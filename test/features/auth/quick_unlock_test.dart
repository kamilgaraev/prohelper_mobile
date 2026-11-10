import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/biometric_unlock.dart';
import 'package:prohelpers_mobile/features/auth/data/quick_unlock_service.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/auth/presentation/lock_screen.dart';

class _Storage extends SecureStorageService {
  String? token = 'token-1';
  String? sessionId = 'session-1';
  Map<String, dynamic>? offlineAuth;
  Map<String, dynamic>? quickUnlock;
  final offered = <int>{};

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveToken(String token) async => this.token = token;

  @override
  Future<void> clearToken() async {
    token = null;
    await clearOfflineAuth();
  }

  @override
  Future<void> clearAccessToken() async => token = null;

  @override
  Future<String> ensureSessionId() async => sessionId ??= 'session-new';

  @override
  Future<void> saveOfflineAuth(Map<String, dynamic> value) async =>
      offlineAuth = Map<String, dynamic>.from(value);

  @override
  Future<Map<String, dynamic>?> getOfflineAuth() async => offlineAuth;

  @override
  Future<void> clearOfflineAuth() async {
    offlineAuth = null;
    sessionId = null;
  }

  @override
  Future<String?> getPushInstallationId() async => null;

  @override
  Future<Map<String, dynamic>?> getQuickUnlock() async =>
      quickUnlock == null ? null : Map<String, dynamic>.from(quickUnlock!);

  @override
  Future<void> saveQuickUnlock(Map<String, dynamic> value) async =>
      quickUnlock = Map<String, dynamic>.from(value);

  @override
  Future<void> clearQuickUnlock() async => quickUnlock = null;

  @override
  Future<bool> wasQuickUnlockOffered(int userId) async =>
      offered.contains(userId);

  @override
  Future<void> markQuickUnlockOffered(int userId) async => offered.add(userId);
}

User _user({int id = 7, int? organizationId = 12}) =>
    User()
      ..serverId = id
      ..email = 'foreman@example.test'
      ..name = 'Иван Прораб'
      ..currentOrganizationId = organizationId
      ..roles = <String>['foreman']
      ..organizationsJson = '[]'
      ..permissionsJson = '{}';

class _Repository extends AuthRepository {
  _Repository(this.storage) : super(Dio(), storage);

  final _Storage storage;
  Object? loginError;
  int loginOrganizationId = 12;
  final switchedTo = <int>[];
  int loginCalls = 0;

  @override
  Future<User> getMe({String? token}) async => _user();

  @override
  Future<User> login(String email, String password) async {
    loginCalls++;
    final error = loginError;
    if (error != null) throw error;
    storage.token = 'token-new';
    return _user(organizationId: loginOrganizationId);
  }

  @override
  Future<User> switchOrganization(int organizationId) async {
    switchedTo.add(organizationId);
    return _user(organizationId: organizationId);
  }

  @override
  Future<void> logout({String? installationId}) async {
    await storage.clearToken();
  }
}

class _Biometric implements BiometricUnlock {
  BiometricResult next = BiometricResult.success;
  bool disabled = false;

  @override
  Future<BiometricAvailability> availability() async =>
      BiometricAvailability.available;

  @override
  Future<BiometricResult> authenticate(BiometricPromptText text) async => next;

  @override
  Future<void> disable() async => disabled = true;

  @override
  Future<BiometricResult> enable(BiometricPromptText text) async => next;
}

Map<String, dynamic> _vault(DateTime confirmedAt) => {
  'token': 'token-1',
  'session_id': 'session-1',
  'user_id': 7,
  'organization_id': 12,
  'confirmed_at': confirmedAt.toUtc().toIso8601String(),
  'user': {
    'server_id': 7,
    'email': 'foreman@example.test',
    'name': 'Иван Прораб',
    'organization_id': 12,
    'organization_name': 'МОСТ',
    'organizations_json': '[]',
    'roles': <String>['foreman'],
    'permissions_json': '{}',
  },
};

const _identity = AuthSessionIdentity(
  userId: 7,
  organizationId: 12,
  sessionId: 'session-1',
);

