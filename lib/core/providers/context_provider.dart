import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_context.dart';
import '../../features/auth/domain/auth_provider.dart';

final userContextProvider = Provider<UserContext>((ref) {
  final authState = ref.watch(authProvider);

  if (authState is AuthAuthenticated) {
    final permissions = authState.user.grantedPermissions;
    if (permissions.any(
      (permission) =>
          permission == 'site_requests.create' ||
          permission == 'warehouse.receipts' ||
          permission == 'machinery-operations.shifts.create' ||
          permission == 'workforce.attendance.self',
    )) {
      return UserContext.field;
    }
  }

  return UserContext.office;
});
