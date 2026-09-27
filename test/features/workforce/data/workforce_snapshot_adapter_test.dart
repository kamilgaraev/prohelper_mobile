import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_snapshot_adapter.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  test(
    'история явки сохраняется для объекта и доступна после перезапуска',
    () async {
      final store = MemoryEntitySnapshotStore();
      final owner = EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _WorkforceRepository();
      final online = WorkforceSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );

      final fresh = await online.loadHistory(
        online: true,
        dateFrom: DateTime(2026, 9, 26),
        dateTo: DateTime(2026, 9, 26),
        projectId: 7,
      );
      final restarted = WorkforceSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );
      final restored = await restarted.loadHistory(
        online: false,
        dateFrom: DateTime(2026, 9, 26),
        dateTo: DateTime(2026, 9, 26),
        projectId: 7,
      );
      final unscopedOffline = await restarted.loadHistory(
        online: false,
        dateFrom: DateTime(2026, 9, 26),
        dateTo: DateTime(2026, 9, 26),
      );

      expect(fresh.data?.items.single.employeeLabel, 'Иванов Иван');
      expect(restored.data?.items.single.projectId, 7);
      expect(restored.fromCache, isTrue);
      expect(unscopedOffline.presence, SnapshotPresence.missing);
      expect(repository.fetchCount, 1);
    },
  );
}

class _WorkforceRepository extends WorkforceRepository {
  _WorkforceRepository() : super(Dio());

  var fetchCount = 0;

  @override
  Future<Map<String, dynamic>> fetchAttendanceHistoryPayload({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    fetchCount++;
    return {
      'items': [
        {
          'scan_event_id': 91,
          'employee_id': 41,
          'employee_label': 'Иванов Иван',
          'project_id': projectId ?? 7,
          'project_label': 'Объект 7',
          'work_date': '2026-09-26',
          'status': 'at_work',
          'status_label': 'На объекте',
          'source': 'self_attendance',
          'source_label': 'Самоотметка',
          'confirmed_at': '2026-09-26T09:00:00Z',
        },
      ],
    };
  }
}
