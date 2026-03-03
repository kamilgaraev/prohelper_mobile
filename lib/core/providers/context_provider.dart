// context_provider.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_context.dart';
import '../../features/auth/domain/auth_provider.dart';

final userContextProvider = Provider<UserContext>((ref) {
  final authState = ref.watch(authProvider);

  if (authState is AuthAuthenticated) {
    final roles = authState.user.roles;
    if (roles.isNotEmpty) {
      return UserContextX.fromSlug(roles.first);
    }
  }

  // По умолчанию считаем всех "офисными", если неизвестно.
  // Полевые работники (прорабы/рабочие) всегда имеют соответствующий role slug
  return UserContext.office;
});
