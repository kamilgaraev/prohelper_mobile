import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
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

  void _clearSearch() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
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
        onClearSearch: _query.isEmpty ? null : _clearSearch,
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
          density: ProSearchFilterDensity.compact,
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
        _ActionCatalogPanel(
          destinations: allDestinations,
          onOpen: onOpenDestination,
          onClearSearch: query.isEmpty ? null : onClearSearch,
        ),
      ],
    );
  }
}

class _ActionCatalogPanel extends StatelessWidget {
  const _ActionCatalogPanel({
    required this.destinations,
    required this.onOpen,
    this.onClearSearch,
  });

  final List<MobileModuleDestination> destinations;
  final ValueChanged<MobileModuleDestination> onOpen;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final groupedDestinations = [
      for (final group in MobileModuleGroup.values)
        (
          group: group,
          destinations: destinations
              .where((destination) => destination.group == group)
              .toList(growable: false),
        ),
    ].where((entry) => entry.destinations.isNotEmpty).toList(growable: false);

    if (groupedDestinations.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Действия не найдены',
        description: 'Попробуйте изменить запрос.',
        action:
            onClearSearch == null
                ? null
                : OutlinedButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Сбросить поиск'),
                ),
        minHeight: 180,
      );
    }

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              ProSpacing.md,
              ProSpacing.md,
              ProSpacing.md,
              0,
            ),
            child: ProSectionHeader(
              title: 'Все разделы',
              subtitle: 'Разделы сгруппированы по рабочим задачам.',
            ),
          ),
          const ProSectionDivider(indent: ProSpacing.md),
          for (
            var groupIndex = 0;
            groupIndex < groupedDestinations.length;
            groupIndex++
          ) ...[
            _ActionGroupSection(
              group: groupedDestinations[groupIndex].group,
              destinations: groupedDestinations[groupIndex].destinations,
              onOpen: onOpen,
            ),
            if (groupIndex != groupedDestinations.length - 1)
              const ProSectionDivider(indent: ProSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ActionGroupSection extends StatelessWidget {
  const _ActionGroupSection({
    required this.group,
    required this.destinations,
    required this.onOpen,
  });

  final MobileModuleGroup group;
  final List<MobileModuleDestination> destinations;
  final ValueChanged<MobileModuleDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ProSpacing.md,
            ProSpacing.md,
            ProSpacing.md,
            ProSpacing.xs,
          ),
          child: Text(
            group.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        for (var index = 0; index < destinations.length; index++) ...[
          _ActionDestinationRow(
            destination: destinations[index],
            onOpen: onOpen,
          ),
          if (index != destinations.length - 1)
            const ProSectionDivider(indent: 72),
        ],
      ],
    );
  }
}

class _ActionDestinationRow extends StatelessWidget {
  const _ActionDestinationRow({
    required this.destination,
    required this.onOpen,
  });

  final MobileModuleDestination destination;
  final ValueChanged<MobileModuleDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, ProStatusTone.info);
    final theme = Theme.of(context);
    final subtitle =
        destination.title == destination.shortTitle
            ? destination.recommendedReason
            : '${destination.title} · ${destination.recommendedReason}';

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: InkWell(
        onTap: () => onOpen(destination),
        child: Padding(
          padding: const EdgeInsets.all(ProSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(ProRadius.sm),
                ),
                child: Icon(
                  destination.icon,
                  color: status.foreground,
                  size: 22,
                ),
              ),
              const SizedBox(width: ProSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.shortTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: ProSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ProSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
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
  Navigator.of(context).push(MaterialPageRoute(builder: destination.builder));
}
