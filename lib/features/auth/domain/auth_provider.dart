import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../data/user_model.dart';
import 'auth_session_provider.dart';

abstract class AuthState {
  User? get user => null;
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated(this.user);

  @override
  final User user;
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  AuthError(this.message);

  final String message;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(secureStorageProvider),
    autoCheckAuth: false,
  );

  ref.listen<int>(authSessionVersionProvider, (_, __) {
    notifier.handleSessionInvalidation();
  });

  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._storage, {bool autoCheckAuth = true})
    : super(AuthInitial()) {
    if (autoCheckAuth) {
      checkAuth();
    }
  }

  final AuthRepository _repository;
  final SecureStorageService _storage;

  Future<void> checkAuth() async {
    final token = await _storage.getToken();
    if (!mounted) {
      return;
    }

    if (token == null || token.isEmpty) {
      state = AuthUnauthenticated();
      return;
    }

    try {
      final user = await _repository.getMe();
      if (!mounted) {
        return;
      }

      state = AuthAuthenticated(user);
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (error is ApiException && error.statusCode == 401) {
        state = AuthUnauthenticated();
        await _clearStoredToken();
        return;
      }

      state = AuthError(UserMessage.fromError(error));
    }
  }

  Future<void> login(String email, String password) async {
    if (!mounted) {
      return;
    }

    state = AuthLoading();

    try {
      final user = await _repository.login(email, password);
      if (!mounted) {
        return;
      }

      state = AuthAuthenticated(user);
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = AuthError(UserMessage.fromError(error));
    }
  }

  Future<void> switchOrganization(int organizationId) async {
    if (state is! AuthAuthenticated) {
      return;
    }

    final currentUser = (state as AuthAuthenticated).user;

    try {
      final updatedUser = await _repository.switchOrganization(organizationId);
      if (!mounted) {
        return;
      }

      state = AuthAuthenticated(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }

      state = AuthAuthenticated(currentUser);
      rethrow;
    }
  }

  Future<void> logout() async {
    if (!mounted) {
      return;
    }

    state = AuthUnauthenticated();
    await _logoutFromStorage();
  }

  void handleSessionInvalidation() {
    if (!mounted) {
      return;
    }

    state = AuthUnauthenticated();
  }

  void clearError() {
    if (!mounted || state is! AuthError) {
      return;
    }

    state = AuthUnauthenticated();
  }

  Future<void> _clearStoredToken() async {
    try {
      await _storage.clearToken();
    } catch (_) {}
  }

  Future<void> _logoutFromStorage() async {
    try {
      await _repository.logout();
    } catch (_) {}
  }
}
