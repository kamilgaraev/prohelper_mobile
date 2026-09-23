import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.getMeError, this.loginError})
    : super(Dio(), _MemoryStorage());

  final Object? getMeError;
  final Object? loginError;

  @override
  Future<User> getMe({String? token}) async {
    final error = getMeError;
    if (error != null) {
      throw error;
    }

    return User()
      ..serverId = 7
      ..email = 'foreman@example.test'
      ..name = 'Иван Прораб'
      ..roles = <String>[]
      ..organizationsJson = '[]'
      ..permissionsJson = '{}';
  }

  @override
  Future<User> login(String email, String password) async {
    final error = loginError;
    if (error != null) {
      throw error;
    }

    return User()
      ..serverId = 7
      ..email = email
      ..name = 'Иван Прораб'
      ..roles = <String>[]
      ..organizationsJson = '[]'
      ..permissionsJson = '{}';
  }
}

class _BlockingOfflineSaveStorage extends _MemoryStorage {
  final saveStarted = Completer<void>();
  final allowSave = Completer<void>();
  bool _blockNextSave = true;

  @override
  Future<void> saveOfflineAuth(Map<String, dynamic> value) async {
    if (_blockNextSave) {
      _blockNextSave = false;
      saveStarted.complete();
      await allowSave.future;
    }
    await super.saveOfflineAuth(value);
  }
}

class _LogoutCheckingRepository extends _FakeAuthRepository {
  _LogoutCheckingRepository(this.storage) : super();

  final _MemoryStorage storage;
  String? tokenAtLogout;
  String? installationIdAtLogout;

  @override
  Future<void> logout({String? installationId}) async {
    tokenAtLogout = await storage.getToken();
    installationIdAtLogout = installationId;
    await storage.clearToken();
  }
}

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage();

  String? token = 'token-1';
  int getTokenCalls = 0;
  int clearCalls = 0;
  String? sessionId;
  String? pushInstallationId;
  Map<String, dynamic>? offlineAuth;

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return token;
  }

  @override
  Future<String?> getPushInstallationId() async => pushInstallationId;

  @override
  Future<void> clearToken() async {
    clearCalls += 1;
    token = null;
    await clearOfflineAuth();
  }

  @override
  Future<String> ensureSessionId() async => sessionId ??= 'session-1';

  @override
  Future<void> saveOfflineAuth(Map<String, dynamic> value) async {
    offlineAuth = Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, dynamic>?> getOfflineAuth() async => offlineAuth;

  @override
  Future<void> clearOfflineAuth() async {
    offlineAuth = null;
    sessionId = null;
  }

  @override
  Future<void> rebindOfflineAuthToken(String token) async {
    if (offlineAuth != null) offlineAuth!['token'] = token;
  }
}

class _BlockingClearStorage extends _MemoryStorage {
  final clearStarted = Completer<void>();
  final allowClear = Completer<void>();

  @override
  Future<void> clearToken() async {
    clearCalls += 1;
    if (!clearStarted.isCompleted) {
      clearStarted.complete();
    }

    await allowClear.future;
    token = null;
  }

  void finishClear() {
    if (!allowClear.isCompleted) {
      allowClear.complete();
    }
  }
}

