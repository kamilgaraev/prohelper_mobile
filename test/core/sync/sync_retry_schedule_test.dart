import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_retry_schedule.dart';

void main() {
  final now = DateTime.utc(2026, 9, 27, 17, 40);

  test('повторяет текущую очередь после истечения задержки', () {
    final operations = [
      _operation('other', nextAttemptAt: now.add(const Duration(seconds: 10))),
      _operation('current', nextAttemptAt: now.add(const Duration(minutes: 3))),
      _operation('current', nextAttemptAt: now.add(const Duration(minutes: 1))),
    ];

    expect(
      nextSyncRetryDelay(operations, scope: 'current', now: now),
      const Duration(minutes: 3),
    );
  });

  test('просроченную очередь повторяет без частого опроса', () {
    final operations = [
      _operation(
        'current',
        nextAttemptAt: now.subtract(const Duration(seconds: 5)),
      ),
      _operation('current', status: SyncOperationStatuses.needsEdit),
    ];

    expect(
      nextSyncRetryDelay(operations, scope: 'current', now: now),
      const Duration(seconds: 30),
    );
  });

  test('не планирует повтор для чужих и заблокированных операций', () {
    final operations = [
      _operation('other'),
      _operation('current', status: SyncOperationStatuses.conflict),
      _operation('current'),
    ];

    expect(nextSyncRetryDelay(operations, scope: 'current', now: now), isNull);
  });
}

QueuedSyncOperation _operation(
  String scope, {
  String status = SyncOperationStatuses.queued,
  DateTime? nextAttemptAt,
}) {
  return QueuedSyncOperation()
    ..status = status
    ..payloadJson = jsonEncode({'queue_scope': scope})
    ..nextAttemptAt = nextAttemptAt;
}
