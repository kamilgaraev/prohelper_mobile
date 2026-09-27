import 'package:isar/isar.dart';

import 'cached_entity.dart';
import 'entity_snapshot_store.dart';

class IsarEntitySnapshotStore implements EntitySnapshotStore {
  const IsarEntitySnapshotStore(this._isar);

  final Isar _isar;

  @override
  Future<void> put(CachedEntity entity) async {
    await _isar.writeTxn(() async {
      final existing =
          await _isar.cachedEntities
              .filter()
              .userIdEqualTo(entity.userId)
              .orgIdEqualTo(entity.orgId)
              .typeEqualTo(entity.type)
              .remoteIdEqualTo(entity.remoteId)
              .projectIdEqualTo(entity.projectId)
              .findFirst();
      if (existing != null) entity.id = existing.id;
      await _isar.cachedEntities.put(entity);
    });
  }

  @override
  Future<void> deleteCleanScope({
    required int userId,
    required int orgId,
    required String type,
    required int? projectId,
    required Set<String> keepRemoteIds,
  }) async {
    await _isar.writeTxn(() async {
      final entities =
          await _isar.cachedEntities
              .filter()
              .userIdEqualTo(userId)
              .orgIdEqualTo(orgId)
              .typeEqualTo(type)
              .projectIdEqualTo(projectId)
              .dirtyEqualTo(false)
              .findAll();
      final ids =
          entities
              .where((entity) => !keepRemoteIds.contains(entity.remoteId))
              .map((entity) => entity.id)
              .toList();
      if (ids.isNotEmpty) await _isar.cachedEntities.deleteAll(ids);
    });
  }

  @override
  Future<CachedEntity?> findOne({
    required int userId,
    required int orgId,
    required String type,
    required String remoteId,
    int? projectId,
  }) {
    final query = _isar.cachedEntities
        .filter()
        .userIdEqualTo(userId)
        .orgIdEqualTo(orgId)
        .typeEqualTo(type)
        .remoteIdEqualTo(remoteId)
        .projectIdEqualTo(projectId);
    return query.findFirst();
  }

  @override
  Future<List<CachedEntity>> findList({
    required int userId,
    required int orgId,
    required String type,
    int? projectId,
  }) {
    return _isar.cachedEntities
        .filter()
        .userIdEqualTo(userId)
        .orgIdEqualTo(orgId)
        .typeEqualTo(type)
        .projectIdEqualTo(projectId)
        .findAll();
  }

  Future<void> deleteForUser(int userId) async {
    await _isar.writeTxn(() async {
      await _isar.cachedEntities.filter().userIdEqualTo(userId).deleteAll();
    });
  }
}
