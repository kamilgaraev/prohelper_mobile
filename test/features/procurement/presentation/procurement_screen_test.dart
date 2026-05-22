import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/procurement/domain/procurement_provider.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

import '../procurement_test_data.dart';

class _RecordingProcurementRepository extends ProcurementRepository {
  _RecordingProcurementRepository() : super(Dio());

  int? loadedProjectId;
  int? fetchedOrderId;
  int? receivedOrderId;
  int? receivedWarehouseId;
  String? receivedReceiptDate;
  List<ProcurementReceiveItemPayload> receivedItems = const [];
  int? commentedOrderId;
  String? orderComment;
  int? approvedApprovalId;
  String? approvedComment;
  int? rejectedApprovalId;
  String? rejectionComment;

  @override
  Future<ProcurementSummaryModel> fetchSummary({int? projectId}) async {
    loadedProjectId = projectId;
    return ProcurementSummaryModel.fromJson(procurementSummaryJson());
  }

  @override
  Future<ProcurementOrderDetailModel> fetchOrder(int id) async {
    fetchedOrderId = id;
    return ProcurementOrderDetailModel.fromJson(procurementOrderDetailJson());
  }

  @override
  Future<ProcurementPurchaseOrderModel> receiveMaterials({
    required int orderId,
    required int warehouseId,
    required List<ProcurementReceiveItemPayload> items,
    required String receiptDate,
    String? notes,
  }) async {
    receivedOrderId = orderId;
    receivedWarehouseId = warehouseId;
    receivedReceiptDate = receiptDate;
    receivedItems = items;
    return ProcurementPurchaseOrderModel.fromJson(
      procurementPurchaseOrderJson(
        status: 'partially_delivered',
        receivedQuantity: 5,
        remainingQuantity: 0,
      ),
    );
  }

  @override
  Future<ProcurementPurchaseOrderModel> addOrderComment({
    required int orderId,
    required String comment,
  }) async {
    commentedOrderId = orderId;
    orderComment = comment;
    return ProcurementPurchaseOrderModel.fromJson(
      procurementPurchaseOrderJson(),
    );
  }

  @override
  Future<ProcurementApprovalModel> approveApproval({
    required int id,
    String? comment,
  }) async {
    approvedApprovalId = id;
    approvedComment = comment;
    return ProcurementApprovalModel.fromJson(
      procurementApprovalJson(status: 'approved', actions: const []),
    );
  }

  @override
  Future<ProcurementApprovalModel> rejectApproval({
    required int id,
    required String comment,
  }) async {
    rejectedApprovalId = id;
    rejectionComment = comment;
    return ProcurementApprovalModel.fromJson(
      procurementApprovalJson(status: 'rejected', actions: const []),
    );
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project? project) : super(_TestProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: project == null ? const [] : [project],
      selectedProject: project,
    );
  }
}

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildApp(
    Widget child,
    _RecordingProcurementRepository repository, {
    Project? selectedProject,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(selectedProject),
        ),
        procurementProvider.overrideWith(
          (ref) => ProcurementNotifier(repository),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows procurement summary for selected project', (tester) async {
    final repository = _RecordingProcurementRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(
        const ProcurementScreen(),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);

    expect(repository.loadedProjectId, 9);
    expect(find.text('Закупки'), findsOneWidget);
    expect(find.text('Башня'), findsWidgets);
    expect(find.text('Согласования'), findsWidgets);
    expect(find.text('PO-61'), findsWidgets);
    expect(find.text('Поставка бетона'), findsWidgets);
    expect(find.text('БетонПром'), findsWidgets);
  });

  testWidgets('submits approval and rejection from summary', (tester) async {
    final repository = _RecordingProcurementRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(
        const ProcurementScreen(),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);

    await tester.tap(find.text('Согласовать').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Проверено');
    await tester.tap(find.text('Отправить').last);
    await pumpUi(tester);

    expect(repository.approvedApprovalId, 21);
    expect(repository.approvedComment, 'Проверено');

    await tester.tap(find.text('Отклонить').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Нужны условия оплаты');
    await tester.tap(find.text('Отправить').last);
    await pumpUi(tester);

    expect(repository.rejectedApprovalId, 21);
    expect(repository.rejectionComment, 'Нужны условия оплаты');
  });

  testWidgets('opens order detail and submits comment and receipt', (
    tester,
  ) async {
    final repository = _RecordingProcurementRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(
        const ProcurementOrderDetailScreen(orderId: 61),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);

    expect(repository.fetchedOrderId, 61);
    expect(find.text('Бетон М300'), findsWidgets);
    expect(find.text('Поставка ожидается до обеда.'), findsOneWidget);

    await tester.tap(find.text('Комментарий').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).last, 'Поставка на въезде');
    await tester.tap(find.text('Отправить').last);
    await pumpUi(tester);

    expect(repository.commentedOrderId, 61);
    expect(repository.orderComment, 'Поставка на въезде');

    await tester.tap(find.text('Принять').first);
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('procurement-receive-warehouse')));
    await pumpUi(tester);
    await tester.tap(find.text('Основной склад').last);
    await pumpUi(tester);
    await tester.enterText(
      find.byKey(const Key('procurement-receive-date')),
      '2026-05-22',
    );
    await tester.enterText(
      find.byKey(const Key('procurement-receive-quantity-701')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('procurement-receive-price-701')),
      '80000',
    );
    await tester.tap(find.text('Принять материалы').last);
    await pumpUi(tester);

    expect(repository.receivedOrderId, 61);
    expect(repository.receivedWarehouseId, 44);
    expect(repository.receivedReceiptDate, '2026-05-22');
    expect(repository.receivedItems.single.itemId, 701);
    expect(repository.receivedItems.single.quantityReceived, 3);
    expect(repository.receivedItems.single.price, 80000);
  });
}
