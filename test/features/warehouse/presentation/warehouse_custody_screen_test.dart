import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_custody_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/project_material_deliveries_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_custody_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_issue_sheet.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_return_sheet.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository({
    this.canReceive = true,
    this.remainingToAccept = 8.5,
    this.displayedQuantity = 12,
  }) : super(Dio());

  final bool canReceive;
  final double remainingToAccept;
  final double displayedQuantity;

  @override
  Future<List<ProjectMaterialDeliveryModel>> fetchProjectMaterialDeliveries({
    int? projectId,
  }) async {
    return <ProjectMaterialDeliveryModel>[
      _deliveryWithCapability(
        canReceive,
        remainingToAccept: remainingToAccept,
        displayedQuantity: displayedQuantity,
      ),
    ];
  }

  @override
  Future<ProjectMaterialStockModel> fetchProjectMaterialStock({
    int? projectId,
  }) async {
    return _projectStock;
  }
}

ProjectMaterialDeliveryModel _deliveryWithCapability(
  bool canReceive, {
  double? remainingToAccept,
  double? displayedQuantity,
}) {
  return ProjectMaterialDeliveryModel(
    id: _delivery.id,
    status: _delivery.status,
    statusLabel: _delivery.statusLabel,
    requestedQuantity: _delivery.requestedQuantity,
    reservedQuantity: _delivery.reservedQuantity,
    shippedQuantity: displayedQuantity ?? _delivery.shippedQuantity,
    acceptedQuantity: _delivery.acceptedQuantity,
    usedQuantity: _delivery.usedQuantity,
    availableQuantity: _delivery.availableQuantity,
    remainingToShip: _delivery.remainingToShip,
    remainingToAccept: remainingToAccept ?? _delivery.remainingToAccept,
    canReceive: canReceive,
    projectId: _delivery.projectId,
    projectName: _delivery.projectName,
    materialId: _delivery.materialId,
    materialName: _delivery.materialName,
    materialUnit: _delivery.materialUnit,
    projectWarehouseId: _delivery.projectWarehouseId,
  );
}

