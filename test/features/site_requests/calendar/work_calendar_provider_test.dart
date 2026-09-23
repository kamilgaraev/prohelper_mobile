import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/calendar/work_calendar_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test(
    'loads selected day requests and project schedule using GET APIs',
    () async {
      final queue =
          TestDioResponseQueue()
            ..respond('GET', '/site-requests', {'success': true, 'data': []})
            ..respond('GET', '/schedule', {
              'success': true,
              'data': {
                'project': {'id': 9, 'name': 'Объект'},
                'summary': {
                  'total_schedules': 0,
                  'active_schedules': 0,
                  'completed_schedules': 0,
                  'average_progress_percent': 0,
                },
                'schedules': [],
              },
            });
      final dio = queue.buildDio();
      final container = ProviderContainer(
        overrides: [
          siteRequestsRepositoryProvider.overrideWithValue(
            SiteRequestsRepository(dio),
          ),
          scheduleRepositoryProvider.overrideWithValue(ScheduleRepository(dio)),
        ],
      );
      addTearDown(container.dispose);

      final day = await container.read(
        workCalendarDayProvider(
          WorkCalendarQuery(
            projectId: 9,
            date: DateTime(2026, 9, 23),
            loadRequests: true,
            loadSchedule: true,
          ),
        ).future,
      );

      expect(day.requests, isEmpty);
      expect(day.schedules, isEmpty);
      expect(queue.requests.map((request) => request.method), ['GET', 'GET']);
      expect(queue.requests.map((request) => request.path), [
        '/site-requests',
        '/schedule',
      ]);
      expect(queue.requests.first.queryParameters['project_id'], 9);
      expect(
        queue.requests.first.queryParameters['required_from'],
        '2026-09-23',
      );
      expect(queue.requests.first.queryParameters['required_to'], '2026-09-23');
      expect(queue.requests.last.queryParameters['project_id'], 9);
    },
  );
}
