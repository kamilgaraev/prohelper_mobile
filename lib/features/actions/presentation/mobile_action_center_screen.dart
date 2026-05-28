import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'mobile_action_search.dart';
import 'mobile_recommended_actions_section.dart';

class MobileActionCenterScreen extends ConsumerStatefulWidget {
  const MobileActionCenterScreen({super.key});

  @override
  ConsumerState<MobileActionCenterScreen> createState() =>
      _MobileActionCenterScreenState();
}

class _MobileActionCenterScreenState
    extends ConsumerState<MobileActionCenterScreen> {
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
    final modulesState = ref.watch(modulesProvider);
    final modules = ref.watch(supportedMobileModulesProvider);
    final smartActions = ref.watch(mobileRecommendedActionsProvider);
    final destinations = uniqueDestinations(
      modules.map(
        (module) =>
            MobileNavigationRegistry.destinationForRoute(module.route) ??
            MobileNavigationRegistry.destinationForRoute(module.slug),
      ),
    );
    final filteredDestinations = filterMobileActions(destinations, _query);

    return ProPageScaffold(
      title: 'Действия',
      subtitle: 'Быстрый доступ к рабочим сценариям',
      body: MobileActionCenterContent(
        modulesState: modulesState,
        smartActions: smartActions,
        allDestinations: filteredDestinations,
        totalDestinations: destinations.length,
        searchController: _searchController,
        query: _query,
        onClearSearch: _query.isEmpty ? null : () => _searchController.clear(),
        onOpenDestination:
            (destination) => _openDestination(context, destination),
        onOpenRecommendation:
            (action) => _openDestination(context, action.destination),
        onRetry: () => ref.read(modulesProvider.notifier).loadModules(),
      ),
    );
  }
}

class MobileActionCenterContent extends StatelessWidget {
  const MobileActionCenterContent({
    super.key,
    required this.modulesState,
    required this.smartActions,
    required this.allDestinations,
    required this.totalDestinations,
    required this.searchController,
    required this.query,
    required this.onOpenDestination,
    required this.onOpenRecommendation,
    required this.onRetry,
    this.onClearSearch,
  });

  final ModulesState modulesState;
  final List<MobileActionRecommendation> smartActions;
  final List<MobileModuleDestination> allDestinations;
  final int totalDestinations;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<MobileModuleDestination> onOpenDestination;
  final ValueChanged<MobileActionRecommendation> onOpenRecommendation;
  final VoidCallback onRetry;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    if (modulesState.isLoading && totalDestinations == 0) {
      return const AppLoadingState(message: 'Загружаем действия');
    }

    if (modulesState.error != null && totalDestinations == 0) {
      return AppErrorState(
        title: 'Не удалось загрузить действия',
        description: modulesState.error,
        onRetry: onRetry,
      );
    }

    if (totalDestinations == 0) {
      return const AppEmptyState(
        icon: Icons.grid_view_rounded,
        title: 'Нет доступных действий',
        description: 'Для вашей роли пока нет мобильных разделов.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProSearchFilterBar<String>(
          controller: searchController,
          hintText: 'Найти действие или раздел',
          options: const [],
          selectedValue: 'all',
          onFilterChanged: (_) {},
          onClearSearch: onClearSearch,
          resultLabel:
              query.isEmpty
                  ? 'Доступно разделов: $totalDestinations'
                  : 'Найдено: ${allDestinations.length} из $totalDestinations',
        ),
        const SizedBox(height: 20),
        if (query.isEmpty) ...[
          MobileRecommendedActionsSection(
            actions: smartActions,
            onOpen: onOpenRecommendation,
          ),
          const SizedBox(height: 20),
        ],
        ProSectionBlock(
          title: 'Все разделы',
          subtitle: 'Разделы сгруппированы по рабочим задачам.',
          children: [
            for (final group in MobileModuleGroup.values)
              _ActionGroup(
                group: group,
                destinations: allDestinations
                    .where((destination) => destination.group == group)
                    .toList(growable: false),
                onOpen: onOpenDestination,
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.group,
    required this.destinations,
    required this.onOpen,
  });

  final MobileModuleGroup group;
  final List<MobileModuleDestination> destinations;
  final ValueChanged<MobileModuleDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return ProSectionBlock(
      title: group.label,
      children: [
        for (final destination in destinations)
          ProActionTile(
            title: destination.shortTitle,
            subtitle:
                destination.title == destination.shortTitle
                    ? destination.recommendedReason
                    : '${destination.title} · ${destination.recommendedReason}',
            icon: destination.icon,
            onTap: () => onOpen(destination),
          ),
      ],
    );
  }
}

void _openDestination(
  BuildContext context,
  MobileModuleDestination destination,
) {
  HapticFeedback.mediumImpact();
  Navigator.of(context).push(MaterialPageRoute(builder: destination.builder));
}
