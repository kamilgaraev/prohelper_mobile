import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/ai_assistant/presentation/ai_assistant_home_screen.dart';
import '../../features/brigades/presentation/brigades_screen.dart';
import '../../features/budget_estimates/presentation/budget_estimates_screen.dart';
import '../../features/catalog_management/presentation/catalog_management_screen.dart';
import '../../features/change_management/presentation/change_management_screen.dart';
import '../../features/construction_journal/presentation/construction_journal_screen.dart';
import '../../features/contract_management/presentation/contract_management_screen.dart';
import '../../features/executive_documentation/presentation/executive_documentation_screen.dart';
import '../../features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import '../../features/machinery_operations/presentation/machinery_operations_screen.dart';
import '../../features/modules/data/mobile_module_model.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/production_labor/presentation/production_labor_screen.dart';
import '../../features/procurement/presentation/procurement_screen.dart';
import '../../features/project_management/presentation/project_management_screen.dart';
import '../../features/quality_control/presentation/quality_control_screen.dart';
import '../../features/safety/presentation/safety_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/site_requests/presentation/screens/site_requests_screen.dart';
import '../../features/time_tracking/presentation/time_tracking_screen.dart';
import '../../features/warehouse/presentation/warehouse_screen.dart';
import '../../features/video_monitoring/presentation/video_monitoring_screen.dart';
import '../../features/workflow_management/presentation/workflow_management_screen.dart';
import '../../features/workforce/presentation/workforce_attendance_screen.dart';
import '../providers/module_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_empty_state.dart';
import 'app_error_state.dart';
import 'app_loading_state.dart';

