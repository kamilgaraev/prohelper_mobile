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

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectId = ref.read(projectsProvider).selectedProject?.serverId;
      ref.read(scheduleProvider.notifier).load(projectId: projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final overview = state.overview;

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
                  description: 'Сначала выберите объект, чтобы открыть графики работ.',
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
                      description: 'Для выбранного объекта еще не создано ни одного графика работ.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final schedule = overview.schedules[index];

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
                      childCount: overview.schedules.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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

    return IndustrialCard(
      onTap: onTap,
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
              _MetaPill(
                icon: Icons.rule_folder_outlined,
                label: schedule.criticalPathCalculated
                    ? 'Критический путь рассчитан'
                    : 'Критический путь не рассчитан',
              ),
              if (schedule.overdueTasksCount > 0)
                _MetaPill(
                  icon: Icons.warning_amber_rounded,
                  label: 'Просрочено: ${schedule.overdueTasksCount}',
                  color: AppColors.warning,
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
