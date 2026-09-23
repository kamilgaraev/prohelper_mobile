import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_empty_states.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_search.dart';
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

  void _clearSearch() {
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final modulesState = ref.watch(modulesProvider);
    final modules = ref.watch(supportedMobileModulesProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final hasSelectedProject = selectedProject != null;
    final allDestinations = visibleMobileDestinations(modules)
        .where(
          (destination) => (!destination.requiresProject || hasSelectedProject),
        )
        .toList(growable: false);
    final filteredDestinations = filterMobileActions(allDestinations, _query);

    return ProPageScaffold(
      title: 'Работа',
      subtitle: selectedProject?.name ?? 'Объект не выбран',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ),
          if (modulesState.isLoading && allDestinations.isEmpty)
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
              onClearSearch: _query.isEmpty ? null : _clearSearch,
              density: ProSearchFilterDensity.compact,
              resultLabel:
                  _query.isEmpty
                      ? 'Доступно разделов: ${allDestinations.length}'
                      : 'Найдено: ${filteredDestinations.length}',
            ),
            const SizedBox(height: 20),
            if (filteredDestinations.isEmpty)
              AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Разделы не найдены',
                description: 'Попробуйте изменить запрос.',
                action:
                    _query.isEmpty
                        ? null
                        : OutlinedButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Сбросить поиск'),
                        ),
              )
            else
              for (final group in MobileAdminGroup.values)
                _WorkGroup(
                  group: group,
                  destinations: filteredDestinations
                      .where((destination) => destination.adminGroup == group)
                      .toList(growable: false),
                ),
          ],
        ],
      ),
    );
  }
}

class _WorkGroup extends StatelessWidget {
  const _WorkGroup({required this.group, required this.destinations});

  final MobileAdminGroup group;
  final List<MobileModuleDestination> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ProSurface(
        tone: ProSurfaceTone.elevated,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ProSpacing.md,
                ProSpacing.md,
                ProSpacing.md,
                0,
              ),
              child: ProSectionHeader(title: group.label),
            ),
            const ProSectionDivider(indent: ProSpacing.md),
            for (var index = 0; index < destinations.length; index++) ...[
              _WorkDestinationRow(destination: destinations[index]),
              if (index != destinations.length - 1)
                const ProSectionDivider(indent: 72),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkDestinationRow extends StatelessWidget {
  const _WorkDestinationRow({required this.destination});

  final MobileModuleDestination destination;

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
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: destination.builder));
        },
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
