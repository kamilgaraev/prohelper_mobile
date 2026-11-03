import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_model.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_upload.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';
import '../../procurement/procurement_test_data.dart';

const _row = {
  'id': 11,
  'project_id': 4,
  'version': 2,
  'status': 'pending',
  'material': {'id': 1, 'name': 'Гвозди'},
  'presented_quantity': '1000.000',
  'accepted_quantity': '900.000',
  'pending_quantity': '100.000',
};

void main() {
  for (final moduleActive in [false, true]) {
    test(
      'приёмка без обязательного контроля не требует QC view, module_active=$moduleActive',
      () async {
        final requests = <String>[];
        final dio = _dio((options, handler) {
          requests.add(options.path);
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'required': false,
                  'module_active': moduleActive,
                  'ready': false,
                  'policy': {'enabled': false},
                  'issues': [],
                },
              },
            ),
          );
        });
        final references = await IncomingControlRepository(
          dio,
        ).fetchReceivingReferences(4);
        expect(references.enabled, false);
        expect(requests, ['${IncomingControlRepository.endpoint}/readiness']);
      },
    );
  }
  test(
    'обязательный неготовый контроль блокирует обычную приёмку явной причиной',
    () async {
      final dio = _dio(
        (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'success': true,
              'data': {
                'required': true,
                'module_active': false,
                'ready': false,
                'issues': ['Подключите контроль качества на объекте.'],
              },
            },
          ),
        ),
      );
      await expectLater(
        IncomingControlRepository(dio).fetchReceivingReferences(4),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Подключите контроль качества на объекте.',
          ),
        ),
      );
    },
  );
  for (final type in [
    DioExceptionType.badResponse,
    DioExceptionType.connectionError,
  ]) {
    test(
      'ошибка readiness $type не превращается в отключённый контроль',
      () async {
        final dio = _dio(
          (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: type,
              response:
                  type == DioExceptionType.badResponse
                      ? Response(
                        requestOptions: options,
                        statusCode: 403,
                        data: {'message': 'Нет доступа.'},
                      )
                      : null,
            ),
          ),
        );
        await expectLater(
          IncomingControlRepository(dio).fetchReceivingReferences(4),
          throwsA(isA<ApiException>()),
        );
      },
    );
  }
  test(
    'новый паспорт и количества переживают неизвестный исход без JSON/bracket коллизии',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'most-incoming-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/passport.pdf',
      ).writeAsString('passport-test');
      final upload = IncomingControlUpload(
        path: file.path,
        kind: 'quality_document',
        metadata: const {
          'document_number': '12',
          'document_date': '2026-11-03',
          'issuer': 'Завод',
          'coverage_batch_number': 'П-1',
        },
      );
      final store = _Store();
      var fail = true;
      final requests = <RequestOptions>[];
      final dio = _dio((options, handler) {
        requests.add(options);
        if (fail) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            ),
          );
        } else {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'success': true, 'data': _row},
            ),
          );
        }
      });
      final service = SyncQueueService(store: store, dio: dio);
      final repository = IncomingControlRepository(
        dio,
        syncQueueServiceFuture: Future.value(service),
      );
      await expectLater(
        repository.create(
          {
            'project_id': 4,
            'complete': true,
            'presented_quantity': 1000,
            'quality_document_versions': [
              {'document_id': 5, 'version_id': 6},
            ],
            'permitted_work_type_ids': [7],
          },
          idempotencyKey: 'passport-one',
          files: [upload],
        ),
        throwsA(isA<SyncQueuedException>()),
      );
      final queued = (await store.all()).single;
      expect(queued.attachments.single.field, 'files[0][file]');
      expect(queued.payload['files[0][kind]'], 'quality_document');
      expect(queued.payload['files[0][coverage_batch_number]'], 'П-1');
      expect(queued.payload['quality_document_versions[0][version_id]'], '6');
      expect(queued.payload['permitted_work_type_ids[0]'], '7');
      expect(queued.payload['complete'], '1');
      fail = false;
      await service.retryQueuedOperations();
      final replay = requests.last.data as FormData;
      expect(replay.files.single.key, 'files[0][file]');
      expect(Map.fromEntries(replay.fields)['presented_quantity'], '1000');
      expect(requests.last.headers['Idempotency-Key'], 'passport-one');
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'приёмка заказа передаёт новый паспорт и принятое количество одной операцией',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'most-incoming-po-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/passport.pdf',
      ).writeAsString('passport-test');
      late RequestOptions request;
      final dio = _dio((options, handler) {
        request = options;
        handler.resolve(
          Response(
            requestOptions: options,
            data: {'success': true, 'data': procurementPurchaseOrderJson()},
          ),
        );
      });
      await ProcurementRepository(dio).receiveMaterials(
        orderId: 61,
        warehouseId: 3,
        projectId: 4,
        receiptDate: '2026-11-03',
        operationKey: 'po-one',
        items: [
          ProcurementReceiveItemPayload(
            itemId: 701,
            quantityReceived: 900,
            price: 5,
            incomingControl: const {
              'presented_quantity': 1000,
              'accepted_quantity': 900,
              'pending_quantity': 100,
            },
            incomingControlFiles: [
              IncomingControlUpload(
                path: file.path,
                kind: 'quality_document',
                metadata: const {
                  'document_number': '12',
                  'document_date': '2026-11-03',
                  'issuer': 'Завод',
                  'coverage_batch_number': 'П-1',
                },
              ),
            ],
          ),
        ],
      );
      final form = request.data as FormData;
      final fields = Map.fromEntries(form.fields);
      expect(fields.containsKey('items'), isFalse);
      expect(fields['items[0][quantity_received]'], '900.0');
      expect(fields['items[0][incoming_control][presented_quantity]'], '1000');
      expect(
        fields['items[0][incoming_control][files][0][kind]'],
        'quality_document',
      );
      expect(
        form.files.single.key,
        'items[0][incoming_control][files][0][file]',
      );
      expect(request.headers['Idempotency-Key'], 'po-one');
    },
  );
  test(
    'журнал читает MobileResponse и сохраняет серверную пагинацию',
    () async {
      late RequestOptions request;
      final dio = _dio((options, handler) {
        request = options;
        handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'success': true,
              'data': [_row],
              'meta': {'current_page': 2, 'last_page': 3},
            },
          ),
        );
      });
      final result = await IncomingControlRepository(dio).fetchPage(
        projectId: 4,
        page: 2,
        status: 'pending',
        search: ' гвозди ',
        sourceType: 'direct',
        dateFrom: '2026-11-01',
      );
      expect(result.items.single.materialName, 'Гвозди');
      expect(result.items.single.quantity('accepted_quantity'), 900);
      expect(result.lastPage, 3);
      expect(request.queryParameters, containsPair('search', 'гвозди'));
      expect(request.queryParameters, containsPair('project_id', 4));
      expect(request.queryParameters, containsPair('page', 2));
      expect(request.queryParameters, containsPair('date_from', '2026-11-01'));
    },
  );

  test(
    'неизвестный исход решения повторяется тем же ключом и expected_version',
    () async {
      final store = _Store();
      var fail = true;
      final requests = <RequestOptions>[];
      final dio = _dio((options, handler) {
        requests.add(options);
        if (fail) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            ),
          );
        } else {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'success': true, 'data': _row},
            ),
          );
        }
      });
      final service = SyncQueueService(store: store, dio: dio);
      final repository = IncomingControlRepository(
        dio,
        syncQueueServiceFuture: Future.value(service),
      );
      await expectLater(
        repository.decide(IncomingControlModel.fromJson(_row), {
          'accepted_quantity': 900,
          'pending_quantity': 100,
        }, idempotencyKey: 'one-operation'),
        throwsA(isA<SyncQueuedException>()),
      );
      final queued = (await store.all()).single;
      expect(queued.status, SyncOperationStatuses.queued);
      expect(queued.payload['project_id'], 4);
      expect(queued.payload['expected_version'], 2);
      fail = false;
      final replay = await service.retryQueuedOperations();
      expect(replay, isNotNull);
      expect(await store.all(), isEmpty);
      expect(
        requests.map((request) => request.headers['Idempotency-Key']),
        everyElement('one-operation'),
      );
      expect((requests.last.data as Map)['expected_version'], 2);
    },
  );

  test(
    '403 не попадает в очередь и не превращается в локальный допуск',
    () async {
      final store = _Store();
      final dio = _dio(
        (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 403,
              data: {'message': 'Нет полномочий.'},
            ),
          ),
        ),
      );
      final repository = IncomingControlRepository(
        dio,
        syncQueueServiceFuture: Future.value(
          SyncQueueService(store: store, dio: dio),
        ),
      );
      await expectLater(
        repository.create({
          'project_id': 4,
        }, idempotencyKey: 'denied-operation'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'смена владельца во время запроса не переносит приёмку в новую очередь',
    () async {
      final store = _Store();
      var scope = '1:4:session';
      final dio = _dio((options, handler) {
        scope = '2:5:session';
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
      });
      final service = SyncQueueService(
        store: store,
        dio: dio,
        currentScope: () => scope,
      );
      final repository = IncomingControlRepository(
        dio,
        syncQueueServiceFuture: Future.value(service),
      );
      await expectLater(
        repository.create({'project_id': 4}, idempotencyKey: 'old-owner'),
        throwsA(isA<ApiException>()),
      );
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'ручной приход отправляет только принятое количество и отдельный контроль',
    () async {
      late RequestOptions request;
      final dio = _dio((options, handler) {
        request = options;
        handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'success': true,
              'data': {'movement_id': 42},
            },
          ),
        );
      });
      await WarehouseRepository(dio).createReceipt(
        const WarehouseReceiptPayload(
          warehouseId: 3,
          materialId: 1,
          projectId: 4,
          quantity: 900,
          price: 5,
          photos: [],
          idempotencyKey: 'receipt-one',
          incomingControl: {
            'presented_quantity': 1000,
            'accepted_quantity': 900,
            'rejected_quantity': 100,
          },
        ),
      );
      final fields = Map.fromEntries((request.data as FormData).fields);
      expect(fields['quantity'], '900.0');
      expect(fields['incoming_control'], contains('"presented_quantity":1000'));
      expect(request.headers['Idempotency-Key'], 'receipt-one');
    },
  );

  test(
    'полный отказ без прихода сохраняет запись контроля без movement_id',
    () async {
      final dio = _dio(
        (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'success': true,
              'data': {'movement_id': null, 'incoming_control': _row},
            },
          ),
        ),
      );
      await WarehouseRepository(dio).createReceipt(
        const WarehouseReceiptPayload(
          warehouseId: 3,
          materialId: 1,
          projectId: 4,
          quantity: 0,
          price: 5,
          photos: [],
          idempotencyKey: 'rejection-one',
          incomingControl: {
            'presented_quantity': 1000,
            'accepted_quantity': 0,
            'rejected_quantity': 1000,
          },
        ),
      );
    },
  );

  test('недопоставка не становится отклонением качества', () {
    const quantities = IncomingControlQuantities(
      document: 1000,
      presented: 900,
      accepted: 900,
      pending: 0,
      rejected: 0,
    );
    expect(quantities.validationError, isNull);
    expect(quantities.toJson()['rejected_quantity'], 0);
    expect(
      const IncomingControlQuantities(
        document: 1000,
        presented: 1000,
        accepted: 900,
        pending: 0,
        rejected: 50,
      ).validationError,
      isNotNull,
    );
  });
}

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) =>
    Dio(BaseOptions(baseUrl: 'https://mobile-api.test'))
      ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));

class _Store implements SyncQueueStore {
  final _items = <int, QueuedSyncOperation>{};
  int _next = 1;
  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (!_items.containsKey(operation.id)) operation.id = _next++;
    _items[operation.id] = operation;
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => _items.values.toList();
  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async =>
      _items.values
          .where(
            (item) =>
                item.nextAttemptAt == null || !item.nextAttemptAt!.isAfter(now),
          )
          .toList();
  @override
  Future<QueuedSyncOperation?> get(int id) async => _items[id];
  @override
  Future<void> delete(int id) async {
    _items.remove(id);
  }
}
