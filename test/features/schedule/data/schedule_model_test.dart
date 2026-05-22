import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';

void main() {
  test('parses overview only from complete schedule contract', () {
    final overview = ScheduleOverviewModel.fromJson({
      'project': {'id': 15, 'name': 'Дом 300м Царево'},
      'summary': {
        'total_schedules': 1,
        'active_schedules': 1,
        'completed_schedules': 0,
        'average_progress_percent': 42.5,
      },
      'schedules': [
        {
          'id': 1,
          'project_id': 15,
          'name': 'Фундамент',
          'status': 'active',
          'status_label': 'Активный',
          'status_color': '#3B82F6',
          'overall_progress_percent': 42.5,
          'progress_color': '#3B82F6',
          'health_status': 'at_risk',
          'critical_path_calculated': true,
          'tasks_count': 5,
          'completed_tasks_count': 2,
          'overdue_tasks_count': 1,
        },
      ],
    });

    expect(overview.project.name, 'Дом 300м Царево');
    expect(overview.summary.averageProgressPercent, 42.5);
    expect(overview.schedules.single.statusLabel, 'Активный');
  });

  test('rejects missing overview summary', () {
    expect(
      () => ScheduleOverviewModel.fromJson({
        'project': {'id': 15, 'name': 'Дом 300м Царево'},
        'schedules': [],
      }),
      throwsFormatException,
    );
  });

  test('rejects unknown schedule and task statuses', () {
    expect(
      () => ScheduleItemModel.fromJson({
        'id': 1,
        'project_id': 15,
        'name': 'Фундамент',
        'status': 'started',
        'status_label': 'Начат',
        'status_color': '#3B82F6',
        'overall_progress_percent': 42.5,
        'progress_color': '#3B82F6',
        'critical_path_calculated': true,
        'tasks_count': 5,
        'completed_tasks_count': 2,
        'overdue_tasks_count': 1,
      }),
      throwsFormatException,
    );

    expect(
      () => ScheduleTaskModel.fromJson({
        'id': 7,
        'name': 'Армирование',
        'task_type': 'activity',
        'task_type_label': 'Работа',
        'status': 'not_started',
        'status_label': 'Не начата',
        'status_color': '#6B7280',
        'progress_percent': 0,
        'is_critical': false,
        'level': 0,
        'children_count': 0,
      }),
      throwsFormatException,
    );
  });
}
