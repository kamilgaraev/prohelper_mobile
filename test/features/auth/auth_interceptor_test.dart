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
  for (final refreshStatus in [200, 503]) {
    test(
      'concurrent unauthorized requests share refresh with status $refreshStatus',
      () async {
        final bothStarted = Completer<void>();
        var unauthorizedCount = 0;
        var refreshCount = 0;
        final adapter = _AuthHttpAdapter();
        adapter.respond = (options) async {
          if (options.path == '/auth/refresh') {
            refreshCount++;
            await bothStarted.future;
            await Future<void>.delayed(Duration.zero);
            return _AdapterResponse(
              statusCode: refreshStatus,
              body: '{"data":{"token":"fresh-token"}}',
            );
          }
          if (options.headers['Authorization'] == 'Bearer expired-token') {
            if (++unauthorizedCount == 2) {
              bothStarted.complete();
            }
            return _AdapterResponse(statusCode: 401, body: '{}');
          }
          return _AdapterResponse(statusCode: 200, body: '{}');
        };
        final storage = _MemorySecureStorage()..token = 'expired-token';
        final container = _container(adapter, storage);
        addTearDown(container.dispose);
        final dio = container.read(dioProvider)..httpClientAdapter = adapter;

        Future<void> request(String path) async {
          if (refreshStatus == 200) {
            expect((await dio.post<dynamic>(path)).statusCode, 200);
          } else {
            await expectLater(
              dio.post<dynamic>(path),
              throwsA(
                isA<DioException>().having(
                  (error) => error.response?.statusCode,
                  'status',
                  refreshStatus,
                ),
              ),
            );
          }
        }

        await Future.wait([request('/first'), request('/second')]);
        expect(refreshCount, 1);
        expect(
          storage.token,
          refreshStatus == 200 ? 'fresh-token' : 'expired-token',
        );
        expect(container.read(authSessionVersionProvider), 0);
      },
    );
  }

  test(
    'late 401 uses already refreshed token without another refresh',
    () async {
      final firstRetried = Completer<void>();
      var refreshCount = 0;
      final adapter = _AuthHttpAdapter();
      adapter.respond = (options) async {
        if (options.path == '/auth/refresh') {
          refreshCount++;
          return _AdapterResponse(
            statusCode: 200,
            body: '{"data":{"token":"fresh-token"}}',
          );
        }
        if (options.headers['Authorization'] == 'Bearer expired-token') {
          if (options.path == '/slow') {
            await firstRetried.future;
          }
          return _AdapterResponse(statusCode: 401, body: '{}');
        }
        if (options.path == '/fast') {
          firstRetried.complete();
        }
        return _AdapterResponse(statusCode: 200, body: '{}');
      };
      final storage = _MemorySecureStorage()..token = 'expired-token';
      final container = _container(adapter, storage);
      addTearDown(container.dispose);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;
      final responses = await Future.wait([
        dio.post<dynamic>('/slow'),
        dio.post<dynamic>('/fast'),
      ]);
      expect(responses.map((response) => response.statusCode), [200, 200]);
      expect(refreshCount, 1);
      expect(storage.token, 'fresh-token');
    },
  );

  test('refresh result cannot restore session after logout', () async {
    final storage = _MemorySecureStorage()..token = 'expired-token';
    final adapter = _AuthHttpAdapter();
    adapter.respond = (options) async {
      if (options.path == '/auth/refresh') {
        await storage.clearToken();
        return _AdapterResponse(
          statusCode: 200,
          body: '{"data":{"token":"fresh-token"}}',
        );
      }
      return _AdapterResponse(statusCode: 401, body: '{}');
    };
    final container = _container(adapter, storage);
    addTearDown(container.dispose);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;
    await expectLater(
      dio.post<dynamic>('/protected'),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(storage.token, isNull);
    expect(adapter.requests.length, 2);
  });

  for (final duringRefresh in [true, false]) {
    for (final status in [401, 403]) {
      test(
        'confirmed session rejection $status during ${duringRefresh ? 'refresh' : 'retry'} logs out',
        () async {
          final adapter =
              _AuthHttpAdapter()
                ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'));
          if (!duringRefresh) {
            adapter.responses.add(
              _AdapterResponse(
                statusCode: 200,
                body: '{"data":{"token":"fresh-token"}}',
              ),
            );
          }
          adapter.responses.add(
            _AdapterResponse(
              statusCode: status,
              body: '{"code":"organization_membership_inactive"}',
            ),
          );
          final storage = _MemorySecureStorage()..token = 'expired-token';
          final container = _container(adapter, storage);
          addTearDown(container.dispose);
          final dio = container.read(dioProvider)..httpClientAdapter = adapter;
          await expectLater(
            dio.post<dynamic>('/protected'),
            throwsA(isA<DioException>()),
          );
          expect(storage.token, isNull);
          expect(container.read(authSessionVersionProvider), 1);
        },
      );
    }
  }

  for (final status in [403, 429, 500, 503]) {
    test(
      'refresh failure $status preserves token and reports real error',
      () async {
        final adapter =
            _AuthHttpAdapter()
              ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'))
              ..responses.add(_AdapterResponse(statusCode: status, body: '{}'));
        final storage = _MemorySecureStorage()..token = 'expired-token';
        final container = _container(adapter, storage);
        addTearDown(container.dispose);
        final dio = container.read(dioProvider)..httpClientAdapter = adapter;

        await expectLater(
          dio.post<dynamic>('/protected'),
          throwsA(
            isA<DioException>().having(
              (error) => error.response?.statusCode,
              'status',
              status,
            ),
          ),
        );

        expect(storage.token, 'expired-token');
        expect(container.read(authSessionVersionProvider), 0);
      },
    );
  }

  for (final status in [403, 422, 429, 500, 503]) {
    test('retry failure $status preserves refreshed token', () async {
      final adapter =
          _AuthHttpAdapter()
            ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'))
            ..responses.add(
              _AdapterResponse(
                statusCode: 200,
                body: '{"data":{"token":"fresh-token"}}',
              ),
            )
            ..responses.add(_AdapterResponse(statusCode: status, body: '{}'));
      final storage = _MemorySecureStorage()..token = 'expired-token';
      final container = _container(adapter, storage);
      addTearDown(container.dispose);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      await expectLater(
        dio.post<dynamic>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(storage.token, 'fresh-token');
      expect(container.read(authSessionVersionProvider), 0);
    });
  }

  for (final duringRefresh in [true, false]) {
    test(
      'timeout during ${duringRefresh ? 'refresh' : 'retry'} preserves session',
      () async {
        final adapter =
            _AuthHttpAdapter()
              ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'));
        if (!duringRefresh) {
          adapter.responses.add(
            _AdapterResponse(
              statusCode: 200,
              body: '{"data":{"token":"fresh-token"}}',
            ),
          );
        }
        adapter.responses.add(
          _AdapterResponse(
            statusCode: 0,
            body: '',
            errorType: DioExceptionType.receiveTimeout,
          ),
        );
        final storage = _MemorySecureStorage()..token = 'expired-token';
        final container = _container(adapter, storage);
        addTearDown(container.dispose);
        final dio = container.read(dioProvider)..httpClientAdapter = adapter;

        await expectLater(
          dio.post<dynamic>('/protected'),
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.receiveTimeout,
            ),
          ),
        );

        expect(storage.token, duringRefresh ? 'expired-token' : 'fresh-token');
        expect(container.read(authSessionVersionProvider), 0);
      },
    );
  }

  test(
    'malformed refresh response preserves session without exposing original 401',
    () async {
      final adapter =
          _AuthHttpAdapter()
            ..responses.add(_AdapterResponse(statusCode: 401, body: '{}'))
            ..responses.add(_AdapterResponse(statusCode: 200, body: '{}'));
      final storage = _MemorySecureStorage()..token = 'expired-token';
      final container = _container(adapter, storage);
      addTearDown(container.dispose);
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;

      await expectLater(
        dio.post<dynamic>('/protected'),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            isNot(401),
          ),
        ),
      );
      expect(storage.token, 'expired-token');
      expect(container.read(authSessionVersionProvider), 0);
    },
  );

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

  test(
    'ordinary forbidden response preserves the authenticated session',
    () async {
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
    },
  );

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

  @override
  Future<void> rebindOfflineAuthToken(String token) async {
    this.token = token;
  }
}

class _AuthHttpAdapter implements HttpClientAdapter {
  final responses = Queue<_AdapterResponse>();
  final requests = <RequestOptions>[];
  Future<_AdapterResponse> Function(RequestOptions)? respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    final response =
        respond == null ? responses.removeFirst() : await respond!(options);

    if (response.errorType != null) {
      throw DioException(requestOptions: options, type: response.errorType!);
    }

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
  const _AdapterResponse({
    required this.statusCode,
    required this.body,
    this.errorType,
  });

  final int statusCode;
  final String body;
  final DioExceptionType? errorType;
}
