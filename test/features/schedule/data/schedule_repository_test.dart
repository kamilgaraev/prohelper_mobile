import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('fetches a task directly by id for deep links', () async {
    final queue =
        TestDioResponseQueue()..respond('GET', '/schedule/tasks/21', {
          'success': true,
          'data': {
            'id': 21,
            'schedule_id': 8,
            'name': 'Армирование',
            'task_type': 'task',
            'task_type_label': 'Задача',
            'status': 'in_progress',
            'status_label': 'В работе',
            'status_color': '#336699',
            'progress_percent': 45,
            'is_critical': false,
            'level': 0,
            'children_count': 0,
          },
        });

    final task = await ScheduleRepository(queue.buildDio()).fetchTask(21);

    expect(task.id, 21);
    expect(task.name, 'Армирование');
    expect(queue.requests.single.path, '/schedule/tasks/21');
  });

  test('creates and updates a task through schedule task endpoints', () async {
    final queue =
        TestDioResponseQueue()
          ..respond('POST', '/schedule/8/tasks', {'success': true, 'data': {}})
          ..respond('PATCH', '/schedule/tasks/21', {
            'success': true,
            'data': {},
          });
    final repository = ScheduleRepository(queue.buildDio());

    await repository.saveTask(
      scheduleId: 8,
      data: {'name': 'Опалубка', 'planned_start_date': '2026-10-01'},
    );
    await repository.saveTask(
      scheduleId: 8,
      taskId: 21,
      data: {'name': 'Армирование', 'description': 'Секция А'},
    );

    expect(queue.requests.map((request) => request.method), ['POST', 'PATCH']);
    expect(queue.requests.map((request) => request.path), [
      '/schedule/8/tasks',
      '/schedule/tasks/21',
    ]);
    expect((queue.requests.last.data as Map)['description'], 'Секция А');
  });

  test('ambiguous offline fact waits for review and is not replayed', () async {
    final store = _MemorySyncQueueStore();
    final sentRequests = <RequestOptions>[];
    final replayRequests = <RequestOptions>[];
    final service = SyncQueueService(
      store: store,
      dio: _successfulDio(replayRequests),
      now: () => DateTime(2026, 9, 27, 12),
    );
    final repository = ScheduleRepository(
      _receiveTimeoutDio(sentRequests),
      syncQueueServiceFuture: Future.value(service),
    );

    await expectLater(
      repository.recordDailyWorkFact(
        assignmentId: 41,
        input: const DailyWorkFactInput(
          status: 'in_progress',
          completedQuantity: 2,
          actualWorkHours: 4,
        ),
      ),
      throwsA(
        predicate<SyncQueuedException>(
          (error) =>
              error.requiresReview &&
              error.message == SyncQueueMessages.unknownOutcome,
        ),
      ),
    );

    final queued = (await store.all()).single;
    expect(
      sentRequests.single.path,
      '/schedule/daily-plan-assignments/41/fact',
    );
    expect(queued.status, SyncOperationStatuses.conflict);
    expect(queued.nextAttemptAt, isNull);
    expect(queued.lastBusinessError, SyncQueueMessages.unknownOutcome);

    final result = await service.retryDueOperations();

    expect(result.successCount, 0);
    expect(result.retryCount, 0);
    expect(replayRequests, isEmpty);
  });
}

Dio _receiveTimeoutDio(List<RequestOptions> requests) {
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
            type: DioExceptionType.receiveTimeout,
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _successfulDio(List<RequestOptions> requests) {
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
            statusCode: 200,
            data: {'success': true, 'data': {}},
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
