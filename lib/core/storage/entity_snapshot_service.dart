import 'cached_entity.dart';
import 'cached_entity_codec.dart';
import 'entity_snapshot_store.dart';

typedef EntitySnapshotFetcher = Future<List<CachedEntity>> Function();

class SnapshotOwnerChangedException implements Exception {
  const SnapshotOwnerChangedException();

  @override
  String toString() => 'Сеанс изменился. Обновите экран.';
}

class EntitySnapshotService {
  EntitySnapshotService({
    required EntitySnapshotStore store,
    required EntitySnapshotOwner? Function() resolveOwner,
    DateTime Function()? now,
  }) : _store = store,
       _resolveOwner = resolveOwner,
       _now = now ?? DateTime.now;

  final EntitySnapshotStore _store;
  final EntitySnapshotOwner? Function() _resolveOwner;
  final DateTime Function() _now;

  EntitySnapshotOwner? get currentOwner => _resolveOwner();

  Future<void> putSnapshot(
    CachedEntity snapshot, {
    EntitySnapshotOwner? expectedOwner,
  }) async {
    final owner = _resolveOwner();
    if (owner == null || (expectedOwner != null && owner != expectedOwner)) {
      if (expectedOwner != null) throw const SnapshotOwnerChangedException();
      return;
    }

    snapshot
      ..userId = owner.userId
      ..orgId = owner.orgId;
    final existing = await _store.findOne(
      userId: owner.userId,
      orgId: owner.orgId,
      type: snapshot.type,
      remoteId: snapshot.remoteId,
      projectId: snapshot.projectId,
    );
    if (_resolveOwner() != owner) throw const SnapshotOwnerChangedException();
    if (existing != null) {
      snapshot.id = existing.id;
    }
    await _store.put(snapshot);
  }

  Future<List<CachedEntity>> getList(String type, int? projectId) async {
    final owner = _resolveOwner();
    if (owner == null) {
      return const <CachedEntity>[];
    }

    final items = await _store.findList(
      userId: owner.userId,
      orgId: owner.orgId,
      type: type,
      projectId: projectId,
    );
    if (_resolveOwner() != owner) return const <CachedEntity>[];
    items.sort((left, right) => left.remoteId.compareTo(right.remoteId));
    return items;
  }

  Future<CachedEntity?> getOne(
    String type,
    String remoteId, {
    int? projectId,
  }) async {
    final owner = _resolveOwner();
    if (owner == null) {
      return null;
    }

    final marker = await _store.findOne(
      userId: owner.userId,
      orgId: owner.orgId,
      type: type,
      remoteId: snapshotCollectionRemoteId,
      projectId: projectId,
    );
    if (_resolveOwner() != owner || isSnapshotPermissionRevoked(marker)) {
      return null;
    }

    final item = await _store.findOne(
      userId: owner.userId,
      orgId: owner.orgId,
      type: type,
      remoteId: remoteId,
      projectId: projectId,
    );
    return _resolveOwner() == owner ? item : null;
  }

  Future<void> invalidateScope(
    String type,
    int? projectId, {
    EntitySnapshotOwner? expectedOwner,
  }) async {
    final owner = _resolveOwner();
    if (owner == null) {
      if (expectedOwner != null) throw const SnapshotOwnerChangedException();
      return;
    }
    if (expectedOwner != null && owner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }

    await putSnapshot(
      snapshotCollectionMarker(
        type: type,
        projectId: projectId,
        at: _now(),
        extra: const {'permission_denied': true},
      ),
      expectedOwner: owner,
    );
    if (_resolveOwner() != owner) throw const SnapshotOwnerChangedException();
    await _store.deleteCleanScope(
      userId: owner.userId,
      orgId: owner.orgId,
      type: type,
      projectId: projectId,
      keepRemoteIds: const {snapshotCollectionRemoteId},
    );
    if (_resolveOwner() != owner) throw const SnapshotOwnerChangedException();
  }

  Future<void> replaceFullList({
    required String type,
    required int? projectId,
    required Set<String> remoteIds,
    required EntitySnapshotOwner expectedOwner,
  }) async {
    final owner = _resolveOwner();
    if (owner == null || owner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
    await _store.deleteCleanScope(
      userId: owner.userId,
      orgId: owner.orgId,
      type: type,
      projectId: projectId,
      keepRemoteIds: {...remoteIds, snapshotCollectionRemoteId},
    );
    if (_resolveOwner() != owner) throw const SnapshotOwnerChangedException();
  }

  Future<void> pullAndMerge(
    String type,
    EntitySnapshotFetcher fetcher, {
    EntitySnapshotOwner? expectedOwner,
  }) async {
    final owner = _resolveOwner();
    if (owner == null) {
      if (expectedOwner != null) throw const SnapshotOwnerChangedException();
      return;
    }
    if (expectedOwner != null && owner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }

    final remoteItems = await fetcher();
    if (_resolveOwner() != owner) throw const SnapshotOwnerChangedException();
    final pulledAt = _now();
    for (final remote in remoteItems) {
      if (_resolveOwner() != owner) throw const SnapshotOwnerChangedException();
      if (remote.type != type) {
        continue;
      }
      remote
        ..userId = owner.userId
        ..orgId = owner.orgId;
      final local = await _store.findOne(
        userId: owner.userId,
        orgId: owner.orgId,
        type: type,
        remoteId: remote.remoteId,
        projectId: remote.projectId,
      );
      if (_resolveOwner() != owner) throw const SnapshotOwnerChangedException();
      final merged = mergeRemoteSnapshot(
        local: local,
        remote: remote,
        pulledAt: pulledAt,
      );
      await _store.put(merged);
    }
  }
}

CachedEntity mergeRemoteSnapshot({
  required CachedEntity remote,
  required DateTime pulledAt,
  CachedEntity? local,
}) {
  if (local == null) {
    remote
      ..dirty = false
      ..pulledAt = pulledAt;
    return remote;
  }

  if (local.dirty) {
    return local;
  }

  final versionOrder = remote.updatedAt.compareTo(local.updatedAt);
  if (versionOrder < 0 ||
      (versionOrder == 0 && remote.payloadJson == local.payloadJson)) {
    return local;
  }

  remote
    ..id = local.id
    ..dirty = false
    ..pulledAt = pulledAt;
  return remote;
}
