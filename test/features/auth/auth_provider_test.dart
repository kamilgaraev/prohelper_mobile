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
      ..name = 'Иван Прораб';
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
      ..name = 'Иван Прораб';
  }
}

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage();

  String? token = 'token-1';
  int getTokenCalls = 0;
  int clearCalls = 0;

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return token;
  }

  @override
  Future<void> clearToken() async {
    clearCalls += 1;
    token = null;
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

    expect(storage.getTokenCalls, 1);
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
}