void main() {
  late _Storage storage;
  late _Repository repository;
  late _Biometric biometric;
  late QuickUnlockService quickUnlock;

  AuthNotifier buildNotifier() {
    final notifier = AuthNotifier(
      repository,
      storage,
      quickUnlock: quickUnlock,
      biometricUnlock: biometric,
      autoCheckAuth: false,
      isDefinitelyOffline: () async => false,
    );
    addTearDown(notifier.dispose);
    return notifier;
  }

  Future<AuthNotifier> lockedNotifier() async {
    final notifier = buildNotifier();
    await notifier.checkAuth();
    expect(notifier.state, isA<AuthAuthenticated>());
    storage.token = null;
    notifier.handleSessionInvalidation();
    await pumpEventQueue();
    return notifier;
  }

  setUp(() {
    storage = _Storage();
    repository = _Repository(storage);
    biometric = _Biometric();
    quickUnlock = QuickUnlockService(storage, iterations: 10);
  });

  group('QuickUnlockService', () {
    test('accepts the right PIN and is bound to its user', () async {
      await quickUnlock.setPin(7, '2468');

      expect(await quickUnlock.isConfiguredFor(7), isTrue);
      expect(await quickUnlock.isConfiguredFor(8), isFalse);
      expect(
        (await quickUnlock.verify(7, '2468')).status,
        PinCheckStatus.success,
      );
      expect(
        (await quickUnlock.verify(8, '2468')).status,
        PinCheckStatus.notConfigured,
      );
    });

    test('does not store the PIN itself', () async {
      await quickUnlock.setPin(7, '2468');

      expect(storage.quickUnlock.toString(), isNot(contains('2468')));
    });

    test('counts wrong PINs and erases setup after the limit', () async {
      await quickUnlock.setPin(7, '2468');

      for (var left = QuickUnlockService.maxAttempts - 1; left > 0; left--) {
        final check = await quickUnlock.verify(7, '0000');
        expect(check.status, PinCheckStatus.wrong);
        expect(check.remainingAttempts, left);
      }
      final last = await quickUnlock.verify(7, '0000');

      expect(last.status, PinCheckStatus.exhausted);
      expect(storage.quickUnlock, isNull);
    });

    test('a correct PIN resets the failure counter', () async {
      await quickUnlock.setPin(7, '2468');
      await quickUnlock.verify(7, '0000');
      await quickUnlock.verify(7, '2468');

      final check = await quickUnlock.verify(7, '0000');

      expect(check.remainingAttempts, QuickUnlockService.maxAttempts - 1);
    });

    test('rejects PINs with a wrong length or letters', () {
      expect(QuickUnlockService.isValidPin('123'), isFalse);
      expect(QuickUnlockService.isValidPin('12a4'), isFalse);
      expect(QuickUnlockService.isValidPin('1234'), isTrue);
    });
  });

  group('locked session', () {
    setUp(() {
      storage.offlineAuth = _vault(DateTime.now());
    });

    test(
      'session rejection locks and keeps the same session identity',
      () async {
        final notifier = await lockedNotifier();

        final state = notifier.state as AuthLocked;
        expect(state.sessionIdentity, _identity);
        expect(retainedSessionIdentity(state), _identity);
        expect(storage.offlineAuth, isNotNull);
        expect(state.canUnlockOffline, isFalse);
      },
    );

    test('app start without token opens the lock screen', () async {
      storage.token = null;
      final notifier = buildNotifier();

      await notifier.checkAuth();
      await pumpEventQueue();

      expect(notifier.state, isA<AuthLocked>());
    });

    test('PIN unlock continues offline with the same identity', () async {
      await quickUnlock.setPin(7, '2468');
      final notifier = await lockedNotifier();
      expect((notifier.state as AuthLocked).canUnlockOffline, isTrue);

      await notifier.unlockWithPin('2468');

      final state = notifier.state as AuthAuthenticated;
      expect(state.sessionIdentity, _identity);
      expect(state.isOnlineVerified, isFalse);
      expect(state.needsReauthentication, isTrue);
    });

    test('wrong PIN keeps the lock and reports attempts left', () async {
      await quickUnlock.setPin(7, '2468');
      final notifier = await lockedNotifier();

      await notifier.unlockWithPin('1111');

      final state = notifier.state as AuthLocked;
      expect(state.messageIsError, isTrue);
      expect(state.message, contains('${QuickUnlockService.maxAttempts - 1}'));
    });

    test('too many wrong PINs erase the local session', () async {
      await quickUnlock.setPin(7, '2468');
      final notifier = await lockedNotifier();

      for (var i = 0; i < QuickUnlockService.maxAttempts; i++) {
        await notifier.unlockWithPin('1111');
      }

      expect(notifier.state, isA<AuthError>());
      expect(storage.offlineAuth, isNull);
      expect(storage.quickUnlock, isNull);
      expect(biometric.disabled, isTrue);
    });

    test('offline unlock is not offered after 14 days', () async {
      storage.offlineAuth = _vault(
        DateTime.now().subtract(const Duration(days: 15)),
      );
      await quickUnlock.setPin(7, '2468');
      storage.token = null;
      final notifier = buildNotifier();
      await notifier.checkAuth();
      await pumpEventQueue();

      expect((notifier.state as AuthLocked).canUnlockOffline, isFalse);
      await notifier.unlockWithPin('2468');
      expect(notifier.state, isA<AuthLocked>());
    });

    test('password sign-in restores the same session identity', () async {
      final notifier = await lockedNotifier();

      await notifier.reauthenticate('secret');

      final state = notifier.state as AuthAuthenticated;
      expect(state.isOnlineVerified, isTrue);
      expect(state.sessionIdentity, _identity);
      expect(storage.token, 'token-new');
    });

    test('password sign-in returns to the locked organization', () async {
      repository.loginOrganizationId = 99;
      final notifier = await lockedNotifier();

      await notifier.reauthenticate('secret');

      expect(repository.switchedTo, [12]);
      expect((notifier.state as AuthAuthenticated).sessionIdentity, _identity);
    });

    test('failed password sign-in stays locked with a message', () async {
      repository.loginError = const ApiException(
        'Пароль не подошёл.',
        statusCode: 401,
      );
      final notifier = await lockedNotifier();

      await notifier.reauthenticate('wrong');

      final state = notifier.state as AuthLocked;
      expect(state.isSubmitting, isFalse);
      expect(state.messageIsError, isTrue);
      expect(state.sessionIdentity, _identity);
    });

    test('offline mode locks again when the queue needs the server', () async {
      await quickUnlock.setPin(7, '2468');
      final notifier = await lockedNotifier();
      await notifier.unlockWithPin('2468');

      final verified = await notifier.verifyOnlineForQueue();

      expect(verified, isFalse);
      expect(notifier.state, isA<AuthLocked>());
      expect((notifier.state as AuthLocked).sessionIdentity, _identity);
    });

    test('offline mode stays unlocked while there is no network', () async {
      await quickUnlock.setPin(7, '2468');
      var offline = false;
      final notifier = AuthNotifier(
        repository,
        storage,
        quickUnlock: quickUnlock,
        biometricUnlock: biometric,
        autoCheckAuth: false,
        isDefinitelyOffline: () async => offline,
      );
      addTearDown(notifier.dispose);
      await notifier.checkAuth();
      storage.token = null;
      notifier.handleSessionInvalidation();
      await pumpEventQueue();
      await notifier.unlockWithPin('2468');
      offline = true;

      expect(await notifier.verifyOnlineForQueue(), isFalse);
      expect(notifier.state, isA<AuthAuthenticated>());
    });

    test(
      'after a network relock a second PIN unlock is not interrupted',
      () async {
        await quickUnlock.setPin(7, '2468');
        final notifier = await lockedNotifier();
        await notifier.unlockWithPin('2468');
        await notifier.verifyOnlineForQueue();
        expect(notifier.state, isA<AuthLocked>());

        await notifier.unlockWithPin('2468');
        await notifier.verifyOnlineForQueue();

        expect(notifier.state, isA<AuthAuthenticated>());
      },
    );

    test('changed fingerprints switch the lock to PIN only', () async {
      await quickUnlock.setPin(7, '2468');
      await quickUnlock.setBiometricEnabled(7, true);
      final notifier = await lockedNotifier();
      expect((notifier.state as AuthLocked).canUseBiometrics, isTrue);
      biometric.next = BiometricResult.invalidated;

      await notifier.unlockWithBiometrics();

      final state = notifier.state as AuthLocked;
      expect(state.canUseBiometrics, isFalse);
      expect(await quickUnlock.biometricEnabledFor(7), isFalse);
    });

    test('biometric success unlocks offline', () async {
      await quickUnlock.setPin(7, '2468');
      await quickUnlock.setBiometricEnabled(7, true);
      final notifier = await lockedNotifier();

      await notifier.unlockWithBiometrics();

      expect(
        (notifier.state as AuthAuthenticated).needsReauthentication,
        isTrue,
      );
    });

    test('explicit sign-out erases PIN setup and local session', () async {
      await quickUnlock.setPin(7, '2468');
      final notifier = await lockedNotifier();

      await notifier.logout();

      expect(notifier.state, isA<AuthUnauthenticated>());
      expect(storage.quickUnlock, isNull);
      expect(storage.offlineAuth, isNull);
    });
  });

  test('without a saved session rejection signs out as before', () async {
    final notifier = buildNotifier();
    storage.offlineAuth = null;
    storage.token = null;

    notifier.handleSessionInvalidation();
    await pumpEventQueue();

    expect(notifier.state, isA<AuthUnauthenticated>());
  });

  test('retained identity is cleared only for signed-out states', () {
    expect(retainedSessionIdentity(AuthUnauthenticated()), isNull);
    expect(retainedSessionIdentity(AuthError('x')), isNull);
    expect(retainedSessionIdentity(AuthLoading()), isNull);
    expect(retainedSessionIdentity(AuthLocked(_user(), _identity)), _identity);
  });

  group('lock screen', () {
    Future<AuthNotifier> pumpLock(
      WidgetTester tester, {
      bool pin = false,
    }) async {
      storage.offlineAuth = _vault(DateTime.now());
      final notifier = AuthNotifier(
        repository,
        storage,
        quickUnlock: quickUnlock,
        biometricUnlock: biometric,
        autoCheckAuth: false,
        isDefinitelyOffline: () async => false,
      );
      await tester.runAsync(() async {
        if (pin) await quickUnlock.setPin(7, '2468');
        await notifier.checkAuth();
        storage.token = null;
        notifier.handleSessionInvalidation();
        await pumpEventQueue();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith((ref) => notifier)],
          child: const MaterialApp(home: LockScreen()),
        ),
      );
      await tester.pump();
      return notifier;
    }

    testWidgets('offers password sign-in and hides PIN when not set up', (
      tester,
    ) async {
      await pumpLock(tester);

      expect(find.text('Войти с паролем'), findsOneWidget);
      expect(find.text('Нет связи?'), findsNothing);
      expect(find.textContaining('Сессия завершена'), findsOneWidget);
    });

    testWidgets('password sign-in restores the session', (tester) async {
      final notifier = await pumpLock(tester);

      await tester.enterText(find.byType(TextField).first, 'secret');
      await tester.runAsync(() async {
        await tester.tap(find.text('Войти'));
        await pumpEventQueue();
      });
      await tester.pump();

      expect(repository.loginCalls, 1);
      expect(notifier.state, isA<AuthAuthenticated>());
    });

    testWidgets('four PIN digits unlock work without connection', (
      tester,
    ) async {
      final notifier = await pumpLock(tester, pin: true);

      expect(find.text('Нет связи?'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.enterText(find.byType(TextField).last, '2468');
        await pumpEventQueue(times: 50);
      });
      await tester.pump();

      expect(
        (notifier.state as AuthAuthenticated).needsReauthentication,
        isTrue,
      );
    });

    testWidgets('sign-out warns that unsent changes will be removed', (
      tester,
    ) async {
      await pumpLock(tester);

      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ещё не отправлены'), findsOneWidget);
      expect(find.text('Выйти и удалить'), findsOneWidget);
    });
  });
}
