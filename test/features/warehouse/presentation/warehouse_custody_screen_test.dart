import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_custody_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_custody_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_issue_sheet.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_return_sheet.dart';

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

  double? issuedQuantity;
  double? returnedQuantity;
  Object? issueError;
  Object? returnError;

  @override
  Future<void> loadCustodyBalances({
    int? projectId,
    int? responsibleUserId,
  }) async {}

  @override
  Future<void> loadProjectMaterialStock({int? projectId}) async {}

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
    issuedQuantity = quantity;
    final error = issueError;
    if (error != null) {
      throw error;
    }
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
    returnedQuantity = quantity;
    final error = returnError;
    if (error != null) {
      throw error;
    }
  }
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
      onProjectQuantity: 5,
      issuedQuantity: 3.5,
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
    onProjectQuantity: 5,
    issuedQuantity: 3.5,
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

  testWidgets('issue sheet shows inline quantity error without snack bar', (
    tester,
  ) async {
    final notifier = _FakeWarehouseNotifier(_FakeWarehouseRepository());

    await _pumpIssueSheet(tester, notifier);
    await tester.tap(find.text('Взять под ответственность').last);
    await tester.pumpAndSettle();

    expect(find.text('Укажите количество'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('return sheet shows inline quantity error without snack bar', (
    tester,
  ) async {
    final notifier = _FakeWarehouseNotifier(_FakeWarehouseRepository());

    await _pumpReturnSheet(tester, notifier);
    await tester.tap(find.text('Вернуть на объект').last);
    await tester.pumpAndSettle();

    expect(find.text('Укажите количество'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('issue sheet cleans technical submit errors', (tester) async {
    final notifier = _FakeWarehouseNotifier(_FakeWarehouseRepository())
      ..issueError = const FormatException('payload issue_to_responsible');

    await _pumpIssueSheet(tester, notifier);
    await tester.enterText(find.byType(TextField).first, '2,5');
    await tester.tap(find.text('Взять под ответственность').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось выполнить действие. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('payload'), findsNothing);
    expect(notifier.issuedQuantity, 2.5);
  });

  testWidgets('return sheet cleans technical submit errors', (tester) async {
    final notifier = _FakeWarehouseNotifier(_FakeWarehouseRepository())
      ..returnError = const FormatException('payload return_material');

    await _pumpReturnSheet(tester, notifier);
    await tester.enterText(find.byType(TextField).first, '3');
    await tester.tap(find.text('Вернуть на объект').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось выполнить действие. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('payload'), findsNothing);
    expect(notifier.returnedQuantity, 3);
  });
}

Future<void> _pumpIssueSheet(
  WidgetTester tester,
  _FakeWarehouseNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [warehouseProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        home: Scaffold(
          body: WarehouseIssueSheet(
            stock: ProjectMaterialStockItemModel(
              projectId: 10,
              projectName: 'Дом 300м',
              materialId: 42,
              materialName: 'Цемент М500',
              materialUnit: 'меш.',
              acceptedQuantity: 12,
              onProjectQuantity: 5,
              issuedQuantity: 3.5,
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
            projectWarehouseId: 22,
            responsibleUserId: 7,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _pumpReturnSheet(
  WidgetTester tester,
  _FakeWarehouseNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [warehouseProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        home: Scaffold(body: WarehouseReturnSheet(balance: _custodyBalance)),
      ),
    ),
  );

  await tester.pumpAndSettle();
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
