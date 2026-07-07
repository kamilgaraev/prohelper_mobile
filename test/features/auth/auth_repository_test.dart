import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';

void main() {
  test('login success stores token and loads profile', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 200,
              body: '{"data":{"token":"token-1"}}',
            ),
          )
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"data":${_userJson()}}'),
          );
    final storage = _MemorySecureStorage();
    final repository = AuthRepository(_dio(adapter), storage);

    final user = await repository.login('foreman@example.test', 'secret');

    expect(user.serverId, 7);
    expect(user.email, 'foreman@example.test');
    expect(await storage.getToken(), 'token-1');
    expect(adapter.requests.map((request) => request.path), [
      '/auth/login',
      '/auth/me',
    ]);
    expect(adapter.requests[1].headers['Authorization'], 'Bearer token-1');
  });

  test('login validation error returns business message', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 422,
              body: '{"message":"Укажите email и пароль"}',
            ),
          );
    final repository = AuthRepository(_dio(adapter), _MemorySecureStorage());

    await expectLater(
      repository.login('', ''),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Укажите email и пароль',
        ),
      ),
    );
  });

  test('invalid credentials do not store token', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 401,
              body: '{"message":"Неверный email или пароль"}',
            ),
          );
    final storage = _MemorySecureStorage();
    final repository = AuthRepository(_dio(adapter), storage);

    await expectLater(
      repository.login('foreman@example.test', 'wrong'),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.message,
              'message',
              'Email или пароль не подошли. Проверьте данные и попробуйте еще раз.',
            )
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );
    expect(await storage.getToken(), isNull);
  });

  test('login preserves profile loading error after token is issued', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 200,
              body: '{"data":{"token":"token-1"}}',
            ),
          )
          ..responses.add(
            _AdapterResponse(
              statusCode: 500,
              body: '{"message":"Профиль временно недоступен"}',
            ),
          );
    final storage = _MemorySecureStorage();
    final repository = AuthRepository(_dio(adapter), storage);

    await expectLater(
      repository.login('foreman@example.test', 'secret'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Профиль временно недоступен',
        ),
      ),
    );
    expect(await storage.getToken(), 'token-1');
  });

  test(
    'switch organization stores returned token and reloads profile',
    () async {
      final adapter =
          _AuthHttpAdapter()
            ..responses.add(
              _AdapterResponse(
                statusCode: 200,
                body: '{"data":{"token":"organization-token"}}',
              ),
            )
            ..responses.add(
              _AdapterResponse(
                statusCode: 200,
                body: '{"data":${_userJson()}}',
              ),
            );
      final storage = _MemorySecureStorage()..token = 'old-token';
      final repository = AuthRepository(_dio(adapter), storage);

      final user = await repository.switchOrganization(3);

      expect(user.serverId, 7);
      expect(await storage.getToken(), 'organization-token');
      expect(adapter.requests.map((request) => request.path), [
        '/auth/switch-organization',
        '/auth/me',
      ]);
    },
  );

  test('switch organization requires a replacement token', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"data":{}}'),
          );
    final storage = _MemorySecureStorage()..token = 'old-token';
    final repository = AuthRepository(_dio(adapter), storage);

    await expectLater(
      repository.switchOrganization(3),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Не удалось переключить организацию.',
        ),
      ),
    );
    expect(await storage.getToken(), 'old-token');
  });

  test('logout calls backend with snapshot token and clears storage', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(_AdapterResponse(statusCode: 200, body: '{}'));
    final storage = _MemorySecureStorage()..token = 'logout-token';
    final repository = AuthRepository(_dio(adapter), storage);

    await repository.logout();

    expect(await storage.getToken(), isNull);
    expect(adapter.requests.single.path, '/auth/logout');
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer logout-token',
    );
  });

  test('logout clears storage even when backend request fails', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(_AdapterResponse(statusCode: 500, body: '{}'));
    final storage = _MemorySecureStorage()..token = 'logout-token';
    final repository = AuthRepository(_dio(adapter), storage);

    await repository.logout();

    expect(await storage.getToken(), isNull);
  });

  test(
    'logout does not clear a newer token saved while request is pending',
    () async {
      final storage = _MemorySecureStorage()..token = 'old-token';
      final adapter =
          _AuthHttpAdapter()
            ..onFetch = (_) async {
              await storage.saveToken('new-token');
            }
            ..responses.add(_AdapterResponse(statusCode: 200, body: '{}'));
      final repository = AuthRepository(_dio(adapter), storage);

      await repository.logout();

      expect(await storage.getToken(), 'new-token');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer old-token',
      );
    },
  );
}

Dio _dio(_AuthHttpAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.prohelper.test',
      headers: const <String, dynamic>{'Content-Type': 'application/json'},
    ),
  )..httpClientAdapter = adapter;
}

String _userJson() {
  return '''
{
  "id": 7,
  "email": "foreman@example.test",
  "name": "Иван Прораб",
  "current_organization_id": 3,
  "organizations": [
    {"id": 3, "name": "МОСТ", "is_active": true}
  ],
  "auth": {
    "roles": ["foreman"],
    "modules": {"site-requests": {"can_view": true}}
  }
}
''';
}

class _MemorySecureStorage extends SecureStorageService {
  String? token;

  @override
  Future<void> saveToken(String token) async {
    this.token = token;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> clearToken() async {
    token = null;
  }
}

class _AuthHttpAdapter implements HttpClientAdapter {
  final responses = Queue<_AdapterResponse>();
  final requests = <RequestOptions>[];
  Future<void> Function(RequestOptions options)? onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    await onFetch?.call(options);
    final response = responses.removeFirst();

    return ResponseBody.fromString(
      response.body,
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterResponse {
  const _AdapterResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
