import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_snapshot_adapter.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  test(
    'график, детали и план дня доступны после перезапуска без сети',
    () async {
      final store = MemoryEntitySnapshotStore();
      final owner = EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _ScheduleRepository();
      final online = ScheduleSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
        now: () => DateTime(2026, 9, 26, 12),
      );

      await online.loadOverview(online: true, projectId: 15);
      await online.loadDetail(online: true, scheduleId: 7, projectId: 15);
      await online.loadDailyPlans(online: true, projectId: 15);

      final restarted = ScheduleSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
        now: () => DateTime(2026, 9, 26, 12),
      );
      final overview = await restarted.loadOverview(
        online: false,
        projectId: 15,
      );
      final detail = await restarted.loadDetail(
        online: false,
        scheduleId: 7,
        projectId: 15,
      );
      final daily = await restarted.loadDailyPlans(
        online: false,
        projectId: 15,
      );

      expect(overview.data?.project.name, 'Объект');
      expect(overview.fromCache, isTrue);
      expect(detail.data?.schedule.name, 'График 7');
      expect(detail.fromCache, isTrue);
      expect(daily.data?.single.scheduleName, 'График 7');
      expect(daily.fromCache, isTrue);
      expect(repository.overviewFetchCount, 1);
      expect(repository.detailFetchCount, 1);
      expect(repository.dailyFetchCount, 1);
    },
  );

  test('403 дневного плана запрещает показ старого кеша офлайн', () async {
    final store = MemoryEntitySnapshotStore();
    const owner = EntitySnapshotOwner(userId: 7, orgId: 10);
    final repository = _ScheduleRepository();
    final adapter = ScheduleSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(store: store, resolveOwner: () => owner),
      ),
      now: () => DateTime(2026, 9, 26, 12),
    );

    final initial = await adapter.loadDailyPlans(online: true, projectId: 15);
    repository.dailyPermissionDenied = true;
    final denied = await adapter.loadDailyPlans(online: true, projectId: 15);
    final afterRevocation = await adapter.loadDailyPlans(
      online: false,
      projectId: 15,
    );

    expect(initial.data, hasLength(1));
    expect(denied.presence, SnapshotPresence.permissionDenied);
    expect(denied.data, isNull);
    expect(afterRevocation.presence, SnapshotPresence.permissionDenied);
    expect(afterRevocation.data, isNull);
  });
}

class _ScheduleRepository extends ScheduleRepository {
  _ScheduleRepository() : super(Dio());

  var overviewFetchCount = 0;
  var detailFetchCount = 0;
  var dailyFetchCount = 0;
  var dailyPermissionDenied = false;

  @override
  Future<Map<String, dynamic>> fetchSchedulesPayload({
    required int projectId,
  }) async {
    overviewFetchCount++;
    return _overview;
  }

  @override
  Future<Map<String, dynamic>> fetchScheduleDetailsPayload(
    int scheduleId,
  ) async {
    detailFetchCount++;
    expect(scheduleId, 7);
    return _detail;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDailyWorkPlanPayloads({
    required int projectId,
  }) async {
    dailyFetchCount++;
    if (dailyPermissionDenied) {
      throw const ApiException('Нет доступа.', statusCode: 403);
    }
    return [_dailyPlan];
  }
}

final _schedule = <String, dynamic>{
  'id': 7,
  'project_id': 15,
  'name': 'График 7',
  'status': 'active',
  'status_label': 'Активен',
  'status_color': '#0055AA',
  'overall_progress_percent': 45,
  'progress_color': '#0055AA',
  'critical_path_calculated': false,
  'tasks_count': 0,
  'completed_tasks_count': 0,
  'overdue_tasks_count': 0,
};

final _overview = <String, dynamic>{
  'project': {'id': 15, 'name': 'Объект'},
  'summary': {
    'total_schedules': 1,
    'active_schedules': 1,
    'completed_schedules': 0,
    'average_progress_percent': 45,
  },
  'schedules': [_schedule],
};

final _detail = <String, dynamic>{
  'project': {'id': 15, 'name': 'Объект'},
  'schedule': _schedule,
  'summary': {
    'tasks_count': 0,
    'completed_tasks_count': 0,
    'in_progress_tasks_count': 0,
    'overdue_tasks_count': 0,
  },
  'tasks': <Object>[],
};

final _dailyPlan = <String, dynamic>{
  'id': 41,
  'project_id': 15,
  'schedule_id': 7,
  'lookahead_plan_id': 3,
  'schedule_name': 'График 7',
  'work_date': '2026-09-26',
  'status': 'published',
  'status_label': 'Опубликован',
  'available_actions': <Object>[],
  'assignments': <Object>[],
};
