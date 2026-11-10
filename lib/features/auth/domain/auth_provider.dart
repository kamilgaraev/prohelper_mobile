import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../data/auth_session_identity.dart';
import '../data/biometric_unlock.dart';
import '../data/quick_unlock_service.dart';
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
    this.needsReauthentication = false,
  });

  @override
  final User user;
  final AuthSessionIdentity? sessionIdentity;
  final bool isOnlineVerified;
  final bool needsReauthentication;
}

class AuthLocked extends AuthState {
  AuthLocked(
    this.lockedUser,
    this.sessionIdentity, {
    this.message,
    this.messageIsError = false,
    this.isSubmitting = false,
    this.canUnlockOffline = false,
    this.canUseBiometrics = false,
  });

  final User lockedUser;
  final AuthSessionIdentity sessionIdentity;
  final String? message;
  final bool messageIsError;
  final bool isSubmitting;
  final bool canUnlockOffline;
  final bool canUseBiometrics;

  AuthLocked copyWith({
    String? message,
    bool? messageIsError,
    bool clearMessage = false,
    bool? isSubmitting,
    bool? canUnlockOffline,
    bool? canUseBiometrics,
  }) => AuthLocked(
    lockedUser,
    sessionIdentity,
    message: clearMessage ? null : message ?? this.message,
    messageIsError:
        clearMessage ? false : messageIsError ?? this.messageIsError,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    canUnlockOffline: canUnlockOffline ?? this.canUnlockOffline,
    canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
  );
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  AuthError(this.message);

  final String message;
}

AuthSessionIdentity? retainedSessionIdentity(AuthState state) =>
    switch (state) {
      AuthAuthenticated(:final sessionIdentity) => sessionIdentity,
      AuthLocked(:final sessionIdentity) => sessionIdentity,
      _ => null,
    };

const _sessionEndedMessage =
    'Сессия завершена. Войдите снова, чтобы продолжить работу и отправить сохранённые изменения.';
const _connectionBackMessage =
    'Связь появилась. Войдите с паролем, чтобы отправить сохранённые изменения.';
const _pinExhaustedMessage =
    'PIN-код введён неверно слишком много раз. Данные входа на этом телефоне удалены, войдите с паролем.';
const _biometricChangedMessage =
    'Отпечатки или лицо на телефоне изменились. Войдите по PIN-коду.';
const _biometricLockedMessage = 'Слишком много попыток. Войдите по PIN-коду.';
const _organizationRestoreFailedMessage =
    'Не удалось вернуться в организацию, где сделаны изменения. Проверьте связь и войдите еще раз.';
const _organizationAccessLostMessage =
    'Нет доступа к организации, где сделаны изменения. Обратитесь к администратору или выйдите из аккаунта — неотправленные изменения будут удалены.';
const _offlineUnavailableMessage =
    'Вход без связи больше недоступен. Подключитесь к интернету и войдите с паролем.';

const unlockPromptText = BiometricPromptText(
  title: 'Вход в МОСТ',
  subtitle: 'Подтвердите, что это вы',
  cancel: 'Ввести PIN-код',
);

