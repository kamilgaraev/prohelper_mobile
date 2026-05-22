import 'queued_sync_operation.dart';

abstract class SyncQueueStore {
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation);

  Future<List<QueuedSyncOperation>> all();

  Future<List<QueuedSyncOperation>> due(DateTime now);

  Future<QueuedSyncOperation?> get(int id);

  Future<void> delete(int id);
}
