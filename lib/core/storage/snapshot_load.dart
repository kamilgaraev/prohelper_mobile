import 'cached_entity.dart';
import 'cached_entity_codec.dart';
import 'entity_snapshot_service.dart';
import 'entity_snapshot_store.dart';
import 'list_snapshot.dart';
import 'snapshot_read.dart';

Future<SnapshotRead<T>> loadSingleEntitySnapshot<T>({
  required bool online,
  required Future<SnapshotRead<T>> Function({bool fromNetwork}) readCached,
  required Future<void> Function()? flushQueue,
  required Future<EntitySnapshotService> snapshots,
  required String type,
  required String remoteId,
  required Future<Map<String, dynamic>> Function() fetchPayload,
  required int? projectId,
  required String permissionFallback,
  required String malformedFallback,
}) async {
  final cached = await readCached();
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
    await currentService.pullAndMerge(type, () async {
      late final Map<String, dynamic> payload;
      try {
        payload = await fetchPayload();
      } catch (error) {
        permissionDeniedByFetch = isSnapshotPermissionDenied(error);
        rethrow;
      }
      return [
        cachedEntityFromPayload(
          type: type,
          remoteId: remoteId,
          payload: payload,
          projectId: projectId ?? snapshotProjectIdOf(payload),
        ),
      ];
    }, expectedOwner: expectedOwner);
    return readCached(fromNetwork: true);
  } catch (error) {
    if (permissionDeniedByFetch && service != null && owner != null) {
      try {
        await service.invalidateScope(type, projectId, expectedOwner: owner);
      } catch (_) {}
    }
    return snapshotFailureRead(
      cached: cached,
      error: error,
      fallback: malformedFallback,
      permissionFallback: permissionFallback,
    );
  }
}

SnapshotRead<T> decodeSingleSnapshot<T>({
  required CachedEntity? entity,
  required T Function(Map<String, dynamic> payload) decode,
  required String missingMessage,
  required bool Function(T data) isEmpty,
  bool fromNetwork = false,
}) {
  if (entity == null) {
    return SnapshotRead(
      presence: SnapshotPresence.missing,
      error: missingMessage,
    );
  }

  final model = decode(decodeSnapshotPayload(entity));
  if (entity.dirty) {
    return SnapshotRead(
      presence: SnapshotPresence.conflict,
      data: model,
      error: SnapshotUserMessages.conflict,
      fromCache: !fromNetwork,
      hasDirtyLocal: true,
    );
  }
  if (isEmpty(model)) {
    return SnapshotRead(
      presence: SnapshotPresence.empty,
      data: model,
      fromCache: !fromNetwork,
    );
  }
  return SnapshotRead(
    presence: SnapshotPresence.ready,
    data: model,
    fromCache: !fromNetwork,
  );
}
