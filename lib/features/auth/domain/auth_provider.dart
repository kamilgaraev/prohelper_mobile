import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../data/user_model.dart';
import 'auth_session_provider.dart';

// State Definition
abstract class AuthState {
  User? get user => null;
}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  @override
  final User user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  ref.watch(authSessionVersionProvider);
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(secureStorageProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SecureStorageService _storage;

  AuthNotifier(this._repository, this._storage) : super(AuthInitial()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = AuthLoading();

    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      state = AuthUnauthenticated();
      return;
    }

    try {
      final user = await _repository.getMe();
      state = AuthAuthenticated(user);
    } catch (_) {
      await _storage.clearToken();
      state = AuthUnauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repository.login(email, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError('Не удалось выполнить вход: ${e.toString()}');
    }
  }

  Future<void> switchOrganization(int organizationId) async {
    if (state is! AuthAuthenticated) return;
    
    final currentUser = (state as AuthAuthenticated).user;
    state = AuthLoading(); 
    
    try {
      final updatedUser = await _repository.switchOrganization(organizationId);
      state = AuthAuthenticated(updatedUser);
    } catch (e) {
      state = AuthAuthenticated(currentUser);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthUnauthenticated();
  }
}
