import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/schedule_model.dart';
import '../domain/schedule_provider.dart';

enum _TaskFilter {
  all('Все'),
  overdue('Просроченные'),
  critical('Критические'),
  inProgress('В работе'),
  completed('Завершенные');

  const _TaskFilter(this.label);

  final String label;
}

class ScheduleDetailsScreen extends ConsumerStatefulWidget {
  const ScheduleDetailsScreen({
    super.key,
    required this.scheduleId,
  });

  final int scheduleId;

  @override
  ConsumerState<ScheduleDetailsScreen> createState() =>
      _ScheduleDetailsScreenState();
}

class _ScheduleDetailsScreenState extends ConsumerState<ScheduleDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  _TaskFilter _selectedFilter = _TaskFilter.all;
  String _searchQuery = '';

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
    final nextValue = _searchController.text.trim();
    if (_searchQuery == nextValue) {
      return;
    }

    setState(() {
      _searchQuery = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleDetailProvider(widget.scheduleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали графика'),
        centerTitle: false,
      ),
      body: state.isLoading && state.detail == null
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.detail == null
              ? AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить график',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => ref
                        .read(scheduleDetailProvider(widget.scheduleId).notifier)
                        .load(),
                    child: const Text('Повторить'),
                  ),
                )
              : _ScheduleDetailsContent(
                  detail: state.detail!,
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  onRefresh: () => ref
                      .read(scheduleDetailProvider(widget.scheduleId).notifier)
                      .load(),
                  isRefreshing: state.isLoading,
                ),
    );
  }
}

