import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_repository.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_snapshot_adapter.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  test(
    'наряды доступны после перезапуска в точном project partition',
    () async {
      final store = MemoryEntitySnapshotStore();
      final owner = EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _ProductionRepository();
      final online = ProductionLaborSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );

      final fresh = await online.load(online: true, projectId: 9);
      expect(fresh.data?.single.title, 'Монтаж стен');
      expect(repository.fetchCount, 1);

      final offline = ProductionLaborSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );
      final restored = await offline.load(online: false, projectId: 9);
      final otherProject = await offline.load(online: false, projectId: 10);

      expect(restored.data?.single.title, 'Монтаж стен');
      expect(restored.fromCache, isTrue);
      expect(otherProject.presence, SnapshotPresence.missing);
      expect(repository.fetchCount, 1);
    },
  );
}

class _ProductionRepository extends ProductionLaborRepository {
  _ProductionRepository() : super(Dio());

  var fetchCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchWorkOrderPayloads({
    int? projectId,
  }) async {
    fetchCount++;
    expect(projectId, 9);
    return [_workOrder];
  }
}

final _workOrder = <String, dynamic>{
  'id': 5,
  'project_id': 9,
  'order_number': 'PL-1',
  'title': 'Монтаж стен',
  'status': 'issued',
  'status_label': 'Выдан',
  'available_actions': ['start', 'submit'],
  'lines': <Object>[],
};
