import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../data/auth_session_identity.dart';
import '../data/user_model.dart';
import '../../notifications/data/mobile_push_service.dart';
import 'auth_session_provider.dart';
import '../../design_management/offline/bim_offline_provider.dart';

Future<bool> _hasNoActiveNetwork() async {
  try {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.isNotEmpty &&
        connectivity.every((result) => result == ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}

abstract class AuthState {
  User? get user => null;
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated(
    this.user, {
    this.sessionIdentity,
    this.isOnlineVerified = false,
  });

  @override
  final User user;
  final AuthSessionIdentity? sessionIdentity;
  final bool isOnlineVerified;
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  AuthError(this.message);

  final String message;
}

final StateNotifierProvider<AuthNotifier, AuthState> authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
      final notifier = AuthNotifier(
        ref.read(authRepositoryProvider),
        ref.read(secureStorageProvider),
        autoCheckAuth: false,
        beforeContextChange: () async {
          await (await ref.read(
            bimOfflineServiceProvider.future,
          )).prepareContextChange();
        },
        beforeLogout:
            () => ref.read(mobilePushServiceProvider).setAuthenticated(false),
        onSessionInvalidated: () {
          ref.read(authSessionVersionProvider.notifier).state++;
        },
      );

      ref.listen<int>(authSessionVersionProvider, (_, __) {
        notifier.handleSessionInvalidation();
      });

      return notifier;
    });

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(
    this._repository,
    this._storage, {
    bool autoCheckAuth = true,
    Future<void> Function()? beforeLogout,
    Future<void> Function()? beforeContextChange,
    void Function()? onSessionInvalidated,
    Future<bool> Function()? isDefinitelyOffline,
  }) : _beforeContextChange = beforeContextChange,
       _onSessionInvalidated = onSessionInvalidated,
       _beforeLogout = beforeLogout,
       _isDefinitelyOffline = isDefinitelyOffline ?? _hasNoActiveNetwork,
       super(AuthInitial()) {
    if (autoCheckAuth) checkAuth();
  }

  static const _offlineWindow = Duration(days: 14);
  final AuthRepository _repository;
  final SecureStorageService _storage;
  final void Function()? _onSessionInvalidated;
  final Future<void> Function()? _beforeLogout;
  final Future<void> Function()? _beforeContextChange;
  final Future<bool> Function() _isDefinitelyOffline;
  bool _loggingOut = false;
  int _operation = 0;
  Future<bool>? _queueVerification;
  AuthSessionIdentity? _queueVerificationIdentity;
  int? _queueVerificationOperation;

  Future<void> checkAuth() async {
    final operation = ++_operation;
    final token = await _storage.getToken();
    if (!_isCurrent(operation)) return;

    if (token == null || token.isEmpty) {
      state = AuthUnauthenticated();
      return;
    }

    var isDefinitelyOffline = false;
    try {
      isDefinitelyOffline = await _isDefinitelyOffline().timeout(
        const Duration(milliseconds: 500),
      );
    } catch (_) {}
    if (!_isCurrent(operation)) return;
    if (isDefinitelyOffline) {
      final cached = await _readOfflineUser(token);
      if (!_isCurrent(operation)) return;
      if (cached == null) {
        state = AuthUnauthenticated();
        return;
      }
      state = AuthAuthenticated(
        cached.$1,
        sessionIdentity: cached.$2,
        isOnlineVerified: false,
      );
      return;
    }

    try {
      final user = await _repository.getMe(token: token);
      if (!_isCurrent(operation)) return;
      final sessionId = await _storage.ensureSessionId();
      if (!_isCurrent(operation)) return;
      final identity = _identity(user, sessionId);
      state = AuthAuthenticated(
        user,
        sessionIdentity: identity,
        isOnlineVerified: true,
      );
      await _saveOfflineUser(user, identity, operation);
    } catch (error) {
      if (!_isCurrent(operation)) return;
      if (_isConfirmedRejection(error)) {
        state = AuthUnauthenticated();
        _onSessionInvalidated?.call();
        await _clearTokenAndOfflineIdentity();
        return;
      }
      final cached = await _readOfflineUser(await _storage.getToken() ?? token);
      if (!_isCurrent(operation)) return;
      if (cached != null) {
        state = AuthAuthenticated(
          cached.$1,
          sessionIdentity: cached.$2,
          isOnlineVerified: false,
        );
      } else {
        state = AuthError(UserMessage.fromError(error));
      }
    }
  }

  Future<void> login(String email, String password) async {
    if (!mounted) return;
    final operation = ++_operation;
    state = AuthLoading();
    try {
      final user = await _repository.login(email, password);
      if (!_isCurrent(operation)) return;
      await _queueOfflineMutation(_storage.clearOfflineAuth);
      final sessionId = await _storage.ensureSessionId();
      final identity = _identity(user, sessionId);
      state = AuthAuthenticated(
        user,
        sessionIdentity: identity,
        isOnlineVerified: true,
      );
      await _saveOfflineUser(user, identity, operation);
    } catch (error) {
      if (_isCurrent(operation)) {
        state = AuthError(UserMessage.fromError(error));
      }
    }
  }

  Future<void> switchOrganization(int organizationId) async {
    final auth = state;
    if (auth is! AuthAuthenticated) return;
    final currentIdentity = auth.sessionIdentity;
    if (currentIdentity == null) return;
    if (currentIdentity.organizationId == organizationId) return;
    await _beforeContextChange?.call();
    final currentAuth = state;
    if (!mounted ||
        currentAuth is! AuthAuthenticated ||
        currentAuth.sessionIdentity != currentIdentity) {
      return;
    }
    final operation = ++_operation;
    try {
      final updatedUser = await _repository.switchOrganization(organizationId);
      if (!_isCurrent(operation)) return;
      final identity = _identity(updatedUser, currentIdentity.sessionId);
      state = AuthAuthenticated(
        updatedUser,
        sessionIdentity: identity,
        isOnlineVerified: true,
      );
      await _saveOfflineUser(updatedUser, identity, operation);
    } catch (_) {
      if (_isCurrent(operation)) {
        state = auth;
      }
      rethrow;
    }
  }

  Future<bool> verifyOnlineForQueue() {
    final auth = state;
    if (auth is! AuthAuthenticated || auth.sessionIdentity == null) {
      return Future.value(false);
    }
    if (_queueVerification != null &&
        _queueVerificationIdentity == auth.sessionIdentity &&
        _queueVerificationOperation == _operation) {
      return _queueVerification!;
    }
    late final Future<bool> verification;
    verification = _verifyOnlineForQueue().whenComplete(() {
      if (identical(_queueVerification, verification)) {
        _queueVerification = null;
        _queueVerificationIdentity = null;
        _queueVerificationOperation = null;
      }
    });
    _queueVerification = verification;
    _queueVerificationIdentity = auth.sessionIdentity;
    _queueVerificationOperation = _operation;
    return verification;
  }

  Future<bool> _verifyOnlineForQueue() async {
    final auth = state;
    if (auth is! AuthAuthenticated) return false;
    final originalIdentity = auth.sessionIdentity;
    if (originalIdentity == null) return false;
    final operation = _operation;
    final token = await _storage.getToken();
    if (!_isCurrent(operation) || token == null || token.isEmpty) return false;

    try {
      final verifiedUser = await _repository.getMe(token: token);
      if (!_isCurrent(operation)) return false;
      final verifiedIdentity = _identity(
        verifiedUser,
        originalIdentity.sessionId,
      );
      final sameOwner = verifiedIdentity == originalIdentity;
      state = AuthAuthenticated(
        verifiedUser,
        sessionIdentity: verifiedIdentity,
        isOnlineVerified: true,
      );
      await _saveOfflineUser(verifiedUser, verifiedIdentity, operation);
      return sameOwner && _isCurrent(operation);
    } catch (error) {
      if (!_isCurrent(operation)) return false;
      if (_isConfirmedRejection(error)) {
        state = AuthUnauthenticated();
        _onSessionInvalidated?.call();
        await _clearTokenAndOfflineIdentity();
      } else {
        state = AuthAuthenticated(
          auth.user,
          sessionIdentity: originalIdentity,
          isOnlineVerified: false,
        );
      }
      return false;
    }
  }

  Future<void> logout() async {
    if (!mounted || _loggingOut) return;
    final authBeforeLogout = state;
    await _beforeContextChange?.call();
    final currentAuth = state;
    final sameSession =
        authBeforeLogout is AuthAuthenticated &&
                currentAuth is AuthAuthenticated
            ? currentAuth.sessionIdentity == authBeforeLogout.sessionIdentity
            : currentAuth == authBeforeLogout;
    if (!mounted || _loggingOut || !sameSession) return;
    _loggingOut = true;
    ++_operation;
    state = AuthLoading();
    String? installationId;
    try {
      installationId = await _storage.getPushInstallationId();
    } catch (_) {}
    try {
      await _beforeLogout?.call();
    } catch (_) {}
    try {
      await _queueOfflineMutation(_storage.clearOfflineAuth);
    } finally {
      try {
        await _repository.logout(installationId: installationId);
      } finally {
        _loggingOut = false;
        _onSessionInvalidated?.call();
        if (mounted) state = AuthUnauthenticated();
      }
    }
  }

  void handleSessionInvalidation() {
    if (!mounted || _loggingOut) return;
    ++_operation;
    state = AuthUnauthenticated();
    unawaited(
      _queueOfflineMutation(
        _storage.clearOfflineAuth,
      ).catchError((Object _) {}),
    );
  }

  void clearError() {
    if (!mounted || state is! AuthError) return;
    state = AuthUnauthenticated();
  }

  bool _isCurrent(int operation) => mounted && operation == _operation;

  bool _isConfirmedRejection(Object error) =>
      error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 403);

  AuthSessionIdentity _identity(User user, String sessionId) =>
      AuthSessionIdentity(
        userId: user.serverId,
        organizationId: user.currentOrganizationId,
        sessionId: sessionId,
      );

  Future<void> _saveOfflineUser(
    User user,
    AuthSessionIdentity identity,
    int operation,
  ) async {
    final bundle = {
      'session_id': identity.sessionId,
      'user_id': user.serverId,
      'organization_id': user.currentOrganizationId,
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      'user': {
        'server_id': user.serverId,
        'email': user.email,
        'name': user.name,
        'avatar_url': user.avatarUrl,
        'organization_id': user.currentOrganizationId,
        'organization_name': user.organizationName,
        'organizations_json': user.organizationsJson,
        'roles': user.roles,
        'permissions_json': user.permissionsJson,
      },
    };
    await _queueOfflineMutation(() async {
      final currentToken = await _storage.getToken();
      final currentAuth = state;
      if (!_isCurrent(operation) ||
          currentToken == null ||
          currentToken.isEmpty ||
          currentAuth is! AuthAuthenticated ||
          currentAuth.sessionIdentity != identity) {
        return;
      }
      await _storage.saveOfflineAuth({...bundle, 'token': currentToken});
    });
  }

  Future<void> _clearTokenAndOfflineIdentity() =>
      _queueOfflineMutation(_storage.clearToken);

  Future<void> _queueOfflineMutation(Future<void> Function() mutation) =>
      _storage.mutateAuth(mutation);

  Future<(User, AuthSessionIdentity)?> _readOfflineUser(String token) async {
    final record = await _storage.getOfflineAuth();
    if (record == null || record['token'] != token) return null;
    final confirmedAt = DateTime.tryParse(
      record['confirmed_at']?.toString() ?? '',
    );
    if (confirmedAt == null) return null;
    final age = DateTime.now().toUtc().difference(confirmedAt.toUtc());
    if (age.isNegative || age > _offlineWindow) return null;
    final json = record['user'];
    if (json is! Map<String, dynamic>) return null;
    final rawId = json['server_id'];
    if (rawId is! int || rawId <= 0) return null;
    final organizationId = json['organization_id'];
    if (record['organization_id'] != organizationId) return null;
    final rawRoles = json['roles'];
    if (rawRoles is! List<dynamic>) return null;
    final user =
        User()
          ..serverId = rawId
          ..email = json['email']?.toString() ?? ''
          ..name = json['name']?.toString() ?? ''
          ..avatarUrl = json['avatar_url']?.toString()
          ..currentOrganizationId =
              organizationId is int ? organizationId : null
          ..organizationName = json['organization_name']?.toString()
          ..organizationsJson = json['organizations_json']?.toString() ?? '[]'
          ..roles = rawRoles.whereType<String>().toList(growable: false)
          ..permissionsJson = json['permissions_json']?.toString() ?? '{}';
    final sessionId = record['session_id']?.toString() ?? '';
    if (sessionId.isEmpty || record['user_id'] != user.serverId) return null;
    return (user, _identity(user, sessionId));
  }
}
