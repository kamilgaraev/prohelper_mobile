import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/user_context.dart';
import '../providers/context_provider.dart';
import '../providers/module_provider.dart';

class PermissionService {
  PermissionService({
    required this.context,
    required this.activeModules,
  });

  final UserContext context;
  final Set<AppModule> activeModules;

  bool canAccessModule(AppModule module) {
    return activeModules.contains(module);
  }

  bool canProcessAction(String action) {
    return switch (action) {
      'receive_material' =>
        context == UserContext.field && canAccessModule(AppModule.basicWarehouse),
      'scan_qr' =>
        context == UserContext.field && canAccessModule(AppModule.basicWarehouse),
      'create_site_request' =>
        context == UserContext.field && canAccessModule(AppModule.siteRequests),
      'approve_request' =>
        context == UserContext.office && canAccessModule(AppModule.siteRequests),
      'view_schedule' => canAccessModule(AppModule.scheduleManagement),
      'view_budget' => canAccessModule(AppModule.budgetEstimates),
      'track_time' => canAccessModule(AppModule.timeTracking),
      _ => false,
    };
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final context = ref.watch(userContextProvider);
  final modules = ref.watch(activeModulesProvider);

  return PermissionService(
    context: context,
    activeModules: modules,
  );
});
