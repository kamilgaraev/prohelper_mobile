import 'package:prohelpers_mobile/core/storage/cached_entity.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';

class MemoryEntitySnapshotStore implements EntitySnapshotStore {
  final _items = <String, CachedEntity>{};
  var _nextId = 1;

  @override
  Future<void> put(CachedEntity entity) async {
    if (entity.id == 0) {
      entity.id = _nextId++;
    }
    _items[_key(entity)] = entity;
  }

  @override
  Future<void> deleteCleanScope({
    required int userId,
    required int orgId,
    required String type,
    required int? projectId,
    required Set<String> keepRemoteIds,
  }) async {
    _items.removeWhere((_, entity) {
      return entity.userId == userId &&
          entity.orgId == orgId &&
          entity.type == type &&
          entity.projectId == projectId &&
          !entity.dirty &&
          !keepRemoteIds.contains(entity.remoteId);
    });
  }

  @override
  Future<CachedEntity?> findOne({
    required int userId,
    required int orgId,
    required String type,
    required String remoteId,
    int? projectId,
  }) async {
    return _items[_composeKey(
      userId: userId,
      orgId: orgId,
      type: type,
      remoteId: remoteId,
      projectId: projectId,
    )];
  }

  @override
  Future<List<CachedEntity>> findList({
    required int userId,
    required int orgId,
    required String type,
    int? projectId,
  }) async {
    return _items.values.where((entity) {
      return entity.userId == userId &&
          entity.orgId == orgId &&
          entity.type == type &&
          entity.projectId == projectId;
    }).toList();
  }

  String _key(CachedEntity entity) {
    return _composeKey(
      userId: entity.userId,
      orgId: entity.orgId,
      type: entity.type,
      remoteId: entity.remoteId,
      projectId: entity.projectId,
    );
  }

  String _composeKey({
    required int userId,
    required int orgId,
    required String type,
    required String remoteId,
    int? projectId,
  }) {
    return '$userId|$orgId|$type|$remoteId|${projectId ?? ''}';
  }
}
