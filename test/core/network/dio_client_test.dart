import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/network/network_retry_interceptor.dart';

void main() {
  test('debug network logging does not expose request or response bodies', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    final logInterceptor = dio.interceptors.whereType<LogInterceptor>().single;

    expect(logInterceptor.requestHeader, isFalse);
    expect(logInterceptor.requestBody, isFalse);
    expect(logInterceptor.responseHeader, isFalse);
    expect(logInterceptor.responseBody, isFalse);
  });

  test('retries transient safe GET failures once', () async {
    final adapter =
        _RetryHttpAdapter()
          ..outcomes.add(
            _AdapterFailure(
              type: DioExceptionType.unknown,
              error: HandshakeException(
                'Connection terminated during handshake',
              ),
            ),
          )
          ..outcomes.add(
            const _AdapterResponse(statusCode: 200, body: '{"data":[]}'),
          );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(NetworkRetryInterceptor(dio, delay: Duration.zero));

    final response = await dio.get<dynamic>('/warehouse/warehouses/9/tasks');

    expect(response.statusCode, 200);
    expect(adapter.requests.map((request) => request.method), ['GET', 'GET']);
  });

  test('retries transient safe GET HTTP status failures once', () async {
    final adapter =
        _RetryHttpAdapter()
          ..outcomes.add(
            const _AdapterResponse(
              statusCode: 503,
              body: '{"message":"temporarily unavailable"}',
            ),
          )
          ..outcomes.add(
            const _AdapterResponse(statusCode: 200, body: '{"data":[]}'),
          );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(NetworkRetryInterceptor(dio, delay: Duration.zero));

    final response = await dio.get<dynamic>('/mobile/notifications');

    expect(response.statusCode, 200);
    expect(adapter.requests.map((request) => request.method), ['GET', 'GET']);
  });

  test('does not retry auth or validation HTTP failures', () async {
    final adapter =
        _RetryHttpAdapter()
          ..outcomes.add(
            const _AdapterResponse(
              statusCode: 401,
              body: '{"message":"unauthenticated"}',
            ),
          );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(NetworkRetryInterceptor(dio, delay: Duration.zero));

    await expectLater(
      dio.get<dynamic>('/mobile/notifications'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests.map((request) => request.method), ['GET']);
  });

  test('does not retry unsafe methods', () async {
    final adapter =
        _RetryHttpAdapter()
          ..outcomes.add(
            _AdapterFailure(
              type: DioExceptionType.unknown,
              error: HandshakeException(
                'Connection terminated during handshake',
              ),
            ),
          );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(NetworkRetryInterceptor(dio, delay: Duration.zero));

    await expectLater(
      dio.post<dynamic>('/warehouse/operations/receipt'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests.map((request) => request.method), ['POST']);
  });

  test('does not retry unsafe HTTP status failures', () async {
    final adapter =
        _RetryHttpAdapter()
          ..outcomes.add(
            const _AdapterResponse(
              statusCode: 503,
              body: '{"message":"temporarily unavailable"}',
            ),
          );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(NetworkRetryInterceptor(dio, delay: Duration.zero));

    await expectLater(
      dio.post<dynamic>('/workflow/tasks/17/approve'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests.map((request) => request.method), ['POST']);
  });
}

class _RetryHttpAdapter implements HttpClientAdapter {
  final outcomes = Queue<Object>();
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    final outcome = outcomes.removeFirst();

    if (outcome is _AdapterFailure) {
      throw DioException(
        requestOptions: options,
        type: outcome.type,
        error: outcome.error,
      );
    }

    final response = outcome as _AdapterResponse;
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

class _AdapterFailure {
  const _AdapterFailure({required this.type, required this.error});

  final DioExceptionType type;
  final Object error;
}
