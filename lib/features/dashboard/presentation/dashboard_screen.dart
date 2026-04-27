import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/widgets/action_hub.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_view.dart';
import 'package:prohelpers_mobile/core/widgets/industrial_card.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_home_screen.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/profile_pill.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/user_profile_bottom_sheet.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final activeModules = ref.watch(activeModulesProvider);
    final hasAiAssistant = activeModules.contains(AppModule.aiAssistant);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              if (dashboardState.isLoading && dashboardState.widgets.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (dashboardState.error != null &&
                  dashboardState.widgets.isEmpty)
                SliverFillRemaining(
                  child: AppStateView(
                    icon: Icons.error_outline_rounded,
                    title: 'Не удалось загрузить дашборд',
                    description: dashboardState.error,
                    action: OutlinedButton(
                      onPressed:
                          () =>
                              ref
                                  .read(dashboardControllerProvider.notifier)
                                  .loadDashboard(),
                      child: const Text('Повторить'),
                    ),
                  ),
                )
              else if (dashboardState.widgets.isEmpty)
                const SliverFillRemaining(
                  child: AppStateView(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'Дашборд пока пуст',
                    description:
                        'Для вашей роли пока не подключены мобильные виджеты.',
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
                      final widget = dashboardState.widgets[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildWidgetByType(context, ref, widget),
                      );
                    }, childCount: dashboardState.widgets.length),
                  ),
                ),
                if (hasAiAssistant)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _buildAiAssistantCard(context),
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
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                (selectedProject?.name ?? 'PROHELPER').toUpperCase(),
                style: AppTypography.h2(context).copyWith(
                  letterSpacing: 0.5,
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

  Widget _buildWidgetByType(
    BuildContext context,
    WidgetRef ref,
    DashboardWidgetModel widget,
  ) {
    return switch (widget.type) {
      DashboardWidgetType.projectOverview => _buildProjectOverview(
        context,
        ref,
        widget,
      ),
      DashboardWidgetType.siteRequests => _buildSiteRequestsCard(
        context,
        widget,
      ),
      DashboardWidgetType.siteRequestApprovals => _buildApprovalsCard(
        context,
        widget,
      ),
      DashboardWidgetType.warehouse => _buildWarehouseCard(context, widget),
      DashboardWidgetType.schedule => _buildScheduleCard(context, widget),
      DashboardWidgetType.unknown => const SizedBox.shrink(),
    };
  }

  Widget _buildProjectOverview(
    BuildContext context,
    WidgetRef ref,
    DashboardWidgetModel widget,
  ) {
    final theme = Theme.of(context);
    final projectsState = ref.watch(projectsProvider);
    final project = projectsState.selectedProject;

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title.toUpperCase(),
            style: AppTypography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 16),
          if (project == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Объект не выбран',
                  style: AppTypography.bodyLarge(context),
                ),
                if (widget.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            )
          else ...[
            _buildProjectParam(context, 'Название', project.name),
            _buildProjectParam(
              context,
              'Адрес',
              project.address?.trim().isNotEmpty == true
                  ? project.address!
                  : 'Не указан',
            ),
            _buildProjectParam(
              context,
              'Роль на объекте',
              project.myRole?.trim().isNotEmpty == true
                  ? project.myRole!
                  : 'Не указана',
              valueColor: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectParam(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLarge(
                context,
              ).copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseCard(
    BuildContext context,
    DashboardWidgetModel widget,
  ) {
    return _buildModuleActionCard(
      context: context,
      title: widget.title,
      subtitle: widget.description,
      icon: Icons.warehouse_outlined,
      color: Theme.of(context).colorScheme.primary,
      badge: widget.badge,
      onTap:
          (_) => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WarehouseScreen())),
    );
  }

  Widget _buildSiteRequestsCard(
    BuildContext context,
    DashboardWidgetModel widget,
  ) {
    return _buildModuleActionCard(
      context: context,
      title: widget.title,
      subtitle: widget.description,
      icon: Icons.add_task_rounded,
      color: AppColors.secondary,
      badge: widget.badge,
      onTap:
          (_) => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SiteRequestsScreen())),
    );
  }

  Widget _buildApprovalsCard(
    BuildContext context,
    DashboardWidgetModel widget,
  ) {
    return _buildModuleActionCard(
      context: context,
      title: widget.title,
      subtitle: widget.description,
      icon: Icons.fact_check_rounded,
      color: Theme.of(context).colorScheme.primary,
      badge: widget.badge,
      onTap:
          (_) => Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => const SiteRequestsScreen(
                    scope: SiteRequestsScope.approvals,
                  ),
            ),
          ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, DashboardWidgetModel widget) {
    return _buildModuleActionCard(
      context: context,
      title: widget.title,
      subtitle: widget.description,
      icon: Icons.timeline_rounded,
      color: AppColors.success,
      badge: widget.badge,
      onTap:
          (_) => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ScheduleScreen())),
    );
  }

  Widget _buildAiAssistantCard(BuildContext context) {
    return _buildModuleActionCard(
      context: context,
      title: 'AI-ассистент',
      subtitle:
          'История диалогов, быстрые управленческие вопросы и единый рабочий контекст по проекту.',
      icon: Icons.smart_toy_outlined,
      color: AppColors.secondary,
      badge: 'AI',
      onTap:
          (_) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AiAssistantHomeScreen()),
          ),
    );
  }

  Widget _buildModuleActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
    required Function(BuildContext) onTap,
  }) {
    final theme = Theme.of(context);

    return IndustrialCard(
      onTap: () => onTap(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.bodySmall(context).copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (badge != null && badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: AppTypography.caption(
                            context,
                          ).copyWith(color: color, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
