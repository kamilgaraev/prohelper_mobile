import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/isar_service.dart';
import '../storage/encrypted_local_file_cache.dart';
import 'isar_sync_queue_store.dart';
import 'sync_queue_service.dart';
import 'sync_queue_store.dart';
import '../../features/auth/domain/auth_provider.dart';

bool shouldAutoFlushQueueOnAuthTransition({
  required bool previousOnlineVerified,
  required String? previousScope,
  required bool nextOnlineVerified,
  required String? nextScope,
}) {
  return nextOnlineVerified &&
      nextScope != null &&
      (!previousOnlineVerified || previousScope != nextScope);
}

final syncQueueStoreProvider = FutureProvider<SyncQueueStore>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  return IsarSyncQueueStore(isar);
});

final syncQueueServiceProvider = FutureProvider<SyncQueueService>((ref) async {
  final store = await ref.watch(syncQueueStoreProvider.future);
  final fileCache = ref.read(encryptedLocalFileCacheProvider);
  unawaited(fileCache.clearTemporaryPlaintext());
  String? scopeFor(AuthState state) {
    if (state is! AuthAuthenticated || state.sessionIdentity == null) {
      return null;
    }
    final identity = state.sessionIdentity!;
    return '${identity.userId}:${identity.organizationId ?? 0}:${identity.sessionId}';
  }

  late final SyncQueueService service;

  ref.listen<AuthState>(authProvider, (previous, next) {
    final oldScope = scopeFor(previous ?? AuthInitial());
    final newScope = scopeFor(next);
    if (oldScope != null && oldScope != newScope) {
      unawaited(fileCache.clearIdentity(oldScope));
      unawaited(service.clearScope(oldScope));
    }
    final wasVerified =
        previous is AuthAuthenticated &&
        previous.isOnlineVerified &&
        previous.sessionIdentity != null;
    final isVerified =
        next is AuthAuthenticated &&
        next.isOnlineVerified &&
        next.sessionIdentity != null;
    if (shouldAutoFlushQueueOnAuthTransition(
      previousOnlineVerified: wasVerified,
      previousScope: oldScope,
      nextOnlineVerified: isVerified,
      nextScope: newScope,
    )) {
      unawaited(service.retryDueOperations());
    }
  });
  service = SyncQueueService(
    store: store,
    dio: ref.read(dioProvider),
    currentScope: () {
      final state = ref.read(authProvider);
      if (state is! AuthAuthenticated || state.sessionIdentity == null) {
        return null;
      }
      final identity = state.sessionIdentity!;
      return '${identity.userId}:${identity.organizationId ?? 0}:${identity.sessionId}';
    },
    onlineVerified: () {
      final state = ref.read(authProvider);
      return state is AuthAuthenticated &&
          state.isOnlineVerified &&
          state.sessionIdentity != null;
    },
    verifyOnline: () async {
      final before = scopeFor(ref.read(authProvider));
      if (before == null) return false;
      final accepted =
          await ref.read(authProvider.notifier).verifyOnlineForQueue();
      final current = ref.read(authProvider);
      return accepted &&
          scopeFor(current) == before &&
          current is AuthAuthenticated &&
          current.isOnlineVerified;
    },
    materializeAttachment:
        (attachment, ownerIdentity) => fileCache.materialize(
          ownerIdentity: ownerIdentity,
          encryptedPath: attachment.path,
          context: attachment.context ?? '',
          fileName: attachment.filename,
        ),
    deleteMaterializedAttachment: (path) => fileCache.deleteStagedUpload(path),
    deleteQueuedAttachment:
        (attachment) => fileCache.deleteStagedUpload(attachment.path),
  );
  return service;
});
