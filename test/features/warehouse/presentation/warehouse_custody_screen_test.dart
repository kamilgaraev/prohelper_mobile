import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_custody_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_custody_screen.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository() : super(Dio());

  @override
  Future<List<ProjectMaterialDeliveryModel>> fetchProjectMaterialDeliveries({
    int? projectId,
  }) async {
    return const <ProjectMaterialDeliveryModel>[_delivery];
  }
}

class _FakeWarehouseNotifier extends WarehouseNotifier {
  _FakeWarehouseNotifier(super.repository) {
    state = const WarehouseState(
      custodyBalances: <WarehouseCustodyBalanceModel>[_custodyBalance],
      projectMaterialStock: _projectStock,
    );
  }

  @override
  Future<void> loadCustodyBalances({
    int? projectId,
    int? responsibleUserId,
  }) async {}

  @override
  Future<void> loadProjectMaterialStock({int? projectId}) async {}
}

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
  items: <ProjectMaterialStockItemModel>[
    ProjectMaterialStockItemModel(
      projectId: 10,
      projectName: 'Дом 300м',
      materialId: 42,
      materialName: 'Цемент М500',
      materialUnit: 'меш.',
      acceptedQuantity: 12,
      usedQuantity: 3.5,
      availableQuantity: 8.5,
      deliveries: <ProjectMaterialStockDeliveryModel>[
        ProjectMaterialStockDeliveryModel(
          id: 701,
          projectWarehouseId: 22,
          acceptedQuantity: 12,
          usedQuantity: 3.5,
          availableQuantity: 8.5,
        ),
      ],
      usages: <ProjectMaterialStockUsageModel>[],
    ),
  ],
  summary: ProjectMaterialStockSummaryModel(
    materialsCount: 1,
    deliveriesCount: 1,
    acceptedQuantity: 12,
    usedQuantity: 3.5,
    availableQuantity: 8.5,
  ),
);

const _delivery = ProjectMaterialDeliveryModel(
  id: 701,
  status: 'in_transit',
  statusLabel: 'В пути',
  requestedQuantity: 12,
  reservedQuantity: 12,
  shippedQuantity: 12,
  acceptedQuantity: 3.5,
  usedQuantity: 0,
  availableQuantity: 3.5,
  remainingToShip: 0,
  remainingToAccept: 8.5,
  canReceive: true,
  projectId: 10,
  projectName: 'Дом 300м',
  materialId: 42,
  materialName: 'Цемент М500',
  materialUnit: 'меш.',
  projectWarehouseId: 22,
);

void main() {
  testWidgets('shows custody, issue, return and receive actions', (
    tester,
  ) async {
    final repository = _FakeWarehouseRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          warehouseRepositoryProvider.overrideWithValue(repository),
          warehouseProvider.overrideWith(
            (ref) => _FakeWarehouseNotifier(repository),
          ),
        ],
        child: const MaterialApp(home: WarehouseCustodyScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('У меня на ответственности'), findsOneWidget);
    expect(find.text('Вернуть на объект'), findsOneWidget);
    expect(find.text('Списано в работу'), findsOneWidget);

    await _expectVisibleText(tester, 'Взять под ответственность');
    await _expectVisibleText(tester, 'Принять на объект');
  });
}

Future<void> _expectVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 8,
    );
  }

  expect(finder, findsOneWidget);
}
