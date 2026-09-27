import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_tracking_repository.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_tracking_snapshot_adapter.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  test('день и запись времени доступны после перезапуска без сети', () async {
    final store = MemoryEntitySnapshotStore();
    final owner = EntitySnapshotOwner(userId: 7, orgId: 10);
    final repository = _TimeTrackingRepository();
    final online = TimeTrackingSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(store: store, resolveOwner: () => owner),
      ),
    );

    final summary = await online.load(
      online: true,
      date: '2026-09-26',
      projectId: 9,
    );
    final restarted = TimeTrackingSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(store: store, resolveOwner: () => owner),
      ),
    );
    final restoredSummary = await restarted.load(
      online: false,
      date: '2026-09-26',
      projectId: 9,
    );
    final detailFromSummary = await restarted.loadEntry(
      online: false,
      entryId: 17,
      projectId: 9,
    );

    expect(summary.data?.entries.single.title, 'Монтаж');
    expect(restoredSummary.data?.entries.single.title, 'Монтаж');
    expect(restoredSummary.fromCache, isTrue);
    expect(detailFromSummary.data?.title, 'Монтаж');
    expect(detailFromSummary.fromCache, isTrue);
    expect(repository.summaryFetchCount, 1);
    expect(repository.entryFetchCount, 0);
  });
}

class _TimeTrackingRepository extends TimeTrackingRepository {
  _TimeTrackingRepository() : super(Dio());

  var summaryFetchCount = 0;
  var entryFetchCount = 0;

  @override
  Future<Map<String, dynamic>> fetchDailySummaryPayload({
    required String date,
    required int projectId,
  }) async {
    summaryFetchCount++;
    return {
      'date': date,
      'project_id': projectId,
      'entries': [_entry],
      'active_timer': null,
      'totals': {
        'total_hours': 3.5,
        'billable_hours': 3.5,
        'entries_count': 1,
        'by_status': {'draft': 1},
      },
      'approval_status': {'draft': 1},
    };
  }

  @override
  Future<Map<String, dynamic>> fetchEntryPayload(int id) async {
    entryFetchCount++;
    expect(id, 17);
    return _entry;
  }
}

final _entry = <String, dynamic>{
  'id': 17,
  'organization_id': 10,
  'user_id': 7,
  'project_id': 9,
  'project_label': 'Объект 9',
  'work_date': '2026-09-26',
  'title': 'Монтаж',
  'status': 'draft',
  'status_label': 'Черновик',
  'is_active_timer': false,
  'is_billable': true,
  'corrections': <Object>[],
  'available_actions': ['submit'],
  'approval_summary': {'status': 'draft', 'status_label': 'Черновик'},
  'created_at': '2026-09-26T09:00:00Z',
  'updated_at': '2026-09-26T12:00:00Z',
};
