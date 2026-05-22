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
      throwsA(isA<ApiException>()),
    );
    expect(await storage.getToken(), isNull);
  });
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
    {"id": 3, "name": "ПроХелпер", "is_active": true}
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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
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
