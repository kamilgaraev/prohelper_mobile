import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/user_model.dart';

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
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthInitial()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    // TODO: Check token and Isar for offline support
    // For now, start unauthenticated
    state = AuthUnauthenticated();
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repository.login(email, password);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError('Login failed: ${e.toString()}');
    }
  }

  Future<void> switchOrganization(int organizationId) async {
    // Keep current state or show loading overlay? 
    // For now, let's keep showing current UI but maybe show a loading indicator
    // ideally strictly we should transition to loading or have a separate loading state property
    if (state is! AuthAuthenticated) return;
    
    final currentUser = (state as AuthAuthenticated).user;
    state = AuthLoading(); 
    
    try {
      final updatedUser = await _repository.switchOrganization(organizationId);
      state = AuthAuthenticated(updatedUser);
    } catch (e) {
      // Revert to previous user if failed, or show error
      state = AuthAuthenticated(currentUser); // Or AuthError
      // NOTE: In a real app we might want to show a toast error instead of changing state to Error which replaces screen
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthUnauthenticated();
  }
}
