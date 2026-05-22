import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
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
}
