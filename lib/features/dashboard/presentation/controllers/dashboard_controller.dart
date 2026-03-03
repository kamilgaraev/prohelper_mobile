// dashboard_controller.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/providers/module_provider.dart';
import '../../../../core/models/user_context.dart';

enum DashboardWidgetType {
  primaryAction,
  stats,
  urgentRequests,
  approvalCounter,
  timeline,
}

class DashboardState {
  final List<DashboardWidgetType> slots;
  DashboardState({required this.slots});
}

class DashboardController extends StateNotifier<DashboardState> {
  final PermissionService _permissions;

  DashboardController(this._permissions) : super(DashboardState(slots: [])) {
    _initSlots();
  }

  void _initSlots() {
    final slots = <DashboardWidgetType>[];

    if (_permissions.context == UserContext.field) {
      if (_permissions.canAccessModule(AppModule.basicWarehouse)) {
        slots.add(DashboardWidgetType.primaryAction); // QR Scanner
      }
      if (_permissions.canAccessModule(AppModule.siteRequests)) {
        slots.add(DashboardWidgetType.urgentRequests); // Создание заявок
      }
      if (_permissions.canAccessModule(AppModule.scheduleManagement)) {
        slots.add(DashboardWidgetType.timeline); // Лента
      }
    } else { // office (например: Admin, Owner, Manager, Observer)
      slots.add(DashboardWidgetType.stats); // Статистика для руководящих
      
      if (_permissions.canAccessModule(AppModule.siteRequests)) {
        slots.add(DashboardWidgetType.approvalCounter); // Согласования
      }
      if (_permissions.canAccessModule(AppModule.scheduleManagement)) {
        slots.add(DashboardWidgetType.timeline); // Лента
      }
    }

    state = DashboardState(slots: slots);
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
  final permissions = ref.watch(permissionServiceProvider);
  return DashboardController(permissions);
});
