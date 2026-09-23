import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/user_context.dart';
import '../providers/context_provider.dart';
import '../providers/module_provider.dart';

class PermissionService {
  PermissionService({
    required this.context,
    required this.activeModules,
    this.grantedPermissions = const <String>{},
  });

  final UserContext context;
  final Set<AppModule> activeModules;
  final Set<String> grantedPermissions;

  bool hasPermission(String permission) {
    final module = permission.split('.').first;
    return grantedPermissions.contains(permission) ||
        grantedPermissions.contains('$module.*') ||
        grantedPermissions.contains('${module.replaceAll('_', '-')}.*') ||
        grantedPermissions.contains('${module.replaceAll('-', '_')}.*');
  }

  bool hasAnyPermission(Iterable<String> permissions) {
    return permissions.any(hasPermission);
  }

  bool canAccessModule(AppModule module) {
    return activeModules.contains(module);
  }

  bool canProcessAction(String action) {
    return switch (action) {
      'receive_material' =>
        canAccessModule(AppModule.basicWarehouse) &&
            hasPermission('warehouse.receipts'),
      'scan_qr' =>
        canAccessModule(AppModule.basicWarehouse) &&
            hasAnyPermission(const [
              'warehouse.advanced.barcode',
              'warehouse.view',
            ]),
      'create_site_request' =>
        canAccessModule(AppModule.siteRequests) &&
            hasPermission('site_requests.create'),
      'approve_request' =>
        canAccessModule(AppModule.siteRequests) &&
            hasPermission('site_requests.approve'),
      'view_schedule' =>
        canAccessModule(AppModule.scheduleManagement) &&
            hasAnyPermission(const [
              'schedule.view',
              'schedule-management.view',
            ]),
      'view_budget' =>
        canAccessModule(AppModule.budgetEstimates) &&
            hasPermission('budget-estimates.view'),
      'quality_control' =>
        canAccessModule(AppModule.qualityControl) &&
            hasPermission('quality-control.defects.view'),
      'view_safety' =>
        canAccessModule(AppModule.safetyManagement) &&
            hasPermission('safety-management.view'),
      'view_workflow' =>
        canAccessModule(AppModule.workflowManagement) &&
            hasAnyPermission(const [
              'completed_works.view',
              'workflow-management.view',
            ]),
      'view_procurement' =>
        canAccessModule(AppModule.procurement) &&
            hasPermission('procurement.view'),
      'view_handover' =>
        canAccessModule(AppModule.handoverAcceptance) &&
            hasPermission('handover-acceptance.view'),
      'view_construction_journal' =>
        canAccessModule(AppModule.constructionJournal) &&
            hasPermission('construction-journal.view'),
      'track_time' =>
        canAccessModule(AppModule.timeTracking) &&
            hasPermission('time_tracking.view'),
      'record_machinery_shift' =>
        canAccessModule(AppModule.machineryOperations) &&
            hasPermission('machinery-operations.shifts.create'),
      'record_labor_output' =>
        canAccessModule(AppModule.productionLabor) &&
            hasPermission('production-labor.view'),
      'confirm_workforce_attendance' =>
        canAccessModule(AppModule.workforceManagement) &&
            hasAnyPermission(const [
              'workforce.attendance.self',
              'workforce.attendance.qr.self',
            ]),
      _ => false,
    };
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final context = ref.watch(userContextProvider);
  final modules = ref.watch(activeModulesProvider);
  final grants = <String>{};
  for (final module in ref.watch(modulesProvider).modules) {
    for (final permission in module.permissions) {
      if (permission == '*') {
        grants.add('${module.slug}.*');
        grants.add('${module.slug.replaceAll('-', '_')}.*');
      } else if (permission.contains('.')) {
        grants.add(permission);
      } else {
        grants.add('${module.slug}.$permission');
      }
    }
  }

  return PermissionService(
    context: context,
    activeModules: modules,
    grantedPermissions: grants,
  );
});
