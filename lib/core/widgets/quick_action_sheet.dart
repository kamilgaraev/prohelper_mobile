import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_center_screen.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_search.dart';

class QuickActionSheet extends ConsumerStatefulWidget {
  const QuickActionSheet({super.key});

  @override
  ConsumerState<QuickActionSheet> createState() => _QuickActionSheetState();
}

class _QuickActionSheetState extends ConsumerState<QuickActionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim();
    if (nextQuery == _query) {
      return;
    }

    setState(() => _query = nextQuery);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modulesState = ref.watch(modulesProvider);
    final modules = ref.watch(supportedMobileModulesProvider);
    final smartActions = ref.watch(mobileRecommendedActionsProvider);
    final allDestinations = uniqueDestinations(
      modules.map(
        (module) =>
            MobileNavigationRegistry.destinationForRoute(module.route) ??
            MobileNavigationRegistry.destinationForRoute(module.slug),
      ),
    );
    final filteredDestinations = filterMobileActions(allDestinations, _query);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.28,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Действия',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                key: const ValueKey('quick-action-sheet-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                children: [
                  MobileActionCenterContent(
                    modulesState: modulesState,
                    smartActions: smartActions,
                    allDestinations: filteredDestinations,
                    totalDestinations: allDestinations.length,
                    searchController: _searchController,
                    query: _query,
                    onClearSearch:
                        _query.isEmpty ? null : () => _searchController.clear(),
                    onOpenDestination:
                        (destination) => _openDestination(context, destination),
                    onOpenRecommendation:
                        (action) =>
                            _openDestination(context, action.destination),
                    onRetry:
                        () => ref.read(modulesProvider.notifier).loadModules(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openDestination(
  BuildContext context,
  MobileModuleDestination destination,
) {
  HapticFeedback.mediumImpact();
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  }
  navigator.push(MaterialPageRoute(builder: destination.builder));
}
