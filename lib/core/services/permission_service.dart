// permission_service.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_context.dart';
import '../providers/module_provider.dart';
import '../providers/context_provider.dart';

class PermissionService {
  final UserContext context;
  final Set<AppModule> activeModules;

  PermissionService({required this.context, required this.activeModules});

  bool canAccessModule(AppModule module) {
    return activeModules.contains(module);
  }

  bool canProcessAction(String action) {
    // В новой парадигме большинство действий зависят от наличия модуля,
    // а не от роли.
    return switch (action) {
      // Только в полевых условиях имеет смысл приемка и скан (при наличии склада)
      'receive_material' => context == UserContext.field &&
          canAccessModule(AppModule.basicWarehouse),
      'scan_qr' => context == UserContext.field && canAccessModule(AppModule.basicWarehouse),
      
      // Заявки с объекта имеют смысл только в поле
      'create_site_request' => context == UserContext.field &&
          canAccessModule(AppModule.siteRequests),

      // Офисные действия
      'approve_request' => context == UserContext.office && canAccessModule(AppModule.siteRequests),

      // Чтение/Просмотр (зависят только от модулей)
      'view_schedule' => canAccessModule(AppModule.scheduleManagement),
      'view_budget'   => canAccessModule(AppModule.budgetEstimates),
      'track_time'    => canAccessModule(AppModule.timeTracking),
      _ => false,
    };
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final context = ref.watch(userContextProvider);
  final modules = ref.watch(activeModulesProvider);
  return PermissionService(context: context, activeModules: modules);
});
