import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/schedule_model.dart';
import '../domain/schedule_provider.dart';

class ScheduleDetailsScreen extends ConsumerWidget {
  const ScheduleDetailsScreen({
    super.key,
    required this.scheduleId,
  });

  final int scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleDetailProvider(scheduleId));

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
                        .read(scheduleDetailProvider(scheduleId).notifier)
                        .load(),
                    child: const Text('Повторить'),
                  ),
                )
              : _ScheduleDetailsContent(
                  detail: state.detail!,
                  onRefresh: () => ref
                      .read(scheduleDetailProvider(scheduleId).notifier)
                      .load(),
                  isRefreshing: state.isLoading,
                ),
    );
  }
}

class _ScheduleDetailsContent extends StatelessWidget {
  const _ScheduleDetailsContent({
    required this.detail,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final ScheduleDetailsModel detail;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
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
              child: _ScheduleInfoCard(schedule: detail.schedule),
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
                  description: 'У этого графика пока нет задач для отображения.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = detail.tasks[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskCard(task: task),
                    );
                  },
                  childCount: detail.tasks.length,
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
          Row(
            children: [
              _StatusBadge(
                label: schedule.statusLabel,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Прогресс ${schedule.overallProgressPercent.toStringAsFixed(1)}%',
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

    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: IndustrialCard(
        borderColor: task.isCritical ? AppColors.warning : null,
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
                            _TypeBadge(
                              label: 'Критическая',
                              color: AppColors.warning,
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
                if (task.quantity != null)
                  _TaskMeta(
                    icon: Icons.straighten_rounded,
                    label: task.completedQuantity != null
                        ? '${task.completedQuantity}/${task.quantity} ${task.measurementUnit ?? ''}'.trim()
                        : '${task.quantity} ${task.measurementUnit ?? ''}'.trim(),
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