final StateNotifierProvider<AuthNotifier, AuthState> authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
      final notifier = AuthNotifier(
        ref.read(authRepositoryProvider),
        ref.read(secureStorageProvider),
        quickUnlock: ref.read(quickUnlockServiceProvider),
        biometricUnlock: ref.read(biometricUnlockProvider),
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
    QuickUnlockService? quickUnlock,
    BiometricUnlock? biometricUnlock,
    bool autoCheckAuth = true,
    Future<void> Function()? beforeLogout,
    Future<void> Function()? beforeContextChange,
    void Function()? onSessionInvalidated,
    Future<bool> Function()? isDefinitelyOffline,
  }) : _quickUnlock = quickUnlock ?? QuickUnlockService(_storage),
       _biometric = biometricUnlock ?? const UnavailableBiometricUnlock(),
       _beforeContextChange = beforeContextChange,
       _onSessionInvalidated = onSessionInvalidated,
       _beforeLogout = beforeLogout,
       _isDefinitelyOffline = isDefinitelyOffline ?? _hasNoActiveNetwork,
       super(AuthInitial()) {
    if (autoCheckAuth) checkAuth();
  }

  static const _offlineWindow = Duration(days: 14);
  final AuthRepository _repository;
  final SecureStorageService _storage;
  final QuickUnlockService _quickUnlock;
  final BiometricUnlock _biometric;
  final void Function()? _onSessionInvalidated;
  final Future<void> Function()? _beforeLogout;
  final Future<void> Function()? _beforeContextChange;
  final Future<bool> Function() _isDefinitelyOffline;
  bool _loggingOut = false;
  bool _autoRelockAllowed = false;
  int _operation = 0;
  Future<bool>? _queueVerification;
  AuthSessionIdentity? _queueVerificationIdentity;
  int? _queueVerificationOperation;

  Future<void> checkAuth() async {
    final operation = ++_operation;
    final token = await _storage.getToken();
    if (!_isCurrent(operation)) return;

    if (token == null || token.isEmpty) {
      final locked = await _readLockedUser();
      if (!_isCurrent(operation)) return;
      if (locked != null) {
        _enterLocked(locked.$1, locked.$2, operation, _sessionEndedMessage);
        return;
      }
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
        final locked = await _readLockedUser();
        if (!_isCurrent(operation)) return;
        if (locked != null) {
          _enterLocked(locked.$1, locked.$2, operation, _sessionEndedMessage);
          return;
        }
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
        final locked = await _readLockedUser();
        if (!_isCurrent(operation)) return;
        if (locked != null) {
          await _queueOfflineMutation(_storage.clearAccessToken);
          if (!_isCurrent(operation)) return;
          _enterLocked(locked.$1, locked.$2, operation, _sessionEndedMessage);
          return;
        }
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
    if (!_isCurrent(operation)) return false;
    if (token == null || token.isEmpty) {
      if (auth.needsReauthentication && _autoRelockAllowed) {
        var offline = true;
        try {
          offline = await _isDefinitelyOffline().timeout(
            const Duration(milliseconds: 500),
          );
        } catch (_) {}
        if (!_isCurrent(operation) || offline || !_autoRelockAllowed) {
          return false;
        }
        _autoRelockAllowed = false;
        _enterLocked(
          auth.user,
          originalIdentity,
          ++_operation,
          _connectionBackMessage,
        );
      }
      return false;
    }

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
        final lockOperation = ++_operation;
        _enterLocked(
          auth.user,
          originalIdentity,
          lockOperation,
          _sessionEndedMessage,
        );
        await _queueOfflineMutation(_storage.clearAccessToken);
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
    if (authBeforeLogout is! AuthLocked) {
      await _beforeContextChange?.call();
    }
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
      await _clearQuickUnlock();
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
    final current = state;
    if (current is AuthLocked) return;
    final operation = ++_operation;
    if (current is AuthAuthenticated && current.sessionIdentity != null) {
      _enterLocked(
        current.user,
        current.sessionIdentity!,
        operation,
        _sessionEndedMessage,
      );
      return;
    }
    unawaited(_lockFromStoredSessionOrSignOut(operation));
  }

  Future<void> _lockFromStoredSessionOrSignOut(int operation) async {
    (User, AuthSessionIdentity)? locked;
    try {
      locked = await _readLockedUser();
    } catch (_) {}
    if (!_isCurrent(operation)) return;
    if (locked != null) {
      _enterLocked(locked.$1, locked.$2, operation, _sessionEndedMessage);
      return;
    }
    state = AuthUnauthenticated();
    await _queueOfflineMutation(
      _storage.clearOfflineAuth,
    ).catchError((Object _) {});
  }

  Future<void> reauthenticate(String password) async {
    final current = state;
    if (!mounted || current is! AuthLocked || current.isSubmitting) return;
    final operation = ++_operation;
    state = current.copyWith(isSubmitting: true, clearMessage: true);
    try {
      var user = await _repository.login(current.lockedUser.email, password);
      if (!_isCurrent(operation)) return;
      final lockedIdentity = current.sessionIdentity;
      if (user.serverId != lockedIdentity.userId) {
        await _queueOfflineMutation(_storage.clearOfflineAuth);
        await _clearQuickUnlock();
        if (!_isCurrent(operation)) return;
        final sessionId = await _storage.ensureSessionId();
        final identity = _identity(user, sessionId);
        state = AuthAuthenticated(
          user,
          sessionIdentity: identity,
          isOnlineVerified: true,
        );
        await _saveOfflineUser(user, identity, operation);
        return;
      }
      final lockedOrganizationId = lockedIdentity.organizationId;
      if (lockedOrganizationId != null &&
          user.currentOrganizationId != lockedOrganizationId) {
        Object? switchError;
        try {
          user = await _repository.switchOrganization(lockedOrganizationId);
        } catch (error) {
          switchError = error;
        }
        if (!_isCurrent(operation)) return;
        if (switchError != null ||
            user.currentOrganizationId != lockedOrganizationId) {
          await _queueOfflineMutation(_storage.clearAccessToken);
          if (!_isCurrent(operation)) return;
          final accessDenied =
              switchError is ApiException &&
              (switchError.statusCode == 403 || switchError.statusCode == 404);
          state = current.copyWith(
            isSubmitting: false,
            message:
                accessDenied
                    ? _organizationAccessLostMessage
                    : _organizationRestoreFailedMessage,
            messageIsError: true,
          );
          return;
        }
      }
      final identity = _identity(user, lockedIdentity.sessionId);
      state = AuthAuthenticated(
        user,
        sessionIdentity: identity,
        isOnlineVerified: true,
      );
      await _saveOfflineUser(user, identity, operation);
    } catch (error) {
      if (!_isCurrent(operation)) return;
      await _queueOfflineMutation(_storage.clearAccessToken);
      if (!_isCurrent(operation)) return;
      state = current.copyWith(
        isSubmitting: false,
        message: UserMessage.fromError(error),
        messageIsError: true,
      );
    }
  }

  Future<void> unlockWithPin(String pin) async {
    final current = state;
    if (!mounted || current is! AuthLocked || current.isSubmitting) return;
    final operation = ++_operation;
    state = current.copyWith(isSubmitting: true, clearMessage: true);
    final userId = current.sessionIdentity.userId;
    if (!await _canUnlockOffline(userId)) {
      if (!_isCurrent(operation)) return;
      state = current.copyWith(
        isSubmitting: false,
        canUnlockOffline: false,
        canUseBiometrics: false,
        message: _offlineUnavailableMessage,
        messageIsError: true,
      );
      return;
    }
    final check = await _quickUnlock.verify(userId, pin);
    if (!_isCurrent(operation)) return;
    switch (check.status) {
      case PinCheckStatus.success:
        await _enterOfflineUnlocked(current, operation);
      case PinCheckStatus.wrong:
        state = current.copyWith(
          isSubmitting: false,
          message:
              'Неверный PIN-код. Осталось попыток: ${check.remainingAttempts}.',
          messageIsError: true,
        );
      case PinCheckStatus.exhausted:
        await _wipeLocalSession(operation, _pinExhaustedMessage);
      case PinCheckStatus.notConfigured:
        state = current.copyWith(
          isSubmitting: false,
          canUnlockOffline: false,
          canUseBiometrics: false,
          message: _offlineUnavailableMessage,
          messageIsError: true,
        );
    }
  }

  Future<void> unlockWithBiometrics() async {
    final current = state;
    if (!mounted ||
        current is! AuthLocked ||
        current.isSubmitting ||
        !current.canUseBiometrics) {
      return;
    }
    final operation = ++_operation;
    state = current.copyWith(isSubmitting: true, clearMessage: true);
    final userId = current.sessionIdentity.userId;
    if (!await _canUnlockOffline(userId) ||
        !await _quickUnlock.biometricEnabledFor(userId)) {
      if (!_isCurrent(operation)) return;
      state = current.copyWith(isSubmitting: false, canUseBiometrics: false);
      return;
    }
    final result = await _biometric.authenticate(unlockPromptText);
    if (!_isCurrent(operation)) return;
    switch (result) {
      case BiometricResult.success:
        await _enterOfflineUnlocked(current, operation);
      case BiometricResult.invalidated:
        await _quickUnlock.setBiometricEnabled(userId, false);
        if (!_isCurrent(operation)) return;
        state = current.copyWith(
          isSubmitting: false,
          canUseBiometrics: false,
          message: _biometricChangedMessage,
          messageIsError: true,
        );
      case BiometricResult.lockedOut:
        state = current.copyWith(
          isSubmitting: false,
          message: _biometricLockedMessage,
          messageIsError: true,
        );
      case BiometricResult.unavailable:
        state = current.copyWith(isSubmitting: false, canUseBiometrics: false);
      case BiometricResult.cancelled:
      case BiometricResult.failed:
        state = current.copyWith(isSubmitting: false);
    }
  }

  void requestPasswordSignIn() {
    final current = state;
    if (!mounted ||
        current is! AuthAuthenticated ||
        !current.needsReauthentication ||
        current.sessionIdentity == null) {
      return;
    }
    _enterLocked(current.user, current.sessionIdentity!, ++_operation, null);
  }

  Future<void> setupQuickUnlock(
    String pin, {
    bool enableBiometrics = false,
  }) async {
    final userId = _verifiedUserId();
    if (userId == null) return;
    await _quickUnlock.setPin(userId, pin);
    await _quickUnlock.markOffered(userId);
    if (enableBiometrics) {
      await enableBiometricUnlock();
    } else {
      await _biometric.disable();
    }
  }

  Future<bool> enableBiometricUnlock() async {
    final userId = _verifiedUserId();
    if (userId == null || !await _quickUnlock.isConfiguredFor(userId)) {
      return false;
    }
    final result = await _biometric.enable(
      const BiometricPromptText(
        title: 'Вход по отпечатку или лицу',
        subtitle: 'Подтвердите, чтобы включить',
        cancel: 'Отмена',
      ),
    );
    final enabled = result == BiometricResult.success;
    await _quickUnlock.setBiometricEnabled(userId, enabled);
    return enabled;
  }

  Future<void> disableBiometricUnlock() async {
    final userId = _verifiedUserId();
    await _biometric.disable();
    if (userId != null) await _quickUnlock.setBiometricEnabled(userId, false);
  }

  Future<void> disableQuickUnlock() async {
    final userId = _verifiedUserId();
    if (userId == null) return;
    await _clearQuickUnlock();
  }

  Future<QuickUnlockStatus> quickUnlockStatus() async {
    final current = state;
    if (current is! AuthAuthenticated) return const QuickUnlockStatus();
    final userId = current.user.serverId;
    final configured = await _quickUnlock.isConfiguredFor(userId);
    final availability = await _biometric.availability();
    return QuickUnlockStatus(
      configured: configured,
      biometricEnabled:
          configured && await _quickUnlock.biometricEnabledFor(userId),
      biometricAvailability: availability,
      offered: await _quickUnlock.wasOffered(userId),
    );
  }

  Future<void> markQuickUnlockOffered() async {
    final userId = _verifiedUserId();
    if (userId != null) await _quickUnlock.markOffered(userId);
  }

  int? _verifiedUserId() {
    final current = state;
    if (current is! AuthAuthenticated) return null;
    return current.user.serverId;
  }

  void _enterLocked(
    User user,
    AuthSessionIdentity identity,
    int operation,
    String? message,
  ) {
    if (!_isCurrent(operation)) return;
    final locked = AuthLocked(user, identity, message: message);
    state = locked;
    unawaited(_refreshLockOptions(locked, operation));
  }

  Future<void> _refreshLockOptions(AuthLocked locked, int operation) async {
    final userId = locked.sessionIdentity.userId;
    final canUnlock = await _canUnlockOffline(userId);
    final canUseBiometrics =
        canUnlock &&
        await _quickUnlock.biometricEnabledFor(userId) &&
        await _biometric.availability() == BiometricAvailability.available;
    if (!_isCurrent(operation) || !identical(state, locked)) return;
    state = locked.copyWith(
      canUnlockOffline: canUnlock,
      canUseBiometrics: canUseBiometrics,
    );
  }

  Future<bool> _canUnlockOffline(int userId) async {
    if (!await _quickUnlock.isConfiguredFor(userId)) return false;
    final record = await _storage.getOfflineAuth();
    if (record == null || record['user_id'] != userId) return false;
    final confirmedAt = DateTime.tryParse(
      record['confirmed_at']?.toString() ?? '',
    );
    if (confirmedAt == null) return false;
    final age = DateTime.now().toUtc().difference(confirmedAt.toUtc());
    return !age.isNegative && age <= _offlineWindow;
  }

  Future<void> _enterOfflineUnlocked(AuthLocked locked, int operation) async {
    final record = await _storage.getOfflineAuth();
    if (!_isCurrent(operation)) return;
    final restored = record == null ? null : _userFromOfflineRecord(record);
    final user =
        restored != null && restored.$2 == locked.sessionIdentity
            ? restored.$1
            : locked.lockedUser;
    _autoRelockAllowed = locked.message != _connectionBackMessage;
    state = AuthAuthenticated(
      user,
      sessionIdentity: locked.sessionIdentity,
      isOnlineVerified: false,
      needsReauthentication: true,
    );
  }

  Future<void> _wipeLocalSession(int operation, String message) async {
    await _clearQuickUnlock();
    await _queueOfflineMutation(_storage.clearToken);
    if (!_isCurrent(operation)) return;
    state = AuthError(message);
  }

  Future<void> _clearQuickUnlock() async {
    try {
      await _quickUnlock.clear();
    } catch (_) {}
    try {
      await _biometric.disable();
    } catch (_) {}
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
    return _userFromOfflineRecord(record);
  }

  Future<(User, AuthSessionIdentity)?> _readLockedUser() async {
    final record = await _storage.getOfflineAuth();
    if (record == null) return null;
    return _userFromOfflineRecord(record);
  }

  (User, AuthSessionIdentity)? _userFromOfflineRecord(
    Map<String, dynamic> record,
  ) {
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

class QuickUnlockStatus {
  const QuickUnlockStatus({
    this.configured = false,
    this.biometricEnabled = false,
    this.biometricAvailability = BiometricAvailability.unavailable,
    this.offered = false,
  });

  final bool configured;
  final bool biometricEnabled;
  final BiometricAvailability biometricAvailability;
  final bool offered;
}
