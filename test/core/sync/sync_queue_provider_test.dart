import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_provider.dart';

void main() {
  test('does not auto-flush again for a verified unchanged session', () {
    expect(
      shouldAutoFlushQueueOnAuthTransition(
        previousOnlineVerified: true,
        previousScope: '27:4:session-a',
        nextOnlineVerified: true,
        nextScope: '27:4:session-a',
      ),
      isFalse,
    );
  });

  test('flushes when login verification or owner identity changes', () {
    expect(
      shouldAutoFlushQueueOnAuthTransition(
        previousOnlineVerified: false,
        previousScope: '27:4:session-a',
        nextOnlineVerified: true,
        nextScope: '27:4:session-a',
      ),
      isTrue,
    );
    expect(
      shouldAutoFlushQueueOnAuthTransition(
        previousOnlineVerified: true,
        previousScope: '27:4:session-a',
        nextOnlineVerified: true,
        nextScope: '27:8:session-b',
      ),
      isTrue,
    );
    expect(
      shouldAutoFlushQueueOnAuthTransition(
        previousOnlineVerified: true,
        previousScope: '27:4:session-a',
        nextOnlineVerified: false,
        nextScope: '27:4:session-a',
      ),
      isFalse,
    );
  });
}
