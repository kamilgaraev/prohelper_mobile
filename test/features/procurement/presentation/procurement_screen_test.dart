import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_model.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_draft_store.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_upload.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_draft.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/incoming_control_provider.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/procurement/domain/procurement_provider.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

import '../procurement_test_data.dart';
import '../../../helpers/memory_entity_snapshot_store.dart';

class _LifetimeDraftStore extends IncomingControlDraftStore {
  _LifetimeDraftStore(this.path)
    : super(
        snapshots: Future.value(
          EntitySnapshotService(
            store: MemoryEntitySnapshotStore(),
            resolveOwner: () => const EntitySnapshotOwner(userId: 1, orgId: 4),
          ),
        ),
        files: EncryptedLocalFileCache(),
        ownerScope: () => '1:4:session',
      );
  final String path;
  int releaseCalls = 0;
  bool cleared = false;
  @override
  Future<IncomingControlSavedDraft?> read(String id, int projectId) async =>
      IncomingControlSavedDraft(
        {
          'values': {
            'document_quantity': '3',
            'presented_quantity': '3',
            'accepted_quantity': '3',
            'pending_quantity': '0',
            'rejected_quantity': '0',
            'location_name': 'Склад',
            'batch_number': 'П-12',
          },
          'complete': true,
          'inspection_result': 'compliant',
          'documents_result': 'compliant',
          'context': {
            'operation_key': 'po-operation',
            'control_operation_key': 'po-line',
            'warehouse_id': 44,
            'receipt_date': '2026-11-03',
            'price': '80000',
          },
        },
        [
          IncomingControlUpload(
            path: path,
            originalFilename: 'passport.pdf',
            kind: 'quality_document',
            metadata: const {
              'document_number': '12',
              'document_date': '2026-11-03',
              'issuer': 'Завод',
              'coverage_batch_number': 'П-12',
            },
          ),
        ],
      );
  @override
  Future<void> clear(String id, int projectId) async {
    cleared = true;
  }

  @override
  Future<void> releaseFiles(List<IncomingControlUpload> files) async {
    releaseCalls++;
    for (final file in files) {
      final source = File(file.path);
      if (source.existsSync()) {
        source.deleteSync();
      }
    }
  }
}

class _LifetimeQueueStore implements SyncQueueStore {
  final _items = <int, QueuedSyncOperation>{};
  int _next = 1;
  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (!_items.containsKey(operation.id)) {
      operation.id = _next++;
    }
    _items[operation.id] = operation;
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => _items.values.toList();
  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async =>
      _items.values.toList();
  @override
  Future<QueuedSyncOperation?> get(int id) async => _items[id];
  @override
  Future<void> delete(int id) async {
    _items.remove(id);
  }
}

class _RecordingProcurementRepository extends ProcurementRepository {
  _RecordingProcurementRepository({
    this.orderActions = const ['receive_materials', 'comment'],
  }) : super(Dio());
  final List<String> orderActions;

  int? loadedProjectId;
  int? fetchedOrderId;
  int? fetchedPurchaseRequestId;
  int? receivedOrderId;
  int? receivedWarehouseId;
  String? receivedReceiptDate;
  List<ProcurementReceiveItemPayload> receivedItems = const [];
  String? receivedOperationKey;
  Future<void> Function(List<ProcurementReceiveItemPayload>)? beforeReceive;
  int? commentedOrderId;
  String? orderComment;
  int? approvedApprovalId;
  String? approvedComment;
  int? rejectedApprovalId;
  String? rejectionComment;
  bool queueMaterialsReception = false;
  String purchaseOrderNumber = 'PO-61';

  @override
  Future<ProcurementSummaryModel> fetchSummary({int? projectId}) async {
    loadedProjectId = projectId;
    return ProcurementSummaryModel.fromJson(procurementSummaryJson());
  }

