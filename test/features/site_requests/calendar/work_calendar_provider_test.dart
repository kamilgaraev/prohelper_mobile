import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/calendar/work_calendar_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';

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
      expect(queue.requests.first.queryParameters['per_page'], 50);
      expect(queue.requests.first.queryParameters['page'], 1);
      expect(
        queue.requests.first.queryParameters['required_from'],
        '2026-09-23',
      );
      expect(queue.requests.first.queryParameters['required_to'], '2026-09-23');
      expect(queue.requests.last.queryParameters['project_id'], 9);
    },
  );

  test(
    'loads the next calendar page when a day contains 50 requests',
    () async {
      final repository = _PagedSiteRequestsRepository();
      final container = ProviderContainer(
        overrides: [
          siteRequestsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final day = await container.read(
        workCalendarDayProvider(
          WorkCalendarQuery(
            projectId: 9,
            date: DateTime(2026, 9, 23),
            loadRequests: true,
            loadSchedule: false,
          ),
        ).future,
      );

      expect(day.requests, hasLength(51));
      expect(repository.pages, [1, 2]);
      expect(repository.pageSizes, [50, 50]);
    },
  );
}

class _PagedSiteRequestsRepository extends SiteRequestsRepository {
  _PagedSiteRequestsRepository() : super(Dio());

  final pages = <int>[];
  final pageSizes = <int>[];

  @override
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    pages.add(page);
    pageSizes.add(perPage);
    final count = page == 1 ? 50 : 1;
    return List.generate(
      count,
      (index) => SiteRequestModel()..serverId = (page - 1) * 50 + index + 1,
    );
  }
}
