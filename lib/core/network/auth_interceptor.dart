import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../storage/secure_storage_service.dart';
import '../../features/auth/domain/auth_session_provider.dart';

final authRefreshClientFactoryProvider = Provider<Dio Function(BaseOptions)>(
  (ref) =>
      (options) => Dio(options),
);

final authRetryClientFactoryProvider = Provider<Dio Function()>(
  (ref) =>
      () => Dio(),
);

class AuthInterceptor extends Interceptor {
  Future<String?>? _refreshFuture;
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skip_auth'] == true) {
      handler.next(options);
      return;
    }

    if (_hasAuthorizationHeader(options.headers)) {
      handler.next(options);
      return;
    }

    final token = await _ref.read(secureStorageProvider).getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    if (requestOptions.extra['skip_auth'] == true) {
      handler.next(err);
      return;
    }

    if (_isInactiveMembership(err)) {
      await _invalidateSession(requestOptions);
      handler.next(err);
      return;
    }

    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final isLoginRequest = requestOptions.path.endsWith('/auth/login');
    final isRefreshRequest = requestOptions.path.endsWith('/auth/refresh');
    final isRetried = requestOptions.extra['auth_retry'] == true;

    if (isLoginRequest) {
      handler.next(err);
      return;
    }

    if (isRefreshRequest || isRetried) {
      await _invalidateSession(requestOptions);
      handler.next(err);
      return;
    }

    final String? refreshedToken;
    try {
      refreshedToken = await _refreshToken(requestOptions);
    } on DioException catch (refreshError) {
      if (_isSessionRejected(refreshError)) {
        await _invalidateSession(refreshError.requestOptions);
      }
      handler.next(refreshError.copyWith(requestOptions: requestOptions));
      return;
    } catch (error, stackTrace) {
      handler.next(
        DioException(
          requestOptions: requestOptions,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }
    if (refreshedToken == null) {
      handler.next(err);
      return;
    }

    requestOptions.headers['Authorization'] = 'Bearer $refreshedToken';
    requestOptions.extra = {...requestOptions.extra, 'auth_retry': true};

    try {
      final retryClient = _ref.read(authRetryClientFactoryProvider)();
      final response = await retryClient.fetch<dynamic>(requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      if (_isSessionRejected(retryError)) {
        await _invalidateSession(requestOptions);
      }
      handler.next(retryError);
    }
  }

  Future<String?> _refreshToken(RequestOptions requestOptions) async {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = _performRefresh(requestOptions);
    _refreshFuture = refresh;
    try {
      return await refresh;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh(RequestOptions requestOptions) async {
    final storage = _ref.read(secureStorageProvider);
    final currentToken = await storage.getToken();
    if (currentToken == null || currentToken.isEmpty) {
      return null;
    }
    final sentAuthorization = _authorizationHeader(requestOptions);
    if (sentAuthorization != null &&
        sentAuthorization != 'Bearer $currentToken') {
      return currentToken;
    }

    final refreshClient = _ref.read(authRefreshClientFactoryProvider)(
      BaseOptions(
        baseUrl: requestOptions.baseUrl,
        connectTimeout: requestOptions.connectTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
      ),
    );

    final response = await refreshClient.post('/auth/refresh');
    final responseData = response.data;
    final payload = responseData is Map<String, dynamic>
        ? responseData['data']
        : null;
    final refreshedToken = payload is Map<String, dynamic>
        ? payload['token']
        : null;

    if (refreshedToken is String && refreshedToken.isNotEmpty) {
      if (await storage.getToken() != currentToken) {
        throw DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.cancel,
        );
      }
      await storage.saveToken(refreshedToken);
      await storage.rebindOfflineAuthToken(refreshedToken);
      return refreshedToken;
    }

    throw DioException(
      requestOptions: requestOptions,
      response: response,
      error: const FormatException('Missing token in refresh response'),
    );
  }

  Future<void> _invalidateSession(RequestOptions requestOptions) async {
    final storage = _ref.read(secureStorageProvider);
    final currentToken = await storage.getToken();
    final authorization = _authorizationHeader(requestOptions);
    if (currentToken == null ||
        (authorization != null && authorization != 'Bearer $currentToken')) {
      return;
    }
    await storage.clearToken();
    _ref.read(authSessionVersionProvider.notifier).state++;
  }

  bool _isSessionRejected(DioException error) {
    return error.response?.statusCode == 401 || _isInactiveMembership(error);
  }

  bool _isInactiveMembership(DioException error) {
    final data = error.response?.data;
    return error.response?.statusCode == 403 &&
        data is Map<String, dynamic> &&
        data['code'] == 'organization_membership_inactive';
  }

  String? _authorizationHeader(RequestOptions options) {
    for (final header in options.headers.entries) {
      if (header.key.toLowerCase() == 'authorization') {
        return header.value?.toString();
      }
    }
    return null;
  }

  bool _hasAuthorizationHeader(Map<String, dynamic> headers) {
    return headers.keys.any((key) => key.toLowerCase() == 'authorization');
  }
}
