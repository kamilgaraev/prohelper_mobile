import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_draft_store.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_model.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_upload.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/incoming_control_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/incoming_control_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/project_material_delivery_receive_sheet.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_receipt_sheet.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  for (final flow in ['editor', 'warehouse', 'delivery']) {
    testWidgets(
      '$flow удерживает восстановленный паспорт после закрытия до timeout и durable staging',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'most-receive-lifetime-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final passport = File('${directory.path}/passport.pdf')
          ..writeAsStringSync('original-passport');
        final drafts = _Drafts(passport.path);
        final adapter = _TimeoutAdapter();
        final dio = Dio(
          BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
        )..httpClientAdapter = adapter;
        final queueStore = _QueueStore();
        final staged = <List<int>>[];
        final queue = SyncQueueService(
          store: queueStore,
          dio: dio,
          currentScope: () => '1:4:session',
          stageQueuedAttachment: (attachment, owner, context) async {
            staged.add(File(attachment.path).readAsBytesSync());
            return 'durable-$context.enc';
          },
        );
        final navigator = GlobalKey<NavigatorState>();
        final references = IncomingControlReferences({
          'policy': {'enabled': true, 'mandatory_documents': true},
          'permissions': {'inspect': true, 'approve': true, 'reject': true},
        });
        tester.view.physicalSize = const Size(1100, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              incomingControlOwnerScopeProvider.overrideWith(
                (ref) => '1:4:session',
              ),
              incomingControlDraftStoreProvider.overrideWithValue(drafts),
              incomingControlReferencesProvider(
                4,
              ).overrideWith((ref) async => references),
              incomingControlReceivingReferencesProvider(
                4,
              ).overrideWith((ref) async => references),
              incomingControlRepositoryProvider.overrideWithValue(
                IncomingControlRepository(
                  dio,
                  syncQueueServiceFuture: Future.value(queue),
                ),
              ),
              warehouseRepositoryProvider.overrideWithValue(
                WarehouseRepository(
                  dio,
                  syncQueueServiceFuture: Future.value(queue),
                ),
              ),
              projectsProvider.overrideWith((ref) => _Projects()),
            ],
            child: MaterialApp(
              navigatorKey: navigator,
              home: const Scaffold(body: Text('Объект')),
            ),
          ),
        );
        if (flow == 'editor') {
          unawaited(
            navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder:
                    (context) => IncomingControlEditor(
                      projectId: 4,
                      record: IncomingControlModel.fromJson({
                        'id': 11,
                        'project_id': 4,
                        'material_id': 1,
                        'version': 1,
                      }),
                    ),
              ),
            ),
          );
        } else {
          unawaited(
            showModalBottomSheet<void>(
              context: navigator.currentContext!,
              isScrollControlled: true,
              builder:
                  (context) =>
                      flow == 'warehouse'
                          ? const WarehouseReceiptSheet(
                            summary: _summary,
                            initialWarehouseId: 3,
                            initialMaterial: WarehouseMaterialOption(
                              id: 1,
                              name: 'Гвозди',
                              defaultPrice: 10,
                            ),
                          )
                          : const ProjectMaterialDeliveryReceiveSheet(
                            delivery: _delivery,
                            initialQuantity: '1',
                          ),
            ),
          );
        }
        await tester.pumpAndSettle();
        final submit = find.widgetWithText(FilledButton, switch (flow) {
          'editor' => 'Сохранить приёмку',
          'warehouse' => 'Провести приход',
          _ => 'Принять на объект',
        });
        await tester.scrollUntilVisible(
          submit,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await _until(tester, () => adapter.started);
        navigator.currentState!.pop();
        await tester.pump(const Duration(seconds: 1));
        expect(passport.existsSync(), true);
        expect(drafts.releaseCalls, 0);
        adapter.finish.complete();
        await _until(tester, () => drafts.releaseCalls == 1);
        expect(staged.single, 'original-passport'.codeUnits);
        final queued = (await queueStore.all()).single;
        expect(queued.attachments.single.encrypted, true);
        expect(queued.payload['project_id'].toString(), '4');
        expect(queued.payload['queue_scope'], '1:4:session');
        expect(passport.existsSync(), false);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(done(), true);
}

class _TimeoutAdapter implements HttpClientAdapter {
  final finish = Completer<void>();
  bool started = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started = true;
    await finish.future;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Drafts extends IncomingControlDraftStore {
  _Drafts(this.path)
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
  @override
  Future<IncomingControlSavedDraft?> read(String id, int projectId) async =>
      IncomingControlSavedDraft(
        {
          'values': {
            'document_quantity': '1',
            'presented_quantity': '1',
            'accepted_quantity': '1',
            'pending_quantity': '0',
            'rejected_quantity': '0',
            'location_name': 'Склад',
            'batch_number': 'A',
          },
          'complete': true,
          'inspection_result': 'compliant',
          'documents_result': 'compliant',
          'context': {'price': '10', 'warehouse_id': 3},
        },
        [
          IncomingControlUpload(
            path: path,
            kind: 'quality_document',
            originalFilename: 'passport.pdf',
            metadata: const {
              'document_number': '1',
              'document_date': '2026-11-03',
              'issuer': 'Завод',
              'coverage_batch_number': 'A',
            },
          ),
        ],
      );
  @override
  Future<void> clear(String id, int projectId) async {}
  @override
  Future<void> releaseFiles(List<IncomingControlUpload> files) async {
    releaseCalls++;
    for (final file in files) {
      final source = File(file.path);
      if (source.existsSync()) source.deleteSync();
    }
  }
}

class _QueueStore implements SyncQueueStore {
  final items = <int, QueuedSyncOperation>{};
  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (!items.containsKey(operation.id)) operation.id = items.length + 1;
    items[operation.id] = operation;
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => items.values.toList();
  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async => [];
  @override
  Future<QueuedSyncOperation?> get(int id) async => items[id];
  @override
  Future<void> delete(int id) async => items.remove(id);
}

class _Projects extends ProjectsNotifier {
  _Projects() : super(ProjectsRepository(Dio())) {
    state = ProjectsState(selectedProject: Project()..serverId = 4);
  }
}

const _summary = WarehouseSummaryModel(
  summary: WarehouseSummaryData(
    warehouseCount: 1,
    uniqueItemsCount: 0,
    lowStockCount: 0,
    reservedItemsCount: 0,
    recentMovementsCount: 0,
    totalValue: 0,
  ),
  warehouses: [
    WarehouseCardModel(
      id: 3,
      name: 'Склад',
      isMain: true,
      uniqueItemsCount: 0,
      totalValue: 0,
    ),
  ],
  recentMovements: [],
);
const _delivery = ProjectMaterialDeliveryModel(
  id: 2,
  status: 'shipped',
  requestedQuantity: 1,
  reservedQuantity: 1,
  shippedQuantity: 1,
  acceptedQuantity: 0,
  usedQuantity: 0,
  availableQuantity: 0,
  remainingToShip: 0,
  remainingToAccept: 1,
  canReceive: true,
  projectId: 4,
  materialId: 1,
  materialName: 'Гвозди',
);
