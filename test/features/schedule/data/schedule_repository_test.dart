import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('loads nonempty daily plans from the mobile project-scoped list', () async {
    final queue = TestDioResponseQueue()..respond(
      'GET',
      '/schedule/daily-plans',
      {
        'success': true,
        'message': null,
        'data': [
          {
            'id': 31,
            'project_id': 52,
            'schedule_id': 8,
            'schedule_name': 'Корпус А',
            'lookahead_plan_id': 12,
            'work_date': '2026-09-28',
            'status': 'published',
            'status_label': 'Опубликован',
            'available_actions': [
              {'action': 'record_fact', 'label': 'Указать факт'},
              {'action': 'submit', 'label': 'Отправить'},
            ],
            'assignments': [],
          },
        ],
      },
    );

    final plans = await ScheduleRepository(
      queue.buildDio(),
    ).fetchDailyWorkPlans(projectId: 52);

    expect(plans.single.id, 31);
    expect(plans.single.scheduleName, 'Корпус А');
    expect(plans.single.availableActions.map((action) => action.action), [
      'record_fact',
      'submit',
    ]);
    expect(queue.requests.single.path, '/schedule/daily-plans');
    expect(queue.requests.single.queryParameters, {'project_id': 52});
    // The current backend returns this collection without pagination metadata.
  });

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

  test('records a daily fact with the mobile API contract', () async {
    final queue =
        TestDioResponseQueue()
          ..respond('PATCH', '/schedule/daily-plan-assignments/41/fact', {
            'success': true,
            'data': {
              'id': 41,
              'daily_work_plan_id': 9,
              'lookahead_plan_task_id': 17,
              'schedule_task_id': 23,
              'journal_entry_id': 88,
              'status': 'partially_done',
              'status_label': 'Частично выполнено',
              'fact_status_options': [
                {'status': 'done', 'label': 'Выполнено'},
                {'status': 'partially_done', 'label': 'Частично выполнено'},
                {'status': 'not_done', 'label': 'Не выполнено'},
              ],
              'planned_quantity': 10,
              'completed_quantity': 6,
              'planned_work_hours': 8,
              'actual_work_hours': 7,
              'failure_reason': null,
              'fact_comment': 'Секция А завершена частично',
              'linked_blocking_entities': [],
              'schedule_task': {'id': 23, 'name': 'Армирование'},
              'constraints': [],
            },
          });
    final repository = ScheduleRepository(queue.buildDio());

    final assignment = await repository.recordDailyWorkFact(
      assignmentId: 41,
      input: const DailyWorkFactInput(
        status: 'partially_done',
        completedQuantity: 6,
        actualWorkHours: 7,
        factComment: '  Секция А завершена частично  ',
      ),
    );

    final request = queue.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/schedule/daily-plan-assignments/41/fact');
    expect(request.data, {
      'status': 'partially_done',
      'completed_quantity': 6,
      'actual_work_hours': 7,
      'fact_comment': 'Секция А завершена частично',
    });
    expect(assignment.id, 41);
    expect(assignment.status, 'partially_done');
    expect(assignment.journalEntryId, 88);
    expect(assignment.completedQuantity, 6);
    expect(assignment.actualWorkHours, 7);
    expect(assignment.factComment, 'Секция А завершена частично');
  });

  test('surfaces a forbidden response when recording a daily fact', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(
      BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
    )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 403,
                data: {'success': false, 'message': 'Недостаточно прав.'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    await expectLater(
      ScheduleRepository(dio).recordDailyWorkFact(
        assignmentId: 41,
        input: const DailyWorkFactInput(status: 'done'),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.message, 'message', 'Недостаточно прав.'),
      ),
    );
    expect(requests, hasLength(1));
    expect(requests.single.method, 'PATCH');
    expect(
      requests.single.path,
      '/schedule/daily-plan-assignments/41/fact',
    );
    expect(requests.single.data, {'status': 'done'});
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
