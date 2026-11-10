import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_provider.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';

void main() {
  final user =
      User()
        ..serverId = 27
        ..email = 'foreman@example.test'
        ..name = 'Прораб'
        ..roles = <String>[]
        ..organizationsJson = '[]'
        ..permissionsJson = '{}';
  const identity = AuthSessionIdentity(
    userId: 27,
    organizationId: 4,
    sessionId: 'session-a',
  );

  test('locking or unlocking the session keeps queued changes', () {
    final online = AuthAuthenticated(
      user,
      sessionIdentity: identity,
      isOnlineVerified: true,
    );
    final locked = AuthLocked(user, identity);
    final offline = AuthAuthenticated(
      user,
      sessionIdentity: identity,
      needsReauthentication: true,
    );

    expect(queueScopeToClearOnAuthTransition(online, locked), isNull);
    expect(queueScopeToClearOnAuthTransition(locked, offline), isNull);
    expect(queueScopeToClearOnAuthTransition(offline, locked), isNull);
    expect(queueScopeToClearOnAuthTransition(locked, online), isNull);
  });

  test('signing out or changing owner clears queued changes', () {
    final locked = AuthLocked(user, identity);
    final other = AuthAuthenticated(
      user,
      sessionIdentity: const AuthSessionIdentity(
        userId: 27,
        organizationId: 8,
        sessionId: 'session-b',
      ),
      isOnlineVerified: true,
    );

    expect(
      queueScopeToClearOnAuthTransition(locked, AuthUnauthenticated()),
      '27:4:session-a',
    );
    expect(
      queueScopeToClearOnAuthTransition(locked, AuthError('x')),
      '27:4:session-a',
    );
    expect(queueScopeToClearOnAuthTransition(locked, other), '27:4:session-a');
  });

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
