import 'package:flutter_test/flutter_test.dart';
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
}
