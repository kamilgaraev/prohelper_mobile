import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/schedule_model.dart';
import '../domain/schedule_provider.dart';
import 'schedule_details_screen.dart';

enum _ScheduleFilter {
  all('Все'),
  atRisk('В риске'),
  overdue('Просрочка'),
  active('Активные'),
  completed('Завершено');

  const _ScheduleFilter(this.label);

  final String label;
}

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  final TextEditingController _searchController = TextEditingController();
  _ScheduleFilter _selectedFilter = _ScheduleFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectId = ref.read(projectsProvider).selectedProject?.serverId;
      ref.read(scheduleProvider.notifier).load(projectId: projectId);
    });
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
    if (nextValue == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final overview = state.overview;

    final schedules = overview == null
        ? const <ScheduleItemModel>[]
        : _sortSchedules(
            overview.schedules
                .where(
                  (schedule) =>
                      _matchesFilter(schedule, _selectedFilter) &&
                      _matchesSearch(schedule, _searchQuery),
                )
                .toList(),
          );
    final attentionCount = overview?.schedules.where(_hasAttention).length ?? 0;
    final overdueSchedulesCount = overview?.schedules
            .where((schedule) => schedule.overdueTasksCount > 0)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('График работ'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(scheduleProvider.notifier).load(
              projectId: selectedProject?.serverId,
            ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (selectedProject == null)
              const SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.timeline_outlined,
                  title: 'Объект не выбран',
                  description:
                      'Сначала выберите объект, чтобы открыть графики работ.',
                ),
              )
            else if (state.isLoading && overview == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && overview == null)
              SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить графики работ',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => ref.read(scheduleProvider.notifier).load(
                          projectId: selectedProject.serverId,
                        ),
                    child: const Text('Повторить'),
                  ),
                ),
              )
            else if (overview == null)
              const SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.timeline_outlined,
                  title: 'Графики работ пока недоступны',
                  description: 'Попробуйте обновить экран позже.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ScheduleHeader(
                    projectName: overview.project?.name ?? selectedProject.name,
                    isRefreshing: state.isLoading,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ScheduleSummaryGrid(summary: overview.summary),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ScheduleOperationalBanner(
                    totalSchedules: overview.schedules.length,
                    attentionCount: attentionCount,
                    overdueSchedulesCount: overdueSchedulesCount,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ScheduleFiltersCard(
                    controller: _searchController,
                    selectedFilter: _selectedFilter,
                    resultCount: schedules.length,
                    totalCount: overview.schedules.length,
                    onFilterChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    onClearSearch: _searchQuery.isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                          },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Графики объекта',
                    style: AppTypography.h2(context),
                  ),
                ),
              ),
              if (overview.schedules.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppStateView(
                      icon: Icons.event_note_outlined,
                      title: 'Графиков пока нет',
                      description:
                          'Для выбранного объекта еще не создано ни одного графика работ.',
                    ),
                  ),
                )
              else if (schedules.isEmpty)
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
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final schedule = schedules[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ScheduleCard(
                            schedule: schedule,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ScheduleDetailsScreen(
                                  scheduleId: schedule.id,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: schedules.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _matchesSearch(ScheduleItemModel schedule, String query) {
    if (query.isEmpty) {
      return true;
    }

    final normalizedQuery = query.toLowerCase();
    final haystack = [
      schedule.name,
      schedule.description ?? '',
      schedule.statusLabel,
      _healthStatusLabel(schedule.healthStatus),
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }

  bool _matchesFilter(ScheduleItemModel schedule, _ScheduleFilter filter) {
    return switch (filter) {
      _ScheduleFilter.all => true,
      _ScheduleFilter.atRisk => _hasAttention(schedule),
      _ScheduleFilter.overdue => schedule.overdueTasksCount > 0,
      _ScheduleFilter.active => _isActiveSchedule(schedule),
      _ScheduleFilter.completed => _isCompletedSchedule(schedule),
    };
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.projectName,
    required this.isRefreshing,
  });

  final String projectName;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projectName,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Список графиков работ по выбранному объекту',
                style: AppTypography.bodyLarge(context),
              ),
            ],
          ),
        ),
        if (isRefreshing)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }
}

