import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_custody_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository({
    this.permissionDenied = false,
    this.invalid = false,
  }) : super(Dio());

  final bool permissionDenied;
  final bool invalid;
  int custodyLoadCount = 0;
  int stockLoadCount = 0;
  int issueCount = 0;
  int returnCount = 0;
  int? lastProjectId;

  @override
  Future<WarehouseSummaryModel> fetchWarehouseSummary() async {
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра склада.',
        statusCode: 403,
      );
    }

    if (invalid) {
      throw const FormatException('missing warehouse_count');
    }

    return _summary;
  }

  @override
  Future<List<WarehouseCustodyBalanceModel>> fetchCustodyBalances({
    int? projectId,
    int? responsibleUserId,
  }) async {
    custodyLoadCount++;
    lastProjectId = projectId;

    return const <WarehouseCustodyBalanceModel>[_custodyBalance];
  }

  @override
  Future<ProjectMaterialStockModel> fetchProjectMaterialStock({
    int? projectId,
  }) async {
    stockLoadCount++;
    lastProjectId = projectId;

    return _projectStock;
  }

  @override
  Future<void> issueToResponsible({
    required int projectId,
    required int projectWarehouseId,
    required int materialId,
    required int responsibleUserId,
    required double quantity,
    String? documentNumber,
    String? reason,
  }) async {
    issueCount++;
    lastProjectId = projectId;
  }

  @override
  Future<void> returnFromResponsible({
    required int projectId,
    required int custodyWarehouseId,
    required int materialId,
    required double quantity,
    String? documentNumber,
    String? reason,
  }) async {
    returnCount++;
    lastProjectId = projectId;
  }
}

const _summary = WarehouseSummaryModel(
  summary: WarehouseSummaryData(
    warehouseCount: 1,
    uniqueItemsCount: 4,
    lowStockCount: 0,
    reservedItemsCount: 1,
    recentMovementsCount: 2,
    totalValue: 12000,
  ),
  warehouses: [
    WarehouseCardModel(
      id: 1,
      name: 'Основной склад',
      isMain: true,
      uniqueItemsCount: 4,
      totalValue: 12000,
    ),
  ],
  recentMovements: [],
);

const _custodyBalance = WarehouseCustodyBalanceModel(
  id: 55,
  projectId: 10,
  projectName: 'Дом 300м',
  custodyWarehouseId: 50,
  responsibleUserId: 7,
  responsibleUserName: 'Иван Прораб',
  materialId: 42,
  materialName: 'Цемент М500',
  unit: 'меш.',
  availableQuantity: 8.5,
);

const _projectStock = ProjectMaterialStockModel(
  items: <ProjectMaterialStockItemModel>[],
  summary: ProjectMaterialStockSummaryModel(
    materialsCount: 1,
    deliveriesCount: 1,
    acceptedQuantity: 12,
    onProjectQuantity: 5,
    issuedQuantity: 3,
    usedQuantity: 4,
    availableQuantity: 8,
  ),
);

void main() {
  test('загружает сводку склада', () async {
    final notifier = WarehouseNotifier(_FakeWarehouseRepository());

    await notifier.load();

    expect(notifier.state.data?.summary.warehouseCount, 1);
    expect(notifier.state.permissionDenied, isFalse);
    expect(notifier.state.error, isNull);
  });

  test('фиксирует состояние недостаточных прав', () async {
    final notifier = WarehouseNotifier(
      _FakeWarehouseRepository(permissionDenied: true),
    );

    await notifier.load();

    expect(notifier.state.permissionDenied, isTrue);
    expect(notifier.state.error, 'Недостаточно прав для просмотра склада.');
  });

  test('показывает бизнес-сообщение при неполном контракте склада', () async {
    final notifier = WarehouseNotifier(_FakeWarehouseRepository(invalid: true));

    await notifier.load();

    expect(notifier.state.permissionDenied, isFalse);
    expect(
      notifier.state.error,
      'Данные склада пришли неполными. Обновите экран и повторите попытку.',
    );
  });

  test('загружает остатки у ответственных', () async {
    final repository = _FakeWarehouseRepository();
    final notifier = WarehouseNotifier(repository);

    await notifier.loadCustodyBalances(projectId: 10);

    expect(repository.custodyLoadCount, 1);
    expect(repository.lastProjectId, 10);
    expect(notifier.state.custodyBalances.single.availableQuantity, 8.5);
    expect(notifier.state.custodyError, isNull);
  });

  test('после выдачи ответственному обновляет custody и объектовые остатки', () async {
    final repository = _FakeWarehouseRepository();
    final notifier = WarehouseNotifier(repository);

    await notifier.issueToResponsible(
      projectId: 10,
      projectWarehouseId: 22,
      materialId: 42,
      responsibleUserId: 7,
      quantity: 3,
    );

    expect(repository.issueCount, 1);
    expect(repository.custodyLoadCount, 1);
    expect(repository.stockLoadCount, 1);
    expect(notifier.state.projectMaterialStock?.summary.availableQuantity, 8);
  });

  test('после возврата ответственным обновляет custody и объектовые остатки', () async {
    final repository = _FakeWarehouseRepository();
    final notifier = WarehouseNotifier(repository);

    await notifier.returnFromResponsible(
      projectId: 10,
      custodyWarehouseId: 50,
      materialId: 42,
      quantity: 2,
    );

    expect(repository.returnCount, 1);
    expect(repository.custodyLoadCount, 1);
    expect(repository.stockLoadCount, 1);
    expect(notifier.state.custodyBalances.single.materialName, 'Цемент М500');
  });
}