class _ScheduleDetailsContent extends StatelessWidget {
  const _ScheduleDetailsContent({
    required this.detail,
    required this.searchController,
    required this.searchQuery,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final ScheduleDetailsModel detail;
  final TextEditingController searchController;
  final String searchQuery;
  final _TaskFilter selectedFilter;
  final ValueChanged<_TaskFilter> onFilterChanged;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _sortTasks(
      detail.tasks
          .where(
            (task) =>
                _matchesFilter(task, selectedFilter) &&
                _matchesSearch(task, searchQuery),
          )
          .toList(),
    );
    final sections = _buildSections(filteredTasks);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _ScheduleDetailHeader(
                detail: detail,
                isRefreshing: isRefreshing,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _ScheduleDetailSummary(summary: detail.summary),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _TaskOperationalBanner(
                tasks: detail.tasks,
                summary: detail.summary,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _ScheduleInfoCard(schedule: detail.schedule),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _TaskFiltersCard(
                controller: searchController,
                selectedFilter: selectedFilter,
                resultCount: filteredTasks.length,
                totalCount: detail.tasks.length,
                onFilterChanged: onFilterChanged,
                onClearSearch: searchQuery.isEmpty
                    ? null
                    : () {
                        searchController.clear();
                      },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Задачи графика',
                style: AppTypography.h2(context),
              ),
            ),
          ),
          if (detail.tasks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppStateView(
                  icon: Icons.checklist_outlined,
                  title: 'Задач пока нет',
                  description:
                      'У этого графика пока нет задач для отображения.',
                ),
              ),
            )
          else if (filteredTasks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppStateView(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'По фильтру ничего не найдено',
                  description:
                      'Снимите часть ограничений или попробуйте другой запрос.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: sections
                      .map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _TaskSection(
                            title: section.title,
                            subtitle: section.subtitle,
                            tasks: section.tasks,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleDetailHeader extends StatelessWidget {
  const _ScheduleDetailHeader({
    required this.detail,
    required this.isRefreshing,
  });

  final ScheduleDetailsModel detail;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final schedule = detail.schedule;
    final statusColor = _parseColor(
      schedule.statusColor,
      Theme.of(context).colorScheme.primary,
    );
    final progressColor = _parseColor(
      schedule.progressColor,
      Theme.of(context).colorScheme.secondary,
    );

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((detail.project?.name ?? '').isNotEmpty)
                      Text(
                        detail.project!.name,
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      schedule.name,
                      style: AppTypography.h1(context),
                    ),
                  ],
                ),
              ),
              if (isRefreshing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(
                label: schedule.statusLabel,
                color: statusColor,
              ),
              _TypeBadge(
                label:
                    'Прогресс ${schedule.overallProgressPercent.toStringAsFixed(1)}%',
                color: progressColor,
              ),
              if (schedule.overdueTasksCount > 0)
                const _TypeBadge(
                  label: 'Есть просрочка',
                  color: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (schedule.overallProgressPercent.clamp(0, 100)) / 100,
              minHeight: 8,
              color: progressColor,
              backgroundColor:
                  Theme.of(context).colorScheme.outline.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDetailSummary extends StatelessWidget {
  const _ScheduleDetailSummary({required this.summary});

  final ScheduleDetailsSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Всего задач',
                value: summary.tasksCount.toString(),
                icon: Icons.checklist_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'В работе',
                value: summary.inProgressTasksCount.toString(),
                icon: Icons.play_circle_outline_rounded,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Завершено',
                value: summary.completedTasksCount.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Просрочено',
                value: summary.overdueTasksCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskOperationalBanner extends StatelessWidget {
  const _TaskOperationalBanner({
    required this.tasks,
    required this.summary,
  });

  final List<ScheduleTaskModel> tasks;
  final ScheduleDetailsSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final criticalCount = tasks.where((task) => task.isCritical).length;
    final hasAttention = summary.overdueTasksCount > 0 || criticalCount > 0;
    final theme = Theme.of(context);

    return IndustrialCard(
      backgroundColor: hasAttention
          ? theme.colorScheme.secondaryContainer.withOpacity(0.45)
          : theme.colorScheme.primaryContainer.withOpacity(0.35),
      borderColor: hasAttention
          ? theme.colorScheme.secondary.withOpacity(0.3)
          : theme.colorScheme.primary.withOpacity(0.2),
      child: Row(
        children: [
          Icon(
            hasAttention ? Icons.report_problem_outlined : Icons.task_alt_rounded,
            color: hasAttention
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAttention ? 'Есть риски по задачам' : 'График выглядит стабильно',
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAttention
                      ? 'Просроченных задач: ${summary.overdueTasksCount}. Критических задач: $criticalCount.'
                      : 'Просроченных и критических задач сейчас нет.',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFiltersCard extends StatelessWidget {
  const _TaskFiltersCard({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.totalCount,
    required this.onFilterChanged,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final _TaskFilter selectedFilter;
  final int resultCount;
  final int totalCount;
  final ValueChanged<_TaskFilter> onFilterChanged;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Поиск по названию, описанию и типу задачи',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: onClearSearch == null
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _TaskFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selectedFilter == filter,
                    label: Text(filter.label),
                    onSelected: (_) => onFilterChanged(filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Найдено: $resultCount из $totalCount',
            style: AppTypography.caption(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: AppTypography.h2(context)),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _ScheduleInfoCard extends StatelessWidget {
  const _ScheduleInfoCard({required this.schedule});

  final ScheduleItemModel schedule;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Параметры графика',
            style: AppTypography.h2(context),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Плановый период',
            value:
                '${_formatDate(schedule.plannedStartDate)} - ${_formatDate(schedule.plannedEndDate)}',
          ),
          _InfoRow(
            label: 'Длительность',
            value: schedule.plannedDurationDays != null
                ? '${schedule.plannedDurationDays} дн.'
                : 'Не указана',
          ),
          _InfoRow(
            label: 'Критический путь',
            value: schedule.criticalPathCalculated
                ? (schedule.criticalPathDurationDays != null
                    ? 'Рассчитан, ${schedule.criticalPathDurationDays} дн.'
                    : 'Рассчитан')
                : 'Не рассчитан',
          ),
          _InfoRow(
            label: 'Задач',
            value:
                '${schedule.completedTasksCount}/${schedule.tasksCount} завершено',
          ),
          if ((schedule.description ?? '').trim().isNotEmpty)
            _InfoRow(
              label: 'Описание',
              value: schedule.description!,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLarge(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.subtitle,
    required this.tasks,
  });

  final String title;
  final String subtitle;
  final List<ScheduleTaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.h2(context),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodyMedium(context).copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(task: task),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final ScheduleTaskModel task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _parseColor(
      task.statusColor,
      theme.colorScheme.primary,
    );
    final leftPadding = (task.level * 14).clamp(0, 42).toDouble();
    final isOverdue = _isOverdueTask(task);
    final borderColor = isOverdue
        ? AppColors.warning
        : task.isCritical
            ? AppColors.secondary
            : null;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: IndustrialCard(
        borderColor: borderColor,
        backgroundColor: isOverdue
            ? theme.colorScheme.secondaryContainer.withOpacity(0.16)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        style: AppTypography.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusBadge(
                            label: task.statusLabel,
                            color: statusColor,
                          ),
                          _TypeBadge(label: task.taskTypeLabel),
                          if (task.isCritical)
                            const _TypeBadge(
                              label: 'Критическая',
                              color: AppColors.warning,
                            ),
                          if (isOverdue)
                            const _TypeBadge(
                              label: 'Просрочена',
                              color: AppColors.error,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${task.progressPercent.toStringAsFixed(1)}%',
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (task.progressPercent.clamp(0, 100)) / 100,
                minHeight: 8,
                color: statusColor,
                backgroundColor: theme.colorScheme.outline.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TaskMeta(
                  icon: Icons.event_outlined,
                  label:
                      '${_formatDate(task.plannedStartDate)} - ${_formatDate(task.plannedEndDate)}',
                ),
                if (task.childrenCount > 0)
                  _TaskMeta(
                    icon: Icons.account_tree_outlined,
                    label: 'Подзадач: ${task.childrenCount}',
                  ),
                if (task.plannedDurationDays != null)
                  _TaskMeta(
                    icon: Icons.timelapse_rounded,
                    label: '${task.plannedDurationDays} дн.',
                  ),
                if (task.quantity != null)
                  _TaskMeta(
                    icon: Icons.straighten_rounded,
                    label: task.completedQuantity != null
                        ? '${_formatQuantity(task.completedQuantity!)}/${_formatQuantity(task.quantity!)} ${task.measurementUnit ?? ''}'.trim()
                        : '${_formatQuantity(task.quantity!)} ${task.measurementUnit ?? ''}'.trim(),
                  ),
              ],
            ),
            if ((task.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                task.description!,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: resolvedColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSectionData {
  const _TaskSectionData({
    required this.title,
    required this.subtitle,
    required this.tasks,
  });

  final String title;
  final String subtitle;
  final List<ScheduleTaskModel> tasks;
}

List<_TaskSectionData> _buildSections(List<ScheduleTaskModel> tasks) {
  final overdue = <ScheduleTaskModel>[];
  final critical = <ScheduleTaskModel>[];
  final regular = <ScheduleTaskModel>[];

  for (final task in tasks) {
    if (_isOverdueTask(task)) {
      overdue.add(task);
      continue;
    }

    if (task.isCritical) {
      critical.add(task);
      continue;
    }

    regular.add(task);
  }

  final sections = <_TaskSectionData>[];

  if (overdue.isNotEmpty) {
    sections.add(
      _TaskSectionData(
        title: 'Просроченные',
        subtitle: 'Задачи, которые уже выбились из планового срока.',
        tasks: overdue,
      ),
    );
  }

  if (critical.isNotEmpty) {
    sections.add(
      _TaskSectionData(
        title: 'Критические',
        subtitle: 'Задачи, влияющие на срок графика.',
        tasks: critical,
      ),
    );
  }

  if (regular.isNotEmpty) {
    sections.add(
      _TaskSectionData(
        title: 'Остальные задачи',
        subtitle: 'Полный список задач по текущему графику.',
        tasks: regular,
      ),
    );
  }

  return sections;
}

List<ScheduleTaskModel> _sortTasks(List<ScheduleTaskModel> tasks) {
  tasks.sort((left, right) {
    final overdueCompare = _boolPriority(_isOverdueTask(right))
        .compareTo(_boolPriority(_isOverdueTask(left)));
    if (overdueCompare != 0) {
      return overdueCompare;
    }

    final criticalCompare =
        _boolPriority(right.isCritical).compareTo(_boolPriority(left.isCritical));
    if (criticalCompare != 0) {
      return criticalCompare;
    }

    final progressCompare = right.progressPercent.compareTo(left.progressPercent);
    if (progressCompare != 0) {
      return progressCompare > 0 ? 1 : -1;
    }

    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });

  return tasks;
}

bool _matchesFilter(ScheduleTaskModel task, _TaskFilter filter) {
  return switch (filter) {
    _TaskFilter.all => true,
    _TaskFilter.overdue => _isOverdueTask(task),
    _TaskFilter.critical => task.isCritical,
    _TaskFilter.inProgress => _isInProgressTask(task),
    _TaskFilter.completed => _isCompletedTask(task),
  };
}

bool _matchesSearch(ScheduleTaskModel task, String query) {
  if (query.isEmpty) {
    return true;
  }

  final normalizedQuery = query.toLowerCase();
  final haystack = [
    task.name,
    task.description ?? '',
    task.taskTypeLabel,
    task.statusLabel,
  ].join(' ').toLowerCase();

  return haystack.contains(normalizedQuery);
}

bool _isOverdueTask(ScheduleTaskModel task) {
  if (_isCompletedTask(task)) {
    return false;
  }

  final normalized =
      '${task.status} ${task.statusLabel}'.trim().toLowerCase();
  if (normalized.contains('overdue') || normalized.contains('просроч')) {
    return true;
  }

  final plannedEndDate = task.plannedEndDate;
  if (plannedEndDate == null || plannedEndDate.isEmpty) {
    return false;
  }

  final parsed = DateTime.tryParse(plannedEndDate);
  if (parsed == null) {
    return false;
  }

  final today = DateTime.now();
  final dayOnly = DateTime(today.year, today.month, today.day);
  final plannedDay = DateTime(parsed.year, parsed.month, parsed.day);

  return plannedDay.isBefore(dayOnly);
}

bool _isInProgressTask(ScheduleTaskModel task) {
  if (_isCompletedTask(task)) {
    return false;
  }

  final normalized =
      '${task.status} ${task.statusLabel}'.trim().toLowerCase();
  return normalized.contains('progress') ||
      normalized.contains('active') ||
      normalized.contains('started') ||
      normalized.contains('в работе') ||
      normalized.contains('актив') ||
      task.progressPercent > 0;
}

bool _isCompletedTask(ScheduleTaskModel task) {
  final normalized =
      '${task.status} ${task.statusLabel}'.trim().toLowerCase();
  return normalized.contains('completed') ||
      normalized.contains('done') ||
      normalized.contains('finished') ||
      normalized.contains('заверш');
}

int _boolPriority(bool value) => value ? 1 : 0;

String _formatDate(String? value) {
  if (value == null || value.isEmpty) {
    return 'Дата не указана';
  }

  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}

Color _parseColor(String? value, Color fallback) {
  if (value == null || value.isEmpty) {
    return fallback;
  }

  final normalized = value.replaceFirst('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final parsed = int.tryParse(hex, radix: 16);

  return parsed == null ? fallback : Color(parsed);
}
