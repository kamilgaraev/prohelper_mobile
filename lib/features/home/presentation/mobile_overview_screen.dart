import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_next_actions.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_project_header.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_today_status.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_work_summary.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';

class MobileOverviewScreen extends ConsumerWidget {
  const MobileOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectsProvider).selectedProject;
    final dashboardState = ref.watch(dashboardControllerProvider);
    final notificationsState = ref.watch(notificationsProvider);
    final authState = ref.watch(authProvider);
    final actions = ref.watch(mobileRecommendedActionsProvider);

    return ProPageScaffold(
      title: 'Обзор',
      subtitle: project?.name ?? 'Объект не выбран',
      onRefresh:
          () => ref.read(dashboardControllerProvider.notifier).loadDashboard(),
      actions: [
        IconButton(
          tooltip: 'Уведомления',
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: Badge(
            isLabelVisible: notificationsState.unreadCount > 0,
            label: Text(
              notificationsState.unreadCount > 99
                  ? '99+'
                  : notificationsState.unreadCount.toString(),
            ),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverviewProjectHeader(
            project: project,
            user: authState.user,
            onSwitchProject:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProjectSelectionScreen(),
                  ),
                ),
          ),
          const SizedBox(height: 20),
          OverviewTodayStatus(
            widgets: dashboardState.widgets,
            unreadCount: notificationsState.unreadCount,
            isLoading: dashboardState.isLoading,
            error: dashboardState.error,
            onRetry:
                () =>
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .loadDashboard(),
          ),
          const SizedBox(height: 20),
          OverviewNextActions(
            actions: actions,
            onOpen:
                (action) => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: action.destination.builder)),
            onOpenActionCenter:
                () => ref
                    .read(mobileNavigationProvider.notifier)
                    .setTab(MobileNavTab.actions),
          ),
          const SizedBox(height: 20),
          OverviewWorkSummary(
            widgets: dashboardState.widgets,
            onOpenGroup: (group) => _openGroup(context, ref, group),
          ),
        ],
      ),
    );
  }

  void _openGroup(
    BuildContext context,
    WidgetRef ref,
    MobileModuleGroup group,
  ) {
    final destinations = MobileNavigationRegistry.byGroup(group);
    final destination = destinations.isEmpty ? null : destinations.first;
    if (destination == null) {
      ref.read(mobileNavigationProvider.notifier).setTab(MobileNavTab.work);
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: destination.builder));
  }
}