  @override
  Future<ProcurementPage<ProcurementPurchaseRequestModel>>
  fetchPurchaseRequests({
    int? projectId,
    int page = 1,
    String? status,
    String? query,
  }) async => ProcurementPage(
    items: [
      ProcurementPurchaseRequestModel.fromJson(
        procurementPurchaseRequestJson(),
      ),
    ],
    currentPage: page,
    lastPage: 1,
    total: 1,
  );

  @override
  Future<ProcurementPage<ProcurementPurchaseOrderModel>> fetchPurchaseOrders({
    int? projectId,
    int page = 1,
    String? status,
    String? query,
  }) async => ProcurementPage(
    items: [
      ProcurementPurchaseOrderModel.fromJson(
        procurementPurchaseOrderJson(orderNumber: purchaseOrderNumber),
      ),
    ],
    currentPage: page,
    lastPage: 1,
    total: 1,
  );

  @override
  Future<ProcurementPurchaseRequestModel> fetchPurchaseRequest(int id) async {
    fetchedPurchaseRequestId = id;
    return ProcurementPurchaseRequestModel.fromJson(
      procurementPurchaseRequestJson(),
    );
  }

  @override
  Future<ProcurementOrderDetailModel> fetchOrder(int id) async {
    fetchedOrderId = id;
    final json = procurementOrderDetailJson();
    final order = json['order'] as Map<String, dynamic>;
    order['available_actions'] = orderActions;
    order['payment_summary'] = {
      'can_receive_materials': orderActions.contains('receive_materials'),
    };
    order['can_record_incoming_control'] = orderActions.contains(
      'record_incoming_control',
    );
    return ProcurementOrderDetailModel.fromJson(json);
  }

