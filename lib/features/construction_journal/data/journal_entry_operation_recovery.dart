import '../../../core/sync/queued_sync_operation.dart';
import '../../../core/sync/sync_queue_service.dart';

class PendingJournalEntryOperation {
  const PendingJournalEntryOperation({
    required this.operation,
    required this.journalId,
    required this.idempotencyKey,
    this.entryId,
  });

  final QueuedSyncOperation operation;
  final int journalId;
  final String idempotencyKey;
  final int? entryId;

  Map<String, dynamic> get payload => operation.payload;
}

class JournalEntryOperationRecovery {
  const JournalEntryOperationRecovery(this._service);

  final SyncQueueService _service;

  Future<List<PendingJournalEntryOperation>> findCandidates() async {
    final operations = await _service.all();
    final candidates = <PendingJournalEntryOperation>[];
    for (final operation in operations) {
      if (operation.moduleSlug != 'construction_journal') {
        continue;
      }

      final match = RegExp(
        r'^/construction-journals/(\d+)/entries$',
      ).firstMatch(operation.endpoint);
      final submitMatch = RegExp(
        r'^/journal-entries/(\d+)/submit$',
      ).firstMatch(operation.endpoint);

      if (match != null) {
        final journalId = int.tryParse(match.group(1)!);
        final key = operation.payload['idempotency_key']?.toString() ?? '';
        if (journalId != null && key.isNotEmpty) {
          candidates.add(
            PendingJournalEntryOperation(
              operation: operation,
              journalId: journalId,
              idempotencyKey: key,
              entryId: int.tryParse(
                operation.payload['created_entry_id']?.toString() ?? '',
              ),
            ),
          );
        }
      }

      if (submitMatch != null) {
        final entryId = int.tryParse(submitMatch.group(1)!);
        if (entryId != null) {
          final key = operation.payload['idempotency_key']?.toString() ?? '';
          candidates.add(
            PendingJournalEntryOperation(
              operation: operation,
              journalId:
                  int.tryParse(
                    operation.payload['journal_id']?.toString() ?? '',
                  ) ??
                  0,
              idempotencyKey: key,
              entryId: entryId,
            ),
          );
        }
      }
    }

    return candidates;
  }
}
