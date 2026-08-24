import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/auth_interceptor.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_session_provider.dart';

void main() {
  test('token refresh saves new token and retries original request', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'))
          ..responses.add(
            _AdapterResponse(
              statusCode: 200,
              body: '{"data":{"token":"fresh-token"}}',
            ),
          )
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"data":{"ok":true}}'),
          );
    final storage = _MemorySecureStorage()..token = 'expired-token';
    final container = _container(adapter, storage);
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    final response = await dio.get<dynamic>('/protected');

    expect(response.statusCode, 200);
    expect(await storage.getToken(), 'fresh-token');
    expect(adapter.requests.map((request) => request.path), [
      '/protected',
      '/auth/refresh',
      '/protected',
    ]);
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer fresh-token',
    );
  });

  test('expired session clears token and increments session version', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'))
          ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'));
    final storage = _MemorySecureStorage()..token = 'expired-token';
    final container = _container(adapter, storage);
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(await storage.getToken(), isNull);
    expect(container.read(authSessionVersionProvider), 1);
  });

  test('inactive organization membership clears the local session', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 403,
              body:
                  '{"success":false,"code":"organization_membership_inactive"}',
            ),
          );
    final storage = _MemorySecureStorage()..token = 'member-token';
    final container = _container(adapter, storage);
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(await storage.getToken(), isNull);
    expect(container.read(authSessionVersionProvider), 1);
    expect(adapter.requests.map((request) => request.path), ['/protected']);
  });

  test('ordinary forbidden response preserves the authenticated session', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 403,
              body: '{"success":false,"code":"http_403"}',
            ),
          );
    final storage = _MemorySecureStorage()..token = 'member-token';
    final container = _container(adapter, storage);
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(await storage.getToken(), 'member-token');
    expect(container.read(authSessionVersionProvider), 0);
  });

  test('does not replace explicit authorization header', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(_AdapterResponse(statusCode: 200, body: '{}'));
    final storage = _MemorySecureStorage()..token = 'current-token';
    final container = _container(adapter, storage);
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await dio.post<dynamic>(
      '/auth/logout',
      options: Options(headers: {'Authorization': 'Bearer snapshot-token'}),
    );

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer snapshot-token',
    );
  });

  test('does not attach token when auth is explicitly skipped', () async {
    final adapter =
        _AuthHttpAdapter()
          ..responses.add(_AdapterResponse(statusCode: 200, body: '{}'));
    final storage = _MemorySecureStorage()..token = 'current-token';
    final container = _container(adapter, storage);
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;

    await dio.post<dynamic>(
      '/auth/logout',
      options: Options(extra: {'skip_auth': true}),
    );

    expect(adapter.requests.single.headers.containsKey('Authorization'), false);
  });

  test(
    'does not refresh skipped auth requests after unauthorized response',
    () async {
      final adapter =
          _AuthHttpAdapter()
            ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'))
            ..responses.add(
              _AdapterResponse(
                statusCode: 200,
                body: '{"data":{"token":"fresh-token"}}',
              ),
            );
      final storage = _MemorySecureStorage()..token = 'current-token';
      final container = _container(adapter, storage);
      addTearDown(container.dispose);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      await expectLater(
        dio.post<dynamic>(
          '/auth/logout',
          options: Options(
            headers: {'Authorization': 'Bearer snapshot-token'},
            extra: {'skip_auth': true},
          ),
        ),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests.map((request) => request.path), ['/auth/logout']);
      expect(await storage.getToken(), 'current-token');
      expect(container.read(authSessionVersionProvider), 0);
    },
  );
}

ProviderContainer _container(
  _AuthHttpAdapter adapter,
  _MemorySecureStorage storage,
) {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authRefreshClientFactoryProvider.overrideWithValue(
        (options) => Dio(options)..httpClientAdapter = adapter,
      ),
      authRetryClientFactoryProvider.overrideWithValue(
        () => Dio()..httpClientAdapter = adapter,
      ),
    ],
  );
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
