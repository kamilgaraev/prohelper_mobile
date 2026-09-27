import 'cached_entity.dart';

class EntitySnapshotOwner {
  const EntitySnapshotOwner({
    required this.userId,
    required this.orgId,
    this.projectId,
  });

  final int userId;
  final int orgId;
  final int? projectId;

  @override
  bool operator ==(Object other) =>
      other is EntitySnapshotOwner &&
      userId == other.userId &&
      orgId == other.orgId &&
      projectId == other.projectId;

  @override
  int get hashCode => Object.hash(userId, orgId, projectId);
}

abstract class EntitySnapshotStore {
  Future<void> put(CachedEntity entity);

  Future<void> deleteCleanScope({
    required int userId,
    required int orgId,
    required String type,
    required int? projectId,
    required Set<String> keepRemoteIds,
  });

  Future<CachedEntity?> findOne({
    required int userId,
    required int orgId,
    required String type,
    required String remoteId,
    int? projectId,
  });

  Future<List<CachedEntity>> findList({
    required int userId,
    required int orgId,
    required String type,
    int? projectId,
  });
}
