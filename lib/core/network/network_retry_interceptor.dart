import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

class NetworkRetryInterceptor extends Interceptor {
  const NetworkRetryInterceptor(
    this._dio, {
    this.maxRetries = 1,
    this.delay = const Duration(milliseconds: 350),
  });

  static const _attemptExtraKey = 'network_retry_attempt';
  static const _skipExtraKey = 'skip_network_retry';
  static const _transientHttpStatuses = {408, 429, 500, 502, 503, 504};

  final Dio _dio;
  final int maxRetries;
  final Duration delay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final requestOptions = err.requestOptions;
    final attempt = (requestOptions.extra[_attemptExtraKey] as int?) ?? 0;
    requestOptions.extra = {
      ...requestOptions.extra,
      _attemptExtraKey: attempt + 1,
    };

    try {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final response = await _dio.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (error, stackTrace) {
      handler.next(
        DioException(
          requestOptions: requestOptions,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  bool _shouldRetry(DioException error) {
    if (error.requestOptions.cancelToken?.isCancelled == true) {
      return false;
    }

    if (error.requestOptions.extra[_skipExtraKey] == true) {
      return false;
    }

    final attempt = (error.requestOptions.extra[_attemptExtraKey] as int?) ?? 0;
    if (attempt >= maxRetries) {
      return false;
    }

    if (!_isSafeMethod(error.requestOptions.method)) {
      return false;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return _isTransientHttpStatus(statusCode);
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown => _isTransientIoError(error.error),
      _ => false,
    };
  }

  bool _isSafeMethod(String method) {
    final normalized = method.toUpperCase();
    return normalized == 'GET' || normalized == 'HEAD';
  }

  bool _isTransientHttpStatus(int statusCode) {
    return _transientHttpStatuses.contains(statusCode);
  }

  bool _isTransientIoError(Object? error) {
    return error is SocketException ||
        error is HandshakeException ||
        error is HttpException ||
        error is TimeoutException;
  }
}
