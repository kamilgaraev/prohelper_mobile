import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_state.dart';
import 'package:prohelpers_mobile/features/home/presentation/mobile_now_screen.dart';
import 'package:prohelpers_mobile/features/navigation/presentation/mobile_more_screen.dart';
import 'package:prohelpers_mobile/features/navigation/presentation/mobile_work_hub_screen.dart';

class MobileAppShell extends ConsumerStatefulWidget {
  const MobileAppShell({super.key});

  @override
  ConsumerState<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends ConsumerState<MobileAppShell> {
  final _nowNavigatorKey = GlobalKey<NavigatorState>();
  final _sectionsNavigatorKey = GlobalKey<NavigatorState>();
  final _meNavigatorKey = GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState> _keyFor(MobileNavTab tab) {
    return switch (tab) {
      MobileNavTab.now => _nowNavigatorKey,
      MobileNavTab.sections => _sectionsNavigatorKey,
      MobileNavTab.me => _meNavigatorKey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedTab = ref.watch(mobileNavigationProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        final navigator = _keyFor(selectedTab).currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: selectedTab.index,
          children: [
            _TabNavigator(
              navigatorKey: _nowNavigatorKey,
              home: const MobileNowScreen(),
            ),
            _TabNavigator(
              navigatorKey: _sectionsNavigatorKey,
              home: const MobileWorkHubScreen(),
            ),
            _TabNavigator(
              navigatorKey: _meNavigatorKey,
              home: const MobileMoreScreen(),
            ),
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
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.bolt_outlined),
                    selectedIcon: Icon(Icons.bolt_rounded),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Разделы',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Я',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.home});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => home,
        );
      },
    );
  }
}
