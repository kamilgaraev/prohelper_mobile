import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/action_hub.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/industrial_card.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_home_screen.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/profile_pill.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/user_profile_bottom_sheet.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/construction_journal_screen.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/machinery_operations_screen.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:prohelpers_mobile/features/production_labor/presentation/production_labor_screen.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';
import 'package:prohelpers_mobile/features/safety/presentation/safety_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';
import 'package:prohelpers_mobile/features/time_tracking/presentation/time_tracking_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';
import 'package:prohelpers_mobile/features/workflow_management/presentation/workflow_management_screen.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/workforce_attendance_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              if (dashboardState.isLoading && dashboardState.widgets.isEmpty)
                const SliverFillRemaining(
                  child: AppLoadingState(message: 'Загружаем рабочий стол'),
                )
              else if (dashboardState.error != null &&
                  dashboardState.widgets.isEmpty)
                SliverFillRemaining(
                  child: AppErrorState(
                    title: 'Не удалось загрузить дашборд',
                    description: dashboardState.error,
                    onRetry:
                        () =>
                            ref
                                .read(dashboardControllerProvider.notifier)
                                .loadDashboard(),
                  ),
                )
              else if (dashboardState.widgets.isEmpty)
                const SliverFillRemaining(
                  child: AppEmptyState(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'Пока нет доступных разделов',
                    description:
                        'Для вашей роли еще не назначены разделы для работы в приложении.',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final dashboardWidget = dashboardState.widgets[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildDashboardCard(context, dashboardWidget),
                      );
                    }, childCount: dashboardState.widgets.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ],
          ),
          const Positioned(bottom: 0, left: 0, right: 0, child: ActionHub()),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      floating: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: Consumer(
        builder: (context, ref, _) {
          final projectsState = ref.watch(projectsProvider);
          final selectedProject = projectsState.selectedProject;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedProject != null)
                Text(
                  'Текущий объект',
                  style: AppTypography.caption(context).copyWith(
                    fontSize: 10,
                    letterSpacing: 0,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                (selectedProject?.name ?? 'PROHELPER').toUpperCase(),
                style: AppTypography.h2(context).copyWith(
                  letterSpacing: 0,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
      centerTitle: false,
      actions: [
        Consumer(
          builder: (context, ref, _) {
            final unreadCount = ref.watch(
              notificationsProvider.select((state) => state.unreadCount),
            );

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Уведомления',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            textAlign: TextAlign.center,
                            style: AppTypography.caption(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authProvider);
            if (authState is! AuthAuthenticated) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: ProfilePill(
                  user: authState.user,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (_) => UserProfileBottomSheet(user: authState.user),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    DashboardWidgetModel dashboardWidget,
  ) {
    final theme = Theme.of(context);
    final color = _colorForStatus(context, dashboardWidget.status);
    final target = _screenForRoute(dashboardWidget.route);

    return IndustrialCard(
      onTap:
          target == null
              ? null
              : () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => target));
              },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForSlug(dashboardWidget.slug), color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dashboardWidget.title,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetric(
                        context,
                        dashboardWidget.primaryMetric,
                        color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetric(
                        context,
                        dashboardWidget.secondaryMetric,
                        color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (target != null) ...[
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    DashboardMetric metric,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            metric.displayValue,
            style: AppTypography.bodyLarge(context).copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _iconForSlug(String slug) {
    return switch (slug) {
      'project_overview' => Icons.domain_rounded,
      'site_requests' => Icons.add_task_rounded,
      'site_request_approvals' => Icons.fact_check_rounded,
      'warehouse' => Icons.warehouse_outlined,
      'schedule' => Icons.timeline_rounded,
      'ai_assistant' => Icons.smart_toy_outlined,
      'construction_journal' => Icons.menu_book_rounded,
      'quality_control' => Icons.verified_outlined,
      'safety_management' => Icons.health_and_safety_rounded,
      'machinery_operations' => Icons.precision_manufacturing_rounded,
      'production_labor' => Icons.assignment_turned_in_rounded,
      'workforce_management' => Icons.badge_rounded,
      'handover_acceptance' => Icons.handshake_rounded,
      'workflow_management' => Icons.hub_outlined,
      'workflow-management' => Icons.hub_outlined,
      'time_tracking' => Icons.timer_outlined,
      'time-tracking' => Icons.timer_outlined,
      _ => Icons.dashboard_customize_outlined,
    };
  }

  Color _colorForStatus(BuildContext context, DashboardWidgetStatus status) {
    return switch (status) {
      DashboardWidgetStatus.ok => AppColors.success,
      DashboardWidgetStatus.active => Theme.of(context).colorScheme.primary,
      DashboardWidgetStatus.attention => AppColors.warning,
      DashboardWidgetStatus.critical => AppColors.error,
    };
  }

  Widget? _screenForRoute(String route) {
    return switch (route) {
      'project_selection' => const ProjectSelectionScreen(),
      'site_requests' => const SiteRequestsScreen(),
      'site_request_approvals' => const SiteRequestsScreen(
        scope: SiteRequestsScope.approvals,
      ),
      'warehouse' => const WarehouseScreen(),
      'schedule' => const ScheduleScreen(),
      'ai_assistant' => const AiAssistantHomeScreen(),
      'construction_journal' => const ConstructionJournalScreen(),
      'workflow-management' => const WorkflowManagementScreen(),
      'workflow_management' => const WorkflowManagementScreen(),
      'time-tracking' => const TimeTrackingScreen(),
      'time_tracking' => const TimeTrackingScreen(),
      'quality-control' => const QualityControlScreen(),
      'safety-management' => const SafetyScreen(),
      'machinery-operations' => const MachineryOperationsScreen(),
      'production-labor' => const ProductionLaborScreen(),
      'workforce-management' => const WorkforceAttendanceScreen(),
      'handover-acceptance' => const HandoverAcceptanceScreen(),
      _ => null,
    };
  }
}