class _ScheduleSummaryGrid extends StatelessWidget {
  const _ScheduleSummaryGrid({required this.summary});

  final ScheduleOverviewSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ScheduleSummaryCard(
                title: 'Всего графиков',
                value: summary.totalSchedules.toString(),
                icon: Icons.timeline_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScheduleSummaryCard(
                title: 'Активных',
                value: summary.activeSchedules.toString(),
                icon: Icons.play_circle_outline_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ScheduleSummaryCard(
                title: 'Завершено',
                value: summary.completedSchedules.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScheduleSummaryCard(
                title: 'Средний прогресс',
                value: '${summary.averageProgressPercent.toStringAsFixed(1)}%',
                icon: Icons.bar_chart_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScheduleOperationalBanner extends StatelessWidget {
  const _ScheduleOperationalBanner({
    required this.totalSchedules,
    required this.attentionCount,
    required this.overdueSchedulesCount,
  });

  final int totalSchedules;
  final int attentionCount;
  final int overdueSchedulesCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAttention = attentionCount > 0;
    final title = hasAttention ? 'Нужны действия' : 'Ситуация под контролем';
    final description = hasAttention
        ? 'Графиков с риском: $attentionCount. Из них с просрочкой: $overdueSchedulesCount.'
        : 'Все $totalSchedules графиков сейчас без критичных сигналов.';

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
            hasAttention ? Icons.priority_high_rounded : Icons.track_changes,
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
                  title,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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

class _ScheduleFiltersCard extends StatelessWidget {
  const _ScheduleFiltersCard({
    required this.controller,
    required this.selectedFilter,
    required this.resultCount,
    required this.totalCount,
    required this.onFilterChanged,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final _ScheduleFilter selectedFilter;
  final int resultCount;
  final int totalCount;
  final ValueChanged<_ScheduleFilter> onFilterChanged;
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
              hintText: 'Поиск по названию, описанию или статусу',
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
              children: _ScheduleFilter.values.map((filter) {
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

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
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
          Text(title, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
  });

  final ScheduleItemModel schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _parseColor(
      schedule.statusColor,
      theme.colorScheme.primary,
    );
    final progressColor = _parseColor(
      schedule.progressColor,
      theme.colorScheme.secondary,
    );
    final healthLabel = _healthStatusLabel(schedule.healthStatus);
    final healthColor = _healthStatusColor(context, schedule.healthStatus);
    final hasAttention = _hasAttention(schedule);

    return IndustrialCard(
      onTap: onTap,
      borderColor: hasAttention ? AppColors.warning : null,
      backgroundColor: hasAttention
          ? theme.colorScheme.secondaryContainer.withOpacity(0.18)
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
                      schedule.name,
                      style: AppTypography.h2(context),
                    ),
                    if ((schedule.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        schedule.description!,
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ScheduleBadge(
                label: schedule.statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (healthLabel != null)
                _MetaPill(
                  icon: Icons.monitor_heart_outlined,
                  label: healthLabel,
                  color: healthColor,
                ),
              if (schedule.overdueTasksCount > 0)
                _MetaPill(
                  icon: Icons.warning_amber_rounded,
                  label: 'Просрочено задач: ${schedule.overdueTasksCount}',
                  color: AppColors.warning,
                ),
              _MetaPill(
                icon: Icons.rule_folder_outlined,
                label: schedule.criticalPathCalculated
                    ? 'Критический путь рассчитан'
                    : 'Критический путь не рассчитан',
                color: schedule.criticalPathCalculated
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Прогресс ${schedule.overallProgressPercent.toStringAsFixed(1)}%',
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${schedule.completedTasksCount}/${schedule.tasksCount} задач',
                style: AppTypography.caption(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (schedule.overallProgressPercent.clamp(0, 100)) / 100,
              minHeight: 8,
              color: progressColor,
              backgroundColor: theme.colorScheme.outline.withOpacity(0.12),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: Icons.event_outlined,
                label:
                    '${_formatDate(schedule.plannedStartDate)} - ${_formatDate(schedule.plannedEndDate)}',
              ),
              if (schedule.plannedDurationDays != null)
                _MetaPill(
                  icon: Icons.timelapse_rounded,
                  label: '${schedule.plannedDurationDays} дн.',
                ),
              if (schedule.actualStartDate != null)
                _MetaPill(
                  icon: Icons.play_arrow_rounded,
                  label: 'Старт: ${_formatDate(schedule.actualStartDate)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleBadge extends StatelessWidget {
  const _ScheduleBadge({
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

List<ScheduleItemModel> _sortSchedules(List<ScheduleItemModel> schedules) {
  schedules.sort((left, right) {
    final attentionCompare =
        _boolPriority(_hasAttention(right)).compareTo(_boolPriority(_hasAttention(left)));
    if (attentionCompare != 0) {
      return attentionCompare;
    }

    final overdueCompare =
        right.overdueTasksCount.compareTo(left.overdueTasksCount);
    if (overdueCompare != 0) {
      return overdueCompare;
    }

    final leftEndDate = _dateSortValue(left.plannedEndDate);
    final rightEndDate = _dateSortValue(right.plannedEndDate);
    final endDateCompare = leftEndDate.compareTo(rightEndDate);
    if (endDateCompare != 0) {
      return endDateCompare;
    }

    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });

  return schedules;
}

bool _hasAttention(ScheduleItemModel schedule) {
  return schedule.overdueTasksCount > 0 ||
      _isHealthProblem(schedule.healthStatus) ||
      (!_isCompletedSchedule(schedule) &&
          schedule.criticalPathCalculated == false &&
          schedule.tasksCount > 0);
}

bool _isCompletedSchedule(ScheduleItemModel schedule) {
  final value =
      '${schedule.status} ${schedule.statusLabel}'.trim().toLowerCase();
  return value.contains('completed') ||
      value.contains('done') ||
      value.contains('finished') ||
      value.contains('заверш');
}

bool _isActiveSchedule(ScheduleItemModel schedule) {
  if (_isCompletedSchedule(schedule)) {
    return false;
  }

  final value =
      '${schedule.status} ${schedule.statusLabel}'.trim().toLowerCase();
  return value.contains('active') ||
      value.contains('progress') ||
      value.contains('started') ||
      value.contains('в работе') ||
      value.contains('актив') ||
      schedule.overallProgressPercent > 0;
}

bool _isHealthProblem(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'at_risk' ||
      normalized == 'warning' ||
      normalized == 'critical' ||
      normalized == 'delayed' ||
      normalized == 'overdue';
}

String? _healthStatusLabel(String value) {
  final normalized = value.trim().toLowerCase();

  return switch (normalized) {
    '' => null,
    'healthy' || 'on_track' => 'По плану',
    'at_risk' || 'warning' => 'Есть риск',
    'critical' || 'delayed' || 'overdue' => 'Требует внимания',
    _ => value,
  };
}

Color _healthStatusColor(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase();

  return switch (normalized) {
    'healthy' || 'on_track' => AppColors.success,
    'at_risk' || 'warning' => AppColors.warning,
    'critical' || 'delayed' || 'overdue' => AppColors.error,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

int _boolPriority(bool value) => value ? 1 : 0;

DateTime _dateSortValue(String? value) {
  final parsed = value == null ? null : DateTime.tryParse(value);
  return parsed ?? DateTime(9999);
}

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

Color _parseColor(String? value, Color fallback) {
  if (value == null || value.isEmpty) {
    return fallback;
  }

  final normalized = value.replaceFirst('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final parsed = int.tryParse(hex, radix: 16);

  return parsed == null ? fallback : Color(parsed);
}
