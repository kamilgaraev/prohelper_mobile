import 'package:isar/isar.dart';

import 'queued_sync_operation.dart';
import 'sync_queue_store.dart';

class IsarSyncQueueStore implements SyncQueueStore {
  const IsarSyncQueueStore(this._isar);

  final Isar _isar;

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    await _isar.writeTxn(() async {
      await _isar.queuedSyncOperations.put(operation);
    });

    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async {
    final operations = await _isar.queuedSyncOperations.where().findAll();
    operations.sort((left, right) => left.createdAt.compareTo(right.createdAt));

    return operations;
  }

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async {
    final operations = await all();

    return operations.where((operation) {
      if (operation.status != SyncOperationStatuses.queued) {
        return false;
      }

      final nextAttemptAt = operation.nextAttemptAt;
      return nextAttemptAt == null || !nextAttemptAt.isAfter(now);
    }).toList();
  }

  @override
  Future<QueuedSyncOperation?> get(int id) {
    return _isar.queuedSyncOperations.get(id);
  }

  @override
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.queuedSyncOperations.delete(id);
    });
  }
}
