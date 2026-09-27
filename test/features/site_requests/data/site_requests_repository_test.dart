import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';

void main() {
  test(
    'replays an offline request creation with the original idempotency key',
    () async {
      final store = _MemorySyncQueueStore();
      var now = DateTime(2026, 9, 27, 12);
      final failedRequests = <RequestOptions>[];
      final replayRequests = <RequestOptions>[];
      final syncService = SyncQueueService(
        store: store,
        dio: _replayDio(replayRequests),
        now: () => now,
      );
      final repository = SiteRequestsRepository(
        _failingDio(failedRequests),
        syncQueueServiceFuture: Future.value(syncService),
      );

      await expectLater(
        repository.createSiteRequest({
          'project_id': 15,
          'title': 'Материалы на фундамент',
          'request_type': 'material_request',
          'material_name': 'Бетон М300',
          'material_quantity': 12,
          'material_unit': 'м3',
        }),
        throwsA(isA<SyncQueuedException>()),
      );

      final queued = (await store.all()).single;
      final idempotencyKey = queued.payload['idempotency_key'];
      expect(idempotencyKey, isA<String>());
      expect(failedRequests.single.headers['Idempotency-Key'], idempotencyKey);

      now = now.add(const Duration(minutes: 1));
      final restartedService = SyncQueueService(
        store: store,
        dio: _replayDio(replayRequests),
        now: () => now,
      );
      final result = await restartedService.retryDueOperations();

      expect(result.successCount, 1);
      expect(replayRequests.single.path, '/site-requests');
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

Dio _replayDio(List<RequestOptions> requests) {
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
