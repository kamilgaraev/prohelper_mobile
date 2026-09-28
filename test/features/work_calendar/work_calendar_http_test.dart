import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/calendar/work_calendar_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';

import '../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('calendar keeps only schedules whose backend date range contains day', () async {
    final queue = TestDioResponseQueue()..respond(
      'GET',
      '/schedule',
      {
        'success': true,
        'message': null,
        'data': {
          'project': {'id': 52, 'name': 'Тестовый'},
          'summary': {
            'total_schedules': 2,
            'active_schedules': 2,
            'completed_schedules': 0,
            'average_progress_percent': 25.0,
          },
          'schedules': [
            {
              'id': 81,
              'project_id': 52,
              'name': 'Монтаж опалубки',
              'description': null,
              'status': 'active',
              'status_label': 'В работе',
              'status_color': '#336699',
              'overall_progress_percent': 50.0,
              'progress_color': '#33AA66',
              'health_status': 'on_track',
              'planned_start_date': '2026-09-22',
              'planned_end_date': '2026-09-24',
              'planned_duration_days': 3,
              'actual_start_date': null,
              'actual_end_date': null,
              'critical_path_calculated': false,
              'critical_path_duration_days': null,
              'tasks_count': 4,
              'completed_tasks_count': 1,
              'overdue_tasks_count': 0,
              'created_at': '2026-09-20 10:00:00',
              'updated_at': '2026-09-28 08:00:00',
            },
            {
              'id': 82,
              'project_id': 52,
              'name': 'Покраска фасада',
              'description': null,
              'status': 'active',
              'status_label': 'В работе',
              'status_color': '#336699',
              'overall_progress_percent': 0.0,
              'progress_color': '#999999',
              'health_status': 'on_track',
              'planned_start_date': '2026-10-01',
              'planned_end_date': '2026-10-03',
              'planned_duration_days': 3,
              'actual_start_date': null,
              'actual_end_date': null,
              'critical_path_calculated': false,
              'critical_path_duration_days': null,
              'tasks_count': 2,
              'completed_tasks_count': 0,
              'overdue_tasks_count': 0,
              'created_at': '2026-09-20 10:00:00',
              'updated_at': '2026-09-28 08:00:00',
            },
          ],
        },
      },
    );
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          ScheduleRepository(queue.buildDio()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final day = await container.read(
      workCalendarDayProvider(
        WorkCalendarQuery(
          projectId: 52,
          date: DateTime(2026, 9, 23),
          loadRequests: false,
          loadSchedule: true,
        ),
      ).future,
    );

    expect(day.schedules.map((schedule) => schedule.id), [81]);
    expect(day.schedules.single.name, 'Монтаж опалубки');
    expect(queue.requests.single.path, '/schedule');
    expect(queue.requests.single.queryParameters, {'project_id': 52});
  });

  test('loads a nonempty selected-day request from the scoped mobile API', () async {
    final queue = TestDioResponseQueue()..respond(
      'GET',
      '/site-requests',
      {
        'success': true,
        'message': null,
        'data': [
          {
            'id': 804,
            'title': 'Цемент на корпус А',
            'description': 'Доставка к началу смены',
            'status': 'pending',
            'status_label': 'Ожидает обработки',
            'priority': 'medium',
            'priority_label': 'Средний',
            'request_type': 'material_request',
            'request_type_label': 'Материалы',
            'required_date': '2026-09-23',
            'project_id': 52,
            'material_name': 'Цемент М500',
            'material_quantity': 12,
            'material_unit': 'меш.',
          },
        ],
      },
    );
    final container = ProviderContainer(
      overrides: [
        siteRequestsRepositoryProvider.overrideWithValue(
          SiteRequestsRepository(queue.buildDio()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final day = await container.read(
      workCalendarDayProvider(
        WorkCalendarQuery(
          projectId: 52,
          date: DateTime(2026, 9, 23),
          loadRequests: true,
          loadSchedule: false,
        ),
      ).future,
    );

    expect(day.requests, hasLength(1));
    expect(day.requests.single.serverId, 804);
    expect(day.requests.single.materialName, 'Цемент М500');
    final request = queue.requests.single;
    expect(request.path, '/site-requests');
    expect(request.queryParameters['project_id'], 52);
    expect(request.queryParameters['scope'], 'all');
    expect(request.queryParameters['required_from'], '2026-09-23');
    expect(request.queryParameters['required_to'], '2026-09-23');
    expect(request.queryParameters['page'], 1);
    expect(request.queryParameters['per_page'], 50);
    // This endpoint returns the collection without page meta.
  });
}
