import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_repository.dart';

void main() {
  test(
    'создаёт табель по mobile HTTP-контракту и читает resource response',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'success': true,
                  'data': {
                    'id': 501,
                    'work_order_id': 42,
                    'shift_date': '2026-09-28',
                    'status_label': 'На проверке',
                    'total_hours': 7.5,
                  },
                },
              ),
            );
          },
        ),
      );

      final result = await ProductionLaborRepository(dio).createTimesheet(
        workOrderId: 42,
        workOrderLineId: 7,
        hours: 7.5,
        shiftDate: '2026-09-28',
        includeInPayroll: true,
        employeeId: 19,
        workerName: '  Иван Петров  ',
        safetyPermitReference: '  WP-31  ',
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/production-labor/timesheets');
      expect(requests.single.data, {
        'work_order_id': 42,
        'shift_date': '2026-09-28',
        'entries': [
          {
            'work_order_line_id': 7,
            'include_in_payroll': true,
            'employee_id': 19,
            'worker_name': 'Иван Петров',
            'hours': 7.5,
            'safety_permit_reference': 'WP-31',
          },
        ],
      });
      expect(result.id, 501);
      expect(result.workOrderId, 42);
      expect(result.shiftDate, '2026-09-28');
      expect(result.totalHours, 7.5);
    },
  );

  test(
    'табель преобразует backend validation и permission ответы в ApiException',
    () async {
      for (final status in [422, 403]) {
        final dio = Dio(
          BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
        );
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: status,
                    data: {
                      'success': false,
                      'message': 'Недостаточно прав или неверные данные.',
                      if (status == 422)
                        'errors': {
                          'entries.0.hours': ['Поле обязательно.'],
                        },
                    },
                  ),
                ),
              );
            },
          ),
        );

        await expectLater(
          ProductionLaborRepository(dio).createTimesheet(
            workOrderId: 42,
            workOrderLineId: 7,
            hours: 7.5,
            shiftDate: '2026-09-28',
            includeInPayroll: false,
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              status,
            ),
          ),
        );
      }
    },
  );

  test(
    'передаёт output fact и разбирает ProductionLaborOutputEntryResource',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'success': true,
                  'data': {
                    'id': 601,
                    'work_order_id': 42,
                    'work_order_line_id': 7,
                    'project_id': 15,
                    'schedule_task_id': null,
                    'work_date': '2026-09-28',
                    'quantity': 2,
                    'hours': 4,
                    'status': 'pending',
                    'status_label': 'На проверке',
                    'workflow_summary': {
                      'stage': 'pending',
                      'status': 'pending',
                      'stage_label': 'На проверке',
                      'available_actions': <String>[],
                      'blockers': <String>[],
                      'warnings': <String>[],
                    },
                    'problem_flags': <String>[],
                    'available_actions': <String>[],
                    'comment': 'Проверочный замер',
                  },
                },
              ),
            );
          },
        ),
      );

      final result = await ProductionLaborRepository(dio).recordOutput(
        workOrderLineId: 7,
        quantity: 2,
        hours: 4,
        workDate: '2026-09-28',
        idempotencyKey: 'stable-output-contract-key-601',
        comment: '  Проверочный замер  ',
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/production-labor/output-entries');
      expect(
        requests.single.headers['Idempotency-Key'],
        'stable-output-contract-key-601',
      );
      expect(requests.single.data, {
        'idempotency_key': 'stable-output-contract-key-601',
        'work_order_line_id': 7,
        'work_date': '2026-09-28',
        'quantity': 2,
        'hours': 4,
        'comment': 'Проверочный замер',
      });
      expect(result.id, 601);
      expect(result.workOrderId, 42);
      expect(result.workOrderLineId, 7);
      expect(result.workDate, '2026-09-28');
      expect(result.quantity, 2);
      expect(result.hours, 4);
      expect(result.statusLabel, 'На проверке');
    },
  );

  test('загружает все страницы нарядов с project_id', () async {
    final requests = <RequestOptions>[];
    final dio = _workOrdersDio(requests, (page) {
      return {
        'success': true,
        'data': {
          'data': [
            {'id': page},
          ],
          'meta': {'last_page': '2'},
        },
      };
    });
    final repository = ProductionLaborRepository(dio);

    final payloads = await repository.fetchWorkOrderPayloads(projectId: 42);

    expect(payloads.map((payload) => payload['id']), [1, 2]);
    expect(requests, hasLength(2));
    for (var index = 0; index < requests.length; index++) {
      expect(requests[index].queryParameters['page'], index + 1);
      expect(requests[index].queryParameters['per_page'], 50);
      expect(requests[index].queryParameters['project_id'], 42);
    }
  });

  test('сохраняет первую страницу при пустой или неверной meta', () async {
    for (final meta in [
      null,
      <String, dynamic>{},
      {'last_page': 'bad'},
    ]) {
      final requests = <RequestOptions>[];
      final dio = _workOrdersDio(
        requests,
        (_) => {
          'success': true,
          'data': {
            'data': [
              {'id': 7},
            ],
            if (meta != null) 'meta': meta,
          },
        },
      );

      final payloads = await ProductionLaborRepository(
        dio,
      ).fetchWorkOrderPayloads(projectId: 42);

      expect(payloads, [
        {'id': 7},
      ]);
      expect(requests, hasLength(1));
    }
  });

  test(
    'replays one offline output fact with the original idempotency key',
    () async {
      final store = _MemorySyncQueueStore();
      var now = DateTime(2026, 9, 27, 12);
      final failedRequests = <RequestOptions>[];
      final retryRequests = <RequestOptions>[];
      final replayRequests = <RequestOptions>[];
      final syncService = SyncQueueService(
        store: store,
        dio: _replayDio(retryRequests, fail: true),
        now: () => now,
      );
      final repository = ProductionLaborRepository(
        _failingDio(failedRequests),
        syncQueueServiceFuture: Future.value(syncService),
      );

      await expectLater(
        repository.recordOutput(
          workOrderLineId: 7,
          quantity: 2,
          hours: 4,
          workDate: '2026-09-27',
          idempotencyKey: 'stable-output-attempt-42',
        ),
        throwsA(isA<SyncQueuedException>()),
      );

      final queued = (await store.all()).single;
      final idempotencyKey = queued.payload['idempotency_key'];
      expect(idempotencyKey, isA<String>());
      expect(queued.payload, {
        'idempotency_key': idempotencyKey,
        'work_order_line_id': 7,
        'work_date': '2026-09-27',
        'quantity': 2,
        'hours': 4,
      });
      expect(failedRequests.single.headers['Idempotency-Key'], idempotencyKey);

      now = now.add(const Duration(minutes: 1));
      final retryService = SyncQueueService(
        store: store,
        dio: _replayDio(retryRequests, fail: true),
        now: () => now,
      );
      final retryResult = await retryService.retryDueOperations();

      expect(retryResult.retryCount, 1);
      expect(retryRequests.single.headers['Idempotency-Key'], idempotencyKey);
      expect(
        (await store.all()).single.payload['idempotency_key'],
        idempotencyKey,
      );

      now = now.add(const Duration(minutes: 3));
      final restartedService = SyncQueueService(
        store: store,
        dio: _replayDio(replayRequests),
        now: () => now,
      );
      final result = await restartedService.retryDueOperations();

      expect(result.successCount, 1);
      expect(replayRequests.single.path, '/production-labor/output-entries');
      expect(replayRequests.single.method, 'POST');
      expect(replayRequests.single.headers['Idempotency-Key'], idempotencyKey);
      expect(
        (replayRequests.single.data as Map<String, dynamic>)['idempotency_key'],
        idempotencyKey,
      );
      expect(await store.all(), isEmpty);
    },
  );
}

Dio _workOrdersDio(
  List<RequestOptions> requests,
  Map<String, dynamic> Function(int page) responseForPage,
) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        final page = options.queryParameters['page'] as int;
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: responseForPage(page),
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _failingDio(List<RequestOptions> requests) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _replayDio(List<RequestOptions> requests, {bool fail = false}) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        if (fail) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            ),
          );
          return;
        }
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {'id': 101},
            },
          ),
        );
      },
    ),
  );
  return dio;
}

class _MemorySyncQueueStore implements SyncQueueStore {
  final Map<int, QueuedSyncOperation> _operations = {};
  int _nextId = 1;

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == Isar.autoIncrement) {
      operation.id = _nextId++;
    }
    _operations[operation.id] = operation;
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => _operations.values.toList();

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async =>
      _operations.values
          .where(
            (operation) =>
                operation.status == SyncOperationStatuses.queued &&
                (operation.nextAttemptAt == null ||
                    !operation.nextAttemptAt!.isAfter(now)),
          )
          .toList();

  @override
  Future<QueuedSyncOperation?> get(int id) async => _operations[id];

  @override
  Future<void> delete(int id) async {
    _operations.remove(id);
  }
}
