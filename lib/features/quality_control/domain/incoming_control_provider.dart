import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
import '../data/incoming_control_model.dart';
import '../data/incoming_control_repository.dart';
import '../data/incoming_control_draft_store.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/encrypted_local_file_cache.dart';
import '../../../core/storage/cached_entity_codec.dart';

final incomingControlDraftStoreProvider = Provider<IncomingControlDraftStore>(
  (ref) => IncomingControlDraftStore(
    snapshots: ref.read(entitySnapshotServiceProvider.future),
    files: ref.read(encryptedLocalFileCacheProvider),
    ownerScope: () => ref.read(incomingControlOwnerScopeProvider),
  ),
);

final incomingControlOwnerScopeProvider = Provider<String?>((ref) {
  final state = ref.watch(authProvider);
  if (state is! AuthAuthenticated || state.sessionIdentity == null) return null;
  final identity = state.sessionIdentity!;
  return '${identity.userId}:${identity.organizationId ?? 0}:${identity.sessionId}';
});

final incomingControlReferencesProvider = FutureProvider.autoDispose
    .family<IncomingControlReferences, int>((ref, projectId) async {
      final scope = ref.watch(incomingControlOwnerScopeProvider);
      final repository = ref.read(incomingControlRepositoryProvider);
      if (scope == null) return repository.fetchReferences(projectId);
      final snapshots = await ref.read(entitySnapshotServiceProvider.future);
      final owner = snapshots.currentOwner;
      try {
        final references = await repository.fetchReferences(projectId);
        if (owner != null) {
          await snapshots.putSnapshot(
            cachedEntityFromPayload(
              type: 'incoming_control_references',
              remoteId: 'references',
              projectId: projectId,
              payload: references.data,
            ),
            expectedOwner: owner,
          );
        }
        return references;
      } catch (error) {
        if (isSnapshotPermissionDenied(error)) {
          await snapshots.invalidateScope(
            'incoming_control_references',
            projectId,
            expectedOwner: owner,
          );
          rethrow;
        }
        if (!isSnapshotOffline(error)) rethrow;
        final cached = await snapshots.getOne(
          'incoming_control_references',
          'references',
          projectId: projectId,
        );
        if (cached == null) rethrow;
        return IncomingControlReferences({
          ...decodeSnapshotPayload(cached),
          'from_cache': true,
        });
      }
    });

final incomingControlDetailProvider = FutureProvider.autoDispose
    .family<IncomingControlModel, int>((ref, id) {
      ref.watch(incomingControlOwnerScopeProvider);
      return ref.read(incomingControlRepositoryProvider).fetch(id);
    });

final incomingControlReceivingReferencesProvider = FutureProvider.autoDispose
    .family<IncomingControlReferences, int>((ref, projectId) async {
      final scope = ref.watch(incomingControlOwnerScopeProvider);
      final repository = ref.read(incomingControlRepositoryProvider);
      if (scope == null) return repository.fetchReceivingReferences(projectId);
      final snapshots = await ref.read(entitySnapshotServiceProvider.future);
      final owner = snapshots.currentOwner;
      try {
        final references = await repository.fetchReceivingReferences(projectId);
        if (owner != null) {
          await snapshots.putSnapshot(
            cachedEntityFromPayload(
              type: 'incoming_control_receiving_references',
              remoteId: 'references',
              projectId: projectId,
              payload: references.data,
            ),
            expectedOwner: owner,
          );
        }
        return references;
      } catch (error) {
        if (isSnapshotPermissionDenied(error)) {
          await snapshots.invalidateScope(
            'incoming_control_receiving_references',
            projectId,
            expectedOwner: owner,
          );
          rethrow;
        }
        if (!isSnapshotOffline(error)) rethrow;
        final cached = await snapshots.getOne(
          'incoming_control_receiving_references',
          'references',
          projectId: projectId,
        );
        if (cached == null) rethrow;
        return IncomingControlReferences({
          ...decodeSnapshotPayload(cached),
          'from_cache': true,
        });
      }
    });

final incomingControlHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, id) {
      ref.watch(incomingControlOwnerScopeProvider);
      return ref.read(incomingControlRepositoryProvider).fetchHistory(id);
    });

final incomingControlDependenciesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) {
      ref.watch(incomingControlOwnerScopeProvider);
      return ref.read(incomingControlRepositoryProvider).fetchDependencies(id);
    });
