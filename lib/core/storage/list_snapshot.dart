import 'cached_entity.dart';
import 'cached_entity_codec.dart';
import 'entity_snapshot_service.dart';
import 'entity_snapshot_store.dart';
import 'snapshot_read.dart';

int? snapshotProjectIdOf(Map<String, dynamic> payload) {
  final direct = payload['project_id'];
  if (direct is int) {
    return direct;
  }
  if (direct is num) {
    return direct.toInt();
  }
  final parsed = int.tryParse(direct?.toString() ?? '');
  if (parsed != null) {
    return parsed;
  }
  final project = payload['project'];
  if (project is Map) {
    final nested = project['id'];
    if (nested is int) {
      return nested;
    }
    if (nested is num) {
      return nested.toInt();
    }
    return int.tryParse(nested?.toString() ?? '');
  }
  return null;
}

Future<SnapshotRead<List<T>>> loadListSnapshot<T>({
  required Future<EntitySnapshotService> snapshots,
  required String type,
  required bool online,
  required Future<List<Map<String, dynamic>>> Function() fetchPayloads,
  required T? Function(CachedEntity entity) decode,
  required String missingMessage,
  required String permissionFallback,
  required String incompleteFallback,
  Future<void> Function()? flushQueue,
  int? projectId,
  bool replaceFullList = false,
  bool Function(T item)? matches,
  Map<String, dynamic>? Function(List<Map<String, dynamic>> payloads)?
  collectionExtra,
}) async {
  final cached = await readListSnapshot<T>(
    snapshots: snapshots,
    type: type,
    decode: decode,
    missingMessage: missingMessage,
    projectId: projectId,
    matches: matches,
  );
  if (!online) {
    return cached;
  }

  EntitySnapshotService? service;
  EntitySnapshotOwner? owner;
  var permissionDeniedByFetch = false;
  try {
    await flushQueue?.call();
    final currentService = await snapshots;
    service = currentService;
    final expectedOwner = currentService.currentOwner;
    if (expectedOwner == null) return cached;
    owner = expectedOwner;
    final pulledAt = DateTime.now().toUtc();
    var fetchedCount = 0;
    late final List<Map<String, dynamic>> payloads;
    await currentService.pullAndMerge(type, () async {
      try {
        payloads = await fetchPayloads();
      } catch (error) {
        permissionDeniedByFetch = isSnapshotPermissionDenied(error);
        rethrow;
      }
      fetchedCount = payloads.length;
      return [
        for (final payload in payloads)
          cachedEntityFromPayload(
            type: type,
            remoteId: '${payload['id']}',
            payload: payload,
            projectId: projectId ?? snapshotProjectIdOf(payload),
            updatedAt:
                DateTime.tryParse(payload['updated_at']?.toString() ?? '') ??
                pulledAt,
          ),
      ];
    }, expectedOwner: expectedOwner);
    if (replaceFullList) {
      await currentService.replaceFullList(
        type: type,
        projectId: projectId,
        remoteIds: payloads.map((payload) => '${payload['id']}').toSet(),
        expectedOwner: expectedOwner,
      );
    }
    await currentService.putSnapshot(
      snapshotCollectionMarker(
        type: type,
        projectId: projectId,
        at: pulledAt,
        extra: collectionExtra?.call(payloads),
      ),
      expectedOwner: expectedOwner,
    );
    final next = await readListSnapshot<T>(
      snapshots: snapshots,
      type: type,
      decode: decode,
      missingMessage: missingMessage,
      projectId: projectId,
      matches: matches,
      fromNetwork: true,
    );
    return SnapshotRead(
      presence: next.presence,
      data: next.data,
      error: next.error,
      fromCache: false,
      hasDirtyLocal: next.hasDirtyLocal,
      hasMore: fetchedCount > 0,
    );
  } catch (error) {
    if (permissionDeniedByFetch && service != null && owner != null) {
      try {
        await service.invalidateScope(type, projectId, expectedOwner: owner);
      } catch (_) {}
    }
    return snapshotFailureRead(
      cached: cached,
      error: error,
      fallback: incompleteFallback,
      permissionFallback: permissionFallback,
    );
  }
}

Future<SnapshotRead<List<T>>> readListSnapshot<T>({
  required Future<EntitySnapshotService> snapshots,
  required String type,
  required T? Function(CachedEntity entity) decode,
  required String missingMessage,
  int? projectId,
  bool Function(T item)? matches,
  bool fromNetwork = false,
}) async {
  final service = await snapshots;
  final entities = await service.getList(type, projectId);
  final hasCollection = entities.any(isSnapshotCollectionMarker);
  if (entities.any(isSnapshotPermissionRevoked)) {
    return const SnapshotRead(
      presence: SnapshotPresence.permissionDenied,
      error: SnapshotUserMessages.permissionRevoked,
      fromCache: true,
    );
  }
  final models =
      entities
          .where((entity) => !isSnapshotCollectionMarker(entity))
          .map(decode)
          .whereType<T>()
          .where(matches ?? (_) => true)
          .toList();
  final dirty = entities.any(
    (entity) => !isSnapshotCollectionMarker(entity) && entity.dirty,
  );

  if (!hasCollection && entities.isEmpty) {
    return SnapshotRead(
      presence: SnapshotPresence.missing,
      error: missingMessage,
    );
  }

  if (dirty) {
    return SnapshotRead(
      presence: SnapshotPresence.conflict,
      data: models,
      error: SnapshotUserMessages.conflict,
      fromCache: !fromNetwork,
      hasDirtyLocal: true,
    );
  }

  if (models.isEmpty) {
    return SnapshotRead(
      presence: SnapshotPresence.empty,
      data: const [],
      fromCache: !fromNetwork,
    );
  }

  return SnapshotRead(
    presence: SnapshotPresence.ready,
    data: models,
    fromCache: !fromNetwork,
  );
}

Map<String, dynamic>? collectionExtraOf(List<CachedEntity> entities) {
  for (final entity in entities) {
    if (isSnapshotCollectionMarker(entity)) {
      return decodeSnapshotPayload(entity);
    }
  }
  return null;
}
