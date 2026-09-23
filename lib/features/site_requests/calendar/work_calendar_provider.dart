import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../schedule/data/schedule_model.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../site_requests/data/site_request_model.dart';
import '../../site_requests/data/site_requests_repository.dart';
import '../../site_requests/domain/site_requests_scope.dart';

class WorkCalendarQuery {
  const WorkCalendarQuery({
    required this.projectId,
    required this.date,
    required this.loadRequests,
    required this.loadSchedule,
  });

  final int projectId;
  final DateTime date;
  final bool loadRequests;
  final bool loadSchedule;

  @override
  bool operator ==(Object other) =>
      other is WorkCalendarQuery &&
      other.projectId == projectId &&
      other.date.year == date.year &&
      other.date.month == date.month &&
      other.date.day == date.day &&
      other.loadRequests == loadRequests &&
      other.loadSchedule == loadSchedule;

  @override
  int get hashCode => Object.hash(
    projectId,
    date.year,
    date.month,
    date.day,
    loadRequests,
    loadSchedule,
  );
}

class WorkCalendarDay {
  const WorkCalendarDay({required this.requests, required this.schedules});

  final List<SiteRequestModel> requests;
  final List<ScheduleItemModel> schedules;
}

final workCalendarDayProvider = FutureProvider.autoDispose
    .family<WorkCalendarDay, WorkCalendarQuery>((ref, query) async {
      final requestsFuture =
          query.loadRequests
              ? ref
                  .read(siteRequestsRepositoryProvider)
                  .fetchSiteRequests(
                    projectId: query.projectId,
                    requiredFrom: query.date,
                    requiredTo: query.date,
                    perPage: 100,
                    scope: SiteRequestsScope.own,
                  )
              : Future.value(<SiteRequestModel>[]);
      final scheduleFuture =
          query.loadSchedule
              ? ref
                  .read(scheduleRepositoryProvider)
                  .fetchSchedules(projectId: query.projectId)
              : Future.value(null);
      final results = await Future.wait<Object?>([
        requestsFuture,
        scheduleFuture,
      ]);
      final requests = results[0] as List<SiteRequestModel>;
      final schedule = results[1] as ScheduleOverviewModel?;
      final schedules =
          schedule?.schedules
              .where((item) => _scheduleIncludesDate(item, query.date))
              .toList(growable: false) ??
          const <ScheduleItemModel>[];

      return WorkCalendarDay(requests: requests, schedules: schedules);
    });

bool _scheduleIncludesDate(ScheduleItemModel schedule, DateTime date) {
  final start = _dateOnly(schedule.plannedStartDate);
  final end = _dateOnly(schedule.plannedEndDate) ?? start;
  if (start == null) return false;
  final day = DateTime(date.year, date.month, date.day);
  return !day.isBefore(start) && !day.isAfter(end ?? start);
}

DateTime? _dateOnly(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}