  @override
  Future<ProcurementPurchaseOrderModel> receiveMaterials({
    required int orderId,
    required int warehouseId,
    required List<ProcurementReceiveItemPayload> items,
    required String receiptDate,
    String? notes,
    String? operationKey,
    int? projectId,
  }) async {
    receivedOrderId = orderId;
    receivedWarehouseId = warehouseId;
    receivedReceiptDate = receiptDate;
    receivedItems = items;
    receivedOperationKey = operationKey;
    if (beforeReceive != null) {
      await beforeReceive!(items);
    }
    if (queueMaterialsReception) {
      throw const SyncQueuedException(queueId: 1);
    }
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
    bool incomingControlEnabled = false,
    IncomingControlDraftStore? draftStore,
  }) {
    final references = IncomingControlReferences({
      'policy': {
        'enabled': incomingControlEnabled,
        'mandatory_documents': false,
      },
      'permissions': {
        'create': true,
        'inspect': true,
        'approve': true,
        'reject': true,
      },
    });
    return ProviderScope(
      overrides: [
        if (draftStore != null)
          incomingControlOwnerScopeProvider.overrideWith(
            (ref) => '1:4:session',
          ),
        if (draftStore != null)
          incomingControlDraftStoreProvider.overrideWithValue(draftStore),
        incomingControlReceivingReferencesProvider(
          9,
        ).overrideWith((ref) async => references),
        incomingControlReferencesProvider(
          9,
        ).overrideWith((ref) async => references),
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

  testWidgets(
    'unpaid PO opens explicit optional-policy QC-only mode and records full rejection without stock',
    (tester) async {
      final repository = _RecordingProcurementRepository(
        orderActions: const ['record_incoming_control'],
      );
      useLargeSurface(tester);
      await tester.pumpWidget(
        buildApp(
          const ProcurementOrderDetailScreen(orderId: 61),
          repository,
          selectedProject: project(),
        ),
      );
      await pumpUi(tester);
      expect(find.widgetWithText(FilledButton, 'Принять'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Входной контроль'));
      await pumpUi(tester);
      expect(find.text('Входной контроль поставки'), findsOneWidget);
      expect(
        find.byKey(const Key('procurement-receive-price-701')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('procurement-receive-warehouse')));
      await pumpUi(tester);
      await tester.tap(find.text('Основной склад').last);
      await pumpUi(tester);
      await tester.enterText(
        find.byKey(const Key('procurement-receive-date')),
        '2026-11-03',
      );
      await tester.tap(find.text('Зафиксировать контроль по позиции'));
      await pumpUi(tester);
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      final accepted = tester.widget<TextField>(field('Принято'));
      expect(accepted.readOnly, true);
      expect(accepted.controller!.text, '0');
      for (final entry
          in {
            'Место приёмки': 'Площадка',
            'Ожидает решения': '0',
            'Отклонено': '3',
            'Замечания и основание решения': 'Повреждено при доставке',
          }.entries) {
        await tester.ensureVisible(field(entry.key));
        await tester.enterText(field(entry.key), entry.value);
      }
      for (final label in [
        'Сверка документов',
        'Осмотр, маркировка и комплектность',
      ]) {
        final select = find.ancestor(
          of: find.text(label),
          matching: find.byType(DropdownButtonFormField<String>),
        );
        await tester.ensureVisible(select);
        await tester.pumpAndSettle();
        await tester.tap(select);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Не соответствует').last);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Сохранить контроль'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить контроль'));
      await pumpUi(tester);
      expect(repository.receivedOrderId, 61);
      expect(repository.receivedItems.single.quantityReceived, 0);
      expect(repository.receivedItems.single.price, 80000);
      expect(
        repository.receivedItems.single.incomingControl!['accepted_quantity'],
        0,
      );
      expect(
        repository.receivedItems.single.incomingControl!['rejected_quantity'],
        3,
      );
      expect(find.text('Входной контроль сохранён'), findsOneWidget);
      expect(find.text('Материалы приняты на склад'), findsNothing);
    },
  );

  testWidgets(
    'paid PO explicitly enables optional incoming control and accepts stock',
    (tester) async {
      final repository = _RecordingProcurementRepository(
        orderActions: const ['receive_materials', 'record_incoming_control'],
      );
      useLargeSurface(tester);
      await tester.pumpWidget(
        buildApp(
          const ProcurementOrderDetailScreen(orderId: 61),
          repository,
          selectedProject: project(),
        ),
      );
      await pumpUi(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Принять'));
      await pumpUi(tester);
      expect(find.text('Принять эту позицию'), findsNothing);
      await tester.tap(find.text('Провести входной контроль'));
      await pumpUi(tester);
      expect(find.text('Принять эту позицию'), findsOneWidget);
      await tester.tap(find.byKey(const Key('procurement-receive-warehouse')));
      await pumpUi(tester);
      await tester.tap(find.text('Основной склад').last);
      await pumpUi(tester);
      await tester.enterText(
        find.byKey(const Key('procurement-receive-date')),
        '2026-11-03',
      );
      await tester.enterText(
        find.byKey(const Key('procurement-receive-price-701')),
        '80000',
      );
      await tester.tap(find.text('Принять эту позицию'));
      await pumpUi(tester);
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      final accepted = tester.widget<TextField>(field('Принято'));
      expect(accepted.readOnly, false);
      expect(accepted.controller!.text, '3.0');
      await tester.enterText(field('Место приёмки'), 'Площадка');
      for (final label in [
        'Сверка документов',
        'Осмотр, маркировка и комплектность',
      ]) {
        final select = find.ancestor(
          of: find.text(label),
          matching: find.byType(DropdownButtonFormField<String>),
        );
        await tester.ensureVisible(select);
        await tester.pumpAndSettle();
        await tester.tap(select);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Соответствует').last);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Принять материалы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Принять материалы'));
      await pumpUi(tester);
      expect(repository.receivedOrderId, 61);
      expect(repository.receivedItems.single.quantityReceived, 3);
      final control = repository.receivedItems.single.incomingControl!;
      expect(control['accepted_quantity'], 3);
      expect(control['presented_quantity'], 3);
      expect(control['complete'], true);
      expect(find.text('Материалы приняты на склад'), findsOneWidget);
    },
  );

  testWidgets('opens purchase request details from its list card', (
    tester,
  ) async {
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

    await tester.tap(find.text('Поставка бетона').first);
    await pumpUi(tester);

    expect(repository.fetchedPurchaseRequestId, 12);
    expect(find.text('Состав заявки'), findsWidgets);
    expect(find.text('Бетон М300'), findsOneWidget);
    expect(find.text('Связанные заказы'), findsOneWidget);
  });

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
    expect(find.text('Бетон М300 — 5 м3'), findsOneWidget);
    expect(find.text('ГОСТ'), findsOneWidget);
    expect(find.textContaining('PO-61'), findsWidgets);
    expect(find.text('Закупки'), findsOneWidget);
    expect(find.text('Башня'), findsWidgets);
    expect(find.text('Согласования'), findsWidgets);
    expect(find.text('К приемке'), findsWidgets);
    expect(find.text('PO-61'), findsWidgets);
    expect(find.text('Поставка бетона'), findsWidgets);
    expect(find.text('БетонПром'), findsWidgets);
  });

  testWidgets(
    'keeps creation action and metrics readable on a compact screen',
    (tester) async {
      final repository =
          _RecordingProcurementRepository()
            ..purchaseOrderNumber = 'ЗП-202609-0002';
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(720, 1280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildApp(
          const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: ProcurementScreen(),
          ),
          repository,
          selectedProject: project(),
        ),
      );
      await pumpUi(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Заявка на закупку'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Заказы').first).dy,
        greaterThan(tester.getTopLeft(find.text('В работе').first).dy),
      );
      expect(find.text('Согласования'), findsWidgets);
      expect(find.text('К приемке'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('ЗП-202609-0002'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ЗП-202609-0002'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Все статусы'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('procurement card remains tappable at 240dp and large text', (
    tester,
  ) async {
    final repository = _RecordingProcurementRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 426);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(240, 426),
            textScaler: TextScaler.linear(1.3),
          ),
          child: ProcurementScreen(),
        ),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
    final createRequest = find.text('Заявка на закупку');
    await tester.scrollUntilVisible(
      createRequest,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(createRequest);
    await tester.pump();
    expect(createRequest, findsOneWidget);
    final request = find.text('Поставка бетона');
    await tester.scrollUntilVisible(
      request,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(request.first);
    await tester.pump();
    final requestRect = tester.getRect(request.first);
    await tester.tapAt(requestRect.center);
    await pumpUi(tester);

    expect(repository.fetchedPurchaseRequestId, 12);
    expect(find.text('Состав заявки'), findsWidgets);
    expect(tester.takeException(), isNull);
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

  testWidgets('shows queued receipt as saved instead of an error', (
    tester,
  ) async {
    final repository =
        _RecordingProcurementRepository()..queueMaterialsReception = true;
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(
        const ProcurementOrderDetailScreen(orderId: 61),
        repository,
        selectedProject: project(),
      ),
    );
    await pumpUi(tester);

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

    expect(
      find.text('Будет отправлено при восстановлении связи'),
      findsOneWidget,
    );
    expect(find.text('Материалы приняты на склад'), findsNothing);
    expect(find.byKey(const Key('app-error-notice')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'приёмка заказа передаёт распределение контроля и только принятое количество',
    (tester) async {
      final repository = _RecordingProcurementRepository();
      useLargeSurface(tester);
      await tester.pumpWidget(
        buildApp(
          const ProcurementOrderDetailScreen(orderId: 61),
          repository,
          selectedProject: project(),
          incomingControlEnabled: true,
        ),
      );
      await pumpUi(tester);
      await tester.tap(find.text('Принять').first);
      await pumpUi(tester);
      await tester.tap(find.byKey(const Key('procurement-receive-warehouse')));
      await pumpUi(tester);
      await tester.tap(find.text('Основной склад').last);
      await pumpUi(tester);
      await tester.enterText(
        find.byKey(const Key('procurement-receive-date')),
        '2026-11-03',
      );
      await tester.enterText(
        find.byKey(const Key('procurement-receive-price-701')),
        '80000',
      );
      await tester.tap(find.text('Принять эту позицию'));
      await pumpUi(tester);
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      for (final entry
          in {
            'Место приёмки': 'Склад',
            'Принято': '2',
            'Ожидает решения': '1',
            'Замечания и основание решения': 'Ждём уточнение',
            'Ответственный за хранение': 'Иванов',
          }.entries) {
        await tester.ensureVisible(field(entry.key));
        await tester.enterText(field(entry.key), entry.value);
      }
      await tester.ensureVisible(find.text('Принять материалы').last);
      for (final label in [
        'Сверка документов',
        'Осмотр, маркировка и комплектность',
      ]) {
        final select = find.ancestor(
          of: find.text(label),
          matching: find.byType(DropdownButtonFormField<String>),
        );
        await tester.ensureVisible(select);
        await tester.pumpAndSettle();
        await tester.tap(select);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Соответствует').last);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Принять материалы').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Принять материалы').last);
      await pumpUi(tester);
      expect(repository.receivedOrderId, 61);
      expect(repository.receivedItems.single.quantityReceived, 2);
      final control = repository.receivedItems.single.incomingControl!;
      expect(control['presented_quantity'], 3);
      expect(control['accepted_quantity'], 2);
      expect(control['pending_quantity'], 1);
      expect(control['idempotency_key'], isNotEmpty);
    },
  );

  testWidgets(
    'восстановленный паспорт PO живёт после pop до отложенного durable queue staging',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'most-po-lifetime-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final passport = File('${directory.path}/passport.pdf')
        ..writeAsStringSync('restored-passport');
      final draftStore = _LifetimeDraftStore(passport.path);
      final queueStore = _LifetimeQueueStore();
      final gate = Completer<void>();
      final staged = <List<int>>[];
      final queue = SyncQueueService(
        store: queueStore,
        dio: Dio(),
        currentScope: () => '1:4:session',
        stageQueuedAttachment: (attachment, owner, context) async {
          staged.add(File(attachment.path).readAsBytesSync());
          return 'durable-$context.enc';
        },
      );
      final repository = _RecordingProcurementRepository();
      repository.beforeReceive = (items) async {
        await gate.future;
        final file = items.single.incomingControlFiles.single;
        final prefix = 'items[0][incoming_control][files][0]';
        final form = FormData.fromMap({
          ...file.fields(prefix),
          '$prefix[file]': MultipartFile.fromBytes(
            File(file.path).readAsBytesSync(),
            filename: file.filename,
          ),
        });
        expect(form.files.single.key, '$prefix[file]');
        final operation = await queue.enqueue(
          SyncQueueDraft(
            moduleSlug: 'procurement',
            operationType: 'receive_materials',
            method: 'POST',
            endpoint: '/procurement/purchase-orders/61/receive-materials',
            payload: {
              'idempotency_key': 'po-operation',
              'project_id': 9,
              ...file.fields(prefix),
            },
            attachments: [file.attachment(prefix)],
          ),
        );
        throw SyncQueuedException(queueId: operation.id);
      };
      useLargeSurface(tester);
      await tester.pumpWidget(
        buildApp(
          const ProcurementOrderDetailScreen(orderId: 61),
          repository,
          selectedProject: project(),
          incomingControlEnabled: true,
          draftStore: draftStore,
        ),
      );
      await pumpUi(tester);
      await tester.tap(find.text('Принять').first);
      await pumpUi(tester);
      await tester.tap(find.text('Принять эту позицию'));
      await pumpUi(tester);
      await tester.ensureVisible(find.text('Принять материалы').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Принять материалы').last);
      await tester.pumpAndSettle();
      expect(repository.receivedOperationKey, 'po-operation');
      expect(draftStore.releaseCalls, 0);
      expect(passport.existsSync(), true);
      gate.complete();
      await tester.pumpAndSettle();
      expect(staged.single, 'restored-passport'.codeUnits);
      expect(
        (await queueStore.all()).single.attachments.single.encrypted,
        true,
      );
      expect(draftStore.releaseCalls, 1);
      expect(passport.existsSync(), false);
      expect(draftStore.cleared, true);
      expect(tester.takeException(), isNull);
    },
  );
}
