import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/data/auth_session_identity.dart';
import '../../features/auth/domain/auth_provider.dart';
import 'entity_snapshot_service.dart';
import 'entity_snapshot_store.dart';
import 'isar_entity_snapshot_store.dart';
import 'isar_service.dart';

final entitySnapshotStoreProvider = FutureProvider<EntitySnapshotStore>((
  ref,
) async {
  final isar = await ref.watch(isarProvider.future);
  return IsarEntitySnapshotStore(isar);
});

final entitySnapshotServiceProvider = FutureProvider<EntitySnapshotService>((
  ref,
) async {
  final store = await ref.watch(entitySnapshotStoreProvider.future);
  return EntitySnapshotService(
    store: store,
    resolveOwner: () => currentEntitySnapshotOwner(ref),
  );
});

EntitySnapshotOwner? currentEntitySnapshotOwner(Ref ref) {
  final auth = ref.read(authProvider);
  final identity = auth is AuthAuthenticated ? auth.sessionIdentity : null;
  return entitySnapshotOwnerFromIdentity(identity);
}

EntitySnapshotOwner? entitySnapshotOwnerFromIdentity(
  AuthSessionIdentity? identity,
) {
  final userId = identity?.userId;
  final orgId = identity?.organizationId;
  if (userId == null || userId <= 0 || orgId == null || orgId <= 0) {
    return null;
  }

  return EntitySnapshotOwner(userId: userId, orgId: orgId);
}