class QuickActionSheet extends ConsumerWidget {
  const QuickActionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modulesState = ref.watch(modulesProvider);
    final modules = ref.watch(supportedMobileModulesProvider);
    final sheetMaxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: sheetMaxHeight),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Быстрые действия',
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (modulesState.isLoading && modules.isEmpty)
            const Expanded(
              child: Center(
                child: AppLoadingState(
                  message: 'Загружаем доступные действия',
                  compact: true,
                ),
              ),
            )
          else if (modulesState.error != null && modules.isEmpty)
            Expanded(
              child: AppErrorState(
                title: 'Не удалось загрузить модули',
                description: modulesState.error!,
                minHeight: 180,
                onRetry: () => ref.read(modulesProvider.notifier).loadModules(),
              ),
            )
          else if (modules.isEmpty)
            const Expanded(
              child: AppEmptyState(
                icon: Icons.grid_view_rounded,
                title: 'Нет доступных действий',
                description: 'Для вашей роли пока нет мобильных модулей.',
                minHeight: 180,
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                itemCount: modules.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.82,
                ),
                physics: const ClampingScrollPhysics(),
                itemBuilder: (context, index) {
                  if (index == modules.length) {
                    return _ActionItem(
                      icon: Icons.notifications_none_rounded,
                      label: 'Уведомления',
                      color: theme.colorScheme.primary,
                      onTap: () => _openNotifications(context),
                    );
                  }

                  final module = modules[index];

                  return _ActionItem(
                    icon: _iconFor(module.icon),
                    label: module.title,
                    color: _colorFor(module.route, theme),
                    onTap: () => _openModule(context, module),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openModule(BuildContext context, MobileModuleModel module) {
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    navigator.pop();

    switch (module.route ?? module.slug) {
      case 'site_requests':
      case 'site-requests':
        navigator.push(
          MaterialPageRoute(builder: (_) => const SiteRequestsScreen()),
        );
        return;
      case 'warehouse':
      case 'basic-warehouse':
        navigator.push(
          MaterialPageRoute(builder: (_) => const WarehouseScreen()),
        );
        return;
      case 'schedule':
      case 'schedule-management':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ScheduleScreen()),
        );
        return;
      case 'safety':
      case 'safety-management':
        navigator.push(MaterialPageRoute(builder: (_) => const SafetyScreen()));
        return;
      case 'quality_control':
      case 'quality-control':
        navigator.push(
          MaterialPageRoute(builder: (_) => const QualityControlScreen()),
        );
        return;
      case 'machinery_operations':
      case 'machinery-operations':
        navigator.push(
          MaterialPageRoute(builder: (_) => const MachineryOperationsScreen()),
        );
        return;
      case 'production_labor':
      case 'production-labor':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ProductionLaborScreen()),
        );
        return;
      case 'workforce':
      case 'workforce_management':
      case 'workforce-management':
        navigator.push(
          MaterialPageRoute(builder: (_) => const WorkforceAttendanceScreen()),
        );
        return;
      case 'handover_acceptance':
      case 'handover-acceptance':
        navigator.push(
          MaterialPageRoute(builder: (_) => const HandoverAcceptanceScreen()),
        );
        return;
      case 'construction_journal':
      case 'construction-journal':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ConstructionJournalScreen()),
        );
        return;
      case 'ai_assistant':
      case 'ai-assistant':
        navigator.push(
          MaterialPageRoute(builder: (_) => const AiAssistantHomeScreen()),
        );
        return;
      case 'workflow_management':
      case 'workflow-management':
        navigator.push(
          MaterialPageRoute(builder: (_) => const WorkflowManagementScreen()),
        );
        return;
      case 'time_tracking':
      case 'time-tracking':
        navigator.push(
          MaterialPageRoute(builder: (_) => const TimeTrackingScreen()),
        );
        return;
      case 'budget_estimates':
      case 'budget-estimates':
        navigator.push(
          MaterialPageRoute(builder: (_) => const BudgetEstimatesScreen()),
        );
        return;
      case 'procurement':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ProcurementScreen()),
        );
        return;
      case 'contract-management':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ContractManagementScreen()),
        );
        return;
      case 'change-management':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ChangeManagementScreen()),
        );
        return;
      case 'executive-documentation':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const ExecutiveDocumentationScreen(),
          ),
        );
        return;
      case 'project-management':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ProjectManagementScreen()),
        );
        return;
      case 'catalog-management':
        navigator.push(
          MaterialPageRoute(builder: (_) => const CatalogManagementScreen()),
        );
        return;
      case 'brigades':
        navigator.push(
          MaterialPageRoute(builder: (_) => const BrigadesScreen()),
        );
        return;
      case 'video-monitoring':
        navigator.push(
          MaterialPageRoute(builder: (_) => const VideoMonitoringScreen()),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Раздел не открыт для мобильной работы.'),
          ),
        );
        return;
    }
  }

  IconData _iconFor(String icon) {
    return switch (icon) {
      'clipboard' => Icons.add_task_rounded,
      'warehouse' => Icons.warehouse_outlined,
      'timeline' => Icons.timeline_rounded,
      'spark' => Icons.smart_toy_outlined,
      'journal' => Icons.menu_book_outlined,
      'hub' => Icons.hub_outlined,
      'quality' => Icons.fact_check_outlined,
      'shield-check' => Icons.health_and_safety_outlined,
      'handover' => Icons.assignment_turned_in_outlined,
      'timer' => Icons.timer_outlined,
      'calculate' => Icons.calculate_outlined,
      'procurement' => Icons.inventory_2_outlined,
      'inventory' => Icons.inventory_2_outlined,
      'contract' => Icons.assignment_outlined,
      'change' => Icons.change_circle_outlined,
      'documents' => Icons.description_outlined,
      'project' => Icons.domain_rounded,
      'catalog' => Icons.category_outlined,
      'brigades' => Icons.groups_2_outlined,
      'video' => Icons.videocam_outlined,
      'machinery' => Icons.precision_manufacturing_outlined,
      'engineer' => Icons.engineering_outlined,
      'people' => Icons.groups_rounded,
      'workforce' => Icons.groups_rounded,
      _ => Icons.grid_view_rounded,
    };
  }

  Color _colorFor(String? route, ThemeData theme) {
    final scheme = theme.colorScheme;

    return switch (route) {
      'site_requests' => scheme.secondary,
      'site-requests' => scheme.secondary,
      'warehouse' => scheme.primary,
      'basic-warehouse' => scheme.primary,
      'schedule' => AppColors.success,
      'schedule-management' => AppColors.success,
      'safety' => scheme.error,
      'safety-management' => scheme.error,
      'quality_control' => scheme.tertiary,
      'quality-control' => scheme.tertiary,
      'machinery_operations' => scheme.primary,
      'machinery-operations' => scheme.primary,
      'production_labor' => AppColors.warning,
      'production-labor' => AppColors.warning,
      'workforce' => scheme.secondary,
      'workforce_management' => scheme.secondary,
      'workforce-management' => scheme.secondary,
      'construction_journal' => AppColors.warning,
      'construction-journal' => AppColors.warning,
      'handover_acceptance' => scheme.onSurfaceVariant,
      'handover-acceptance' => scheme.onSurfaceVariant,
      'ai_assistant' => scheme.secondary,
      'ai-assistant' => scheme.secondary,
      'workflow_management' => scheme.primary,
      'workflow-management' => scheme.primary,
      'time_tracking' => AppColors.success,
      'time-tracking' => AppColors.success,
      'budget_estimates' => scheme.tertiary,
      'budget-estimates' => scheme.tertiary,
      'procurement' => scheme.secondary,
      'contract-management' => scheme.primary,
      'change-management' => AppColors.warning,
      'executive-documentation' => scheme.tertiary,
      'project-management' => scheme.primary,
      'catalog-management' => scheme.secondary,
      'brigades' => AppColors.success,
      'video-monitoring' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
