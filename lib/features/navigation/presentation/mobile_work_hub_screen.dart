import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_empty_states.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_search.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_recommended_actions_section.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';

class MobileWorkHubScreen extends ConsumerStatefulWidget {
  const MobileWorkHubScreen({super.key});

  @override
  ConsumerState<MobileWorkHubScreen> createState() =>
      _MobileWorkHubScreenState();
}

class _MobileWorkHubScreenState extends ConsumerState<MobileWorkHubScreen> {
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
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final recommendations = ref.watch(mobileRecommendedActionsProvider);
    final hasSelectedProject = selectedProject != null;
    final allDestinations = uniqueDestinations(
          modules.map(
            (module) =>
                MobileNavigationRegistry.destinationForRoute(module.route) ??
                MobileNavigationRegistry.destinationForRoute(module.slug),
          ),
        )
        .where(
          (destination) =>
              _workGroups.contains(destination.group) &&
              (!destination.requiresProject || hasSelectedProject),
        )
        .toList(growable: false);
    final filteredDestinations = filterMobileActions(allDestinations, _query);

    return ProPageScaffold(
      title: 'Работа',
      subtitle: selectedProject?.name ?? 'Объект не выбран',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProStatusBanner(
            title: 'Задачи на объекте, смены и контроль выполнения',
            description:
                'Разделы собраны по рабочим сценариям, чтобы не искать нужный модуль по названию.',
            tone: ProStatusTone.info,
          ),
          const SizedBox(height: 20),
          if (!hasSelectedProject)
            ProNoProjectState(
              action: FilledButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProjectSelectionScreen(),
                      ),
                    ),
                icon: const Icon(Icons.domain_rounded),
                label: const Text('Выбрать объект'),
              ),
            )
          else if (modulesState.isLoading && allDestinations.isEmpty)
            const AppLoadingState(message: 'Загружаем рабочие разделы')
          else if (modulesState.error != null && allDestinations.isEmpty)
            AppErrorState(
              title: 'Не удалось загрузить разделы',
              description: modulesState.error,
              onRetry: () => ref.read(modulesProvider.notifier).loadModules(),
            )
          else ...[
            ProSearchFilterBar<String>(
              controller: _searchController,
              hintText: 'Найти раздел',
              options: const [],
              selectedValue: 'all',
              onFilterChanged: (_) {},
              onClearSearch:
                  _query.isEmpty ? null : () => _searchController.clear(),
              resultLabel:
                  _query.isEmpty
                      ? 'Доступно разделов: ${allDestinations.length}'
                      : 'Найдено: ${filteredDestinations.length}',
            ),
            if (_query.isEmpty && recommendations.isNotEmpty) ...[
              const SizedBox(height: 20),
              MobileRecommendedActionsSection(
                title: 'Следующие в работе',
                subtitle: 'Действия, которые сейчас полезнее всего.',
                actions: recommendations,
                onOpen:
                    (action) => Navigator.of(context).push(
                      MaterialPageRoute(builder: action.destination.builder),
                    ),
              ),
            ],
            const SizedBox(height: 20),
            if (filteredDestinations.isEmpty)
              const AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Разделы не найдены',
                description: 'Попробуйте изменить запрос.',
              )
            else
              for (final group in _workGroups)
                _WorkGroup(
                  group: group,
                  destinations: filteredDestinations
                      .where((destination) => destination.group == group)
                      .toList(growable: false),
                ),
          ],
        ],
      ),
    );
  }
}

const _workGroups = <MobileModuleGroup>[
  MobileModuleGroup.fieldWork,
  MobileModuleGroup.warehouseAndSupply,
  MobileModuleGroup.approvalsAndDocs,
];

class _WorkGroup extends StatelessWidget {
  const _WorkGroup({required this.group, required this.destinations});

  final MobileModuleGroup group;
  final List<MobileModuleDestination> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ProSectionBlock(
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
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: destination.builder)),
            ),
        ],
      ),
    );
  }
}