class _FakeWarehouseNotifier extends WarehouseNotifier {
  _FakeWarehouseNotifier(super.repository, {bool tinyQuantities = false}) {
    state = WarehouseState(
      custodyBalances: <WarehouseCustodyBalanceModel>[
        tinyQuantities ? _custodyBalanceWithQuantity(0.001) : _custodyBalance,
      ],
      projectMaterialStock:
          tinyQuantities ? _projectStockWithQuantity(0.001) : _projectStock,
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

WarehouseCustodyBalanceModel _custodyBalanceWithQuantity(double quantity) {
  return WarehouseCustodyBalanceModel(
    id: _custodyBalance.id,
    projectId: _custodyBalance.projectId,
    projectName: _custodyBalance.projectName,
    custodyWarehouseId: _custodyBalance.custodyWarehouseId,
    responsibleUserId: _custodyBalance.responsibleUserId,
    responsibleUserName: _custodyBalance.responsibleUserName,
    materialId: _custodyBalance.materialId,
    materialName: _custodyBalance.materialName,
    unit: _custodyBalance.unit,
    availableQuantity: quantity,
  );
}

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

ProjectMaterialStockModel _projectStockWithQuantity(double quantity) {
  final stock = _projectStock.items.single;
  return ProjectMaterialStockModel(
    items: [
      ProjectMaterialStockItemModel(
        projectId: stock.projectId,
        projectName: stock.projectName,
        materialId: stock.materialId,
        materialName: stock.materialName,
        materialUnit: stock.materialUnit,
        acceptedQuantity: stock.acceptedQuantity,
        onProjectQuantity: quantity,
        issuedQuantity: stock.issuedQuantity,
        usedQuantity: stock.usedQuantity,
        availableQuantity: quantity,
        deliveries: stock.deliveries,
        usages: stock.usages,
      ),
    ],
    summary: _projectStock.summary,
  );
}

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
  testWidgets('shows thousandth precision across warehouse quantities', (
    tester,
  ) async {
    await _pumpCustodyScreen(
      tester,
      grants: const {'warehouse.manage_stock'},
      tinyQuantities: true,
      remainingToAccept: 0.001,
    );

    expect(find.text('0.001 меш.'), findsNWidgets(2));
    await _expectVisibleText(tester, 'Осталось');
    expect(find.text('0.001'), findsOneWidget);

    final notifier = _FakeWarehouseNotifier(_FakeWarehouseRepository());
    await _pumpIssueSheet(tester, notifier, onProjectQuantity: 0.001);
    expect(find.text('Доступно на объекте: 0.001 меш.'), findsOneWidget);

    await _pumpReturnSheet(
      tester,
      notifier,
      balance: _custodyBalanceWithQuantity(0.001),
    );
    expect(find.text('У ответственного: 0.001 меш.'), findsOneWidget);

    final repository = _FakeWarehouseRepository(
      remainingToAccept: 0.001,
      displayedQuantity: 0.001,
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [warehouseRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ProjectMaterialDeliveriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0.001 меш.'), findsOneWidget);
  });

  testWidgets('shows custody, issue, return and receive actions', (
    tester,
  ) async {
    await _pumpCustodyScreen(tester, grants: const {'warehouse.manage_stock'});

    expect(find.text('У меня на ответственности'), findsOneWidget);
    expect(find.text('Вернуть на объект'), findsOneWidget);
    expect(find.text('Списано в работу'), findsOneWidget);

    await _expectVisibleText(tester, 'Взять под ответственность');
    await _expectVisibleText(tester, 'Принять на объект');
  });

  testWidgets('issue grant exposes issue only', (tester) async {
    await _pumpCustodyScreen(
      tester,
      grants: const {'warehouse.issue_to_responsible'},
    );

    await _expectVisibleText(tester, 'Взять под ответственность');
    expect(find.text('Вернуть на объект'), findsNothing);
    expect(find.text('Принять на объект'), findsNothing);
  });

  testWidgets('return grant exposes return only', (tester) async {
    await _pumpCustodyScreen(
      tester,
      grants: const {'warehouse.return_from_responsible'},
    );

    expect(find.text('Вернуть на объект'), findsOneWidget);
    expect(find.text('Взять под ответственность'), findsNothing);
    expect(find.text('Принять на объект'), findsNothing);
  });

  testWidgets('receipt grant preserves server canReceive gate', (tester) async {
    await _pumpCustodyScreen(tester, grants: const {'warehouse.receipts'});

    await _expectVisibleText(tester, 'Принять на объект');
    expect(find.text('Взять под ответственность'), findsNothing);
    expect(find.text('Вернуть на объект'), findsNothing);
  });

  testWidgets('receipt grant cannot override server canReceive false', (
    tester,
  ) async {
    await _pumpCustodyScreen(
      tester,
      grants: const {'warehouse.receipts'},
      canReceive: false,
    );

    expect(find.text('Принять на объект'), findsNothing);
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

Future<void> _pumpCustodyScreen(
  WidgetTester tester, {
  required Set<String> grants,
  bool canReceive = true,
  bool tinyQuantities = false,
  double remainingToAccept = 8.5,
}) async {
  final repository = _FakeWarehouseRepository(
    canReceive: canReceive,
    remainingToAccept: remainingToAccept,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(repository),
        warehouseProvider.overrideWith(
          (ref) => _FakeWarehouseNotifier(
            repository,
            tinyQuantities: tinyQuantities,
          ),
        ),
        permissionServiceProvider.overrideWithValue(
          PermissionService(
            context: UserContext.field,
            activeModules: const {AppModule.basicWarehouse},
            grantedPermissions: grants,
          ),
        ),
      ],
      child: const MaterialApp(home: WarehouseCustodyScreen()),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _pumpIssueSheet(
  WidgetTester tester,
  _FakeWarehouseNotifier notifier, {
  double onProjectQuantity = 5,
}) async {
  final stock = _projectStockWithQuantity(onProjectQuantity).items.single;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [warehouseProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        home: Scaffold(
          body: WarehouseIssueSheet(
            stock: stock,
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
  _FakeWarehouseNotifier notifier, {
  WarehouseCustodyBalanceModel balance = _custodyBalance,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [warehouseProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        home: Scaffold(body: WarehouseReturnSheet(balance: balance)),
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
