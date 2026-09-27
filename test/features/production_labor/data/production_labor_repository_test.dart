import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_repository.dart';

void main() {
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
