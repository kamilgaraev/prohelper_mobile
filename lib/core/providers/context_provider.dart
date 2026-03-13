import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_context.dart';
import '../../features/auth/domain/auth_provider.dart';

final userContextProvider = Provider<UserContext>((ref) {
  final authState = ref.watch(authProvider);

  if (authState is AuthAuthenticated) {
    final roles = authState.user.roles;
    if (roles.isNotEmpty) {
      return UserContextX.fromRoles(roles);
    }
  }

  return UserContext.office;
});
