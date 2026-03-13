import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../storage/secure_storage_service.dart';
import '../../features/auth/domain/auth_session_provider.dart';

class AuthInterceptor extends Interceptor {
  static Future<String?>? _refreshFuture;
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _ref.read(secureStorageProvider).getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final requestOptions = err.requestOptions;
    final isLoginRequest = requestOptions.path.endsWith('/auth/login');
    final isRefreshRequest = requestOptions.path.endsWith('/auth/refresh');
    final isRetried = requestOptions.extra['auth_retry'] == true;

    if (isLoginRequest) {
      handler.next(err);
      return;
    }

    if (isRefreshRequest || isRetried) {
      await _invalidateSession();
      handler.next(err);
      return;
    }

    final refreshedToken = await _refreshToken(requestOptions);
    if (refreshedToken == null) {
      await _invalidateSession();
      handler.next(err);
      return;
    }

    requestOptions.headers['Authorization'] = 'Bearer $refreshedToken';
    requestOptions.extra = {
      ...requestOptions.extra,
      'auth_retry': true,
    };

    try {
      final response = await Dio().fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      await _invalidateSession();
      handler.next(retryError);
    }
  }

  Future<String?> _refreshToken(RequestOptions requestOptions) async {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final completer = Completer<String?>();
    _refreshFuture = completer.future;
    final storage = _ref.read(secureStorageProvider);

    try {
      final currentToken = await storage.getToken();
      if (currentToken == null || currentToken.isEmpty) {
        completer.complete(null);
        return completer.future;
      }

      final refreshClient = Dio(BaseOptions(
        baseUrl: requestOptions.baseUrl,
        connectTimeout: requestOptions.connectTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
      ));

      final response = await refreshClient.post('/auth/refresh');
      final responseData = response.data;
      final payload = responseData is Map<String, dynamic>
          ? responseData['data'] as Map<String, dynamic>?
          : null;
      final refreshedToken = payload != null ? payload['token'] : null;

      if (refreshedToken is String && refreshedToken.isNotEmpty) {
        await storage.saveToken(refreshedToken);
        completer.complete(refreshedToken);
        return completer.future;
      }

      await storage.clearToken();
      completer.complete(null);
      return completer.future;
    } catch (_) {
      await storage.clearToken();
      completer.complete(null);
      return completer.future;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _invalidateSession() async {
    await _ref.read(secureStorageProvider).clearToken();
    _ref.read(authSessionVersionProvider.notifier).state++;
  }
}
