import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_state.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_center_screen.dart';
import 'package:prohelpers_mobile/features/home/presentation/mobile_overview_screen.dart';
import 'package:prohelpers_mobile/features/navigation/presentation/mobile_more_screen.dart';
import 'package:prohelpers_mobile/features/navigation/presentation/mobile_work_hub_screen.dart';

class MobileAppShell extends ConsumerWidget {
  const MobileAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedTab = ref.watch(mobileNavigationProvider);
    return Scaffold(
      body: IndexedStack(
        index: selectedTab.index,
        children: const [
          MobileOverviewScreen(),
          MobileWorkHubScreen(),
          MobileActionCenterScreen(),
          MobileMoreScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: theme.colorScheme.outline.withValues(
                alpha: isDark ? 0.34 : 0.42,
              ),
              child: const SizedBox(height: 0.5, width: double.infinity),
            ),
            NavigationBar(
              animationDuration: ProMotion.normal,
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              height: ProTouchTarget.comfortable + ProSpacing.lg,
              indicatorColor: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.22 : 0.12,
              ),
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              selectedIndex: selectedTab.index,
              onDestinationSelected:
                  ref.read(mobileNavigationProvider.notifier).setTabByIndex,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Обзор',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.engineering_outlined),
                  selectedIcon: Icon(Icons.engineering_rounded),
                  label: 'Работа',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt_rounded),
                  label: 'Действия',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Ещё',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