void main() {
  test('checkAuth can be delayed until after the first app frame', () async {
    final storage = _MemoryStorage();
    final notifier = AuthNotifier(
      _FakeAuthRepository(),
      storage,
      autoCheckAuth: false,
    );
    addTearDown(notifier.dispose);

    expect(notifier.state, isA<AuthInitial>());
    expect(storage.getTokenCalls, 0);

    await notifier.checkAuth();
    await pumpEventQueue();

    expect(storage.getTokenCalls, 2);
    expect(notifier.state, isA<AuthAuthenticated>());
  });

  test('checkAuth preserves token on recoverable profile errors', () async {
    final storage = _MemoryStorage();
    final notifier = AuthNotifier(
      _FakeAuthRepository(
        getMeError: const ApiException(
          'Проверьте дату и время на устройстве, затем повторите вход.',
        ),
      ),
      storage,
    );
    addTearDown(notifier.dispose);

    await pumpEventQueue();

    expect(
      notifier.state,
      isA<AuthError>().having(
        (state) => state.message,
        'message',
        'Проверьте дату и время на устройстве, затем повторите вход.',
      ),
    );
    expect(storage.clearCalls, 0);
    expect(await storage.getToken(), 'token-1');
  });

  test('checkAuth clears token only when session is rejected', () async {
    final storage = _MemoryStorage();
    final notifier = AuthNotifier(
      _FakeAuthRepository(
        getMeError: const ApiException('Сессия истекла.', statusCode: 401),
      ),
      storage,
    );
    addTearDown(notifier.dispose);

    await pumpEventQueue();

    expect(notifier.state, isA<AuthUnauthenticated>());
    expect(storage.clearCalls, 1);
    expect(await storage.getToken(), isNull);
  });

  test('checkAuth opens login before expired token cleanup finishes', () async {
    final storage = _BlockingClearStorage();
    final notifier = AuthNotifier(
      _FakeAuthRepository(
        getMeError: const ApiException('Сессия истекла.', statusCode: 401),
      ),
      storage,
    );
    addTearDown(() {
      storage.finishClear();
      notifier.dispose();
    });

    await pumpEventQueue();

    expect(storage.clearStarted.isCompleted, isTrue);
    expect(notifier.state, isA<AuthUnauthenticated>());
    expect(await storage.getToken(), 'token-1');

    storage.finishClear();
    await pumpEventQueue();

    expect(await storage.getToken(), isNull);
  });

  test('clearError returns login screen to editable state', () async {
    final storage = _MemoryStorage()..token = null;
    final notifier = AuthNotifier(
      _FakeAuthRepository(
        loginError: const ApiException('Email или пароль не подошли.'),
      ),
      storage,
    );
    addTearDown(notifier.dispose);

    await pumpEventQueue();

    await notifier.login('foreman@example.test', 'wrong');

    expect(notifier.state, isA<AuthError>());

    notifier.clearError();

    expect(notifier.state, isA<AuthUnauthenticated>());
    expect(storage.clearCalls, 0);
  });

  test('offline restore is bound to token and is unverified', () async {
    final storage = _MemoryStorage();
    final confirmedAt = DateTime.now().toUtc();
    storage.offlineAuth = {
      'token': 'token-1',
      'session_id': 'session-1',
      'user_id': 7,
      'organization_id': 12,
      'confirmed_at': confirmedAt.toIso8601String(),
      'user': {
        'server_id': 7,
        'email': 'offline@example.test',
        'name': 'Офлайн',
        'organization_id': 12,
        'organization_name': 'МОСТ',
        'organizations_json': '[]',
        'roles': <String>['foreman'],
        'permissions_json': '{}',
      },
    };
    final notifier = AuthNotifier(
      _FakeAuthRepository(getMeError: const ApiException('Нет сети.')),
      storage,
    );
    addTearDown(notifier.dispose);

    await pumpEventQueue();

    final auth = notifier.state as AuthAuthenticated;
    expect(auth.user.email, 'offline@example.test');
    expect(auth.isOnlineVerified, isFalse);
    expect(auth.sessionIdentity?.userId, 7);
    expect(auth.sessionIdentity?.organizationId, 12);
    expect(auth.sessionIdentity?.sessionId, 'session-1');
  });

  test(
    'offline restore rejects another token and expired confirmation',
    () async {
      final storage = _MemoryStorage()..token = 'different-token';
      storage.offlineAuth = {
        'token': 'token-1',
        'session_id': 'session-1',
        'user_id': 7,
        'organization_id': 12,
        'confirmed_at':
            DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 15))
                .toIso8601String(),
        'user': {
          'server_id': 7,
          'email': 'stale@example.test',
          'name': 'Старый профиль',
          'organization_id': 12,
          'organizations_json': '[]',
          'roles': <String>[],
          'permissions_json': '{}',
        },
      };
      final notifier = AuthNotifier(
        _FakeAuthRepository(getMeError: const ApiException('Нет сети.')),
        storage,
      );
      addTearDown(notifier.dispose);

      await pumpEventQueue();

      expect(notifier.state, isA<AuthError>());
    },
  );

  test(
    'logout sends the saved bearer before cleaning local auth cache',
    () async {
      final storage =
          _MemoryStorage()
            ..token = 'saved-bearer'
            ..pushInstallationId = 'install-1';
      storage.offlineAuth = {'session_id': 'session-1'};
      final repository = _LogoutCheckingRepository(storage);
      var invalidationCount = 0;
      final notifier = AuthNotifier(
        repository,
        storage,
        autoCheckAuth: false,
        onSessionInvalidated: () => invalidationCount++,
      );
      addTearDown(notifier.dispose);

      await notifier.logout();

      expect(repository.tokenAtLogout, 'saved-bearer');
      expect(repository.installationIdAtLogout, 'install-1');
      expect(storage.token, isNull);
      expect(storage.offlineAuth, isNull);
      expect(invalidationCount, 1);
      expect(notifier.state, isA<AuthUnauthenticated>());
    },
  );

  test('stale profile write cannot replace a later login bundle', () async {
    final storage = _BlockingOfflineSaveStorage();
    final notifier = AuthNotifier(
      _FakeAuthRepository(),
      storage,
      autoCheckAuth: false,
    );
    addTearDown(() {
      if (!storage.allowSave.isCompleted) storage.allowSave.complete();
      notifier.dispose();
    });

    final profileCheck = notifier.checkAuth();
    await storage.saveStarted.future;
    final newLogin = notifier.login('new@example.test', 'password');
    storage.allowSave.complete();
    await Future.wait([profileCheck, newLogin]);

    expect(notifier.state.user?.email, 'new@example.test');
    expect(storage.offlineAuth?['user']['email'], 'new@example.test');
  });
}
