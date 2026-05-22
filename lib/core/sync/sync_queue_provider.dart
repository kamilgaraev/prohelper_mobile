import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/isar_service.dart';
import 'isar_sync_queue_store.dart';
import 'sync_queue_service.dart';
import 'sync_queue_store.dart';

final syncQueueStoreProvider = FutureProvider<SyncQueueStore>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  return IsarSyncQueueStore(isar);
});

final syncQueueServiceProvider = FutureProvider<SyncQueueService>((ref) async {
  final store = await ref.watch(syncQueueStoreProvider.future);
  return SyncQueueService(store: store, dio: ref.read(dioProvider));
});
