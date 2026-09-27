import 'queued_sync_operation.dart';

Duration? nextSyncRetryDelay(
  Iterable<QueuedSyncOperation> operations, {
  required String? scope,
  required DateTime now,
}) {
  if (scope == null || scope.isEmpty) return null;

  for (final operation in operations) {
    if (operation.payload['queue_scope'] != scope) continue;
    if (operation.status != SyncOperationStatuses.queued &&
        operation.status != SyncOperationStatuses.sending) {
      return null;
    }
    final dueAt = operation.nextAttemptAt ?? now;
    final remaining = dueAt.difference(now);
    const minimumDelay = Duration(seconds: 30);
    return remaining > minimumDelay ? remaining : minimumDelay;
  }
  return null;
}
