import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/schedule_summary_model.dart';
import '../domain/schedule_provider.dart';

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
    final theme = Theme.of(context);

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
            if (state.isLoading && state.data == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.data == null)
              SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить график работ',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => ref.read(scheduleProvider.notifier).load(
                          projectId: selectedProject?.serverId,
                        ),
                    child: const Text('Повторить'),
                  ),
                ),
              )
            else if (state.data == null)
              const SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.timeline_rounded,
                  title: 'Нет данных по графику',
                  description: 'Как только на сервере появятся события, они отобразятся здесь.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ScheduleSummarySection(
                    summary: state.data!.summary,
                    selectedProjectName: selectedProject?.name,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ближайшие события',
                          style: AppTypography.h2(context),
                        ),
                      ),
                      if (state.isLoading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (state.data!.events.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppStateView(
                      icon: Icons.event_busy_outlined,
                      title: 'Событий пока нет',
                      description: 'На ближайшие дни ничего не запланировано.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = state.data!.events[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ScheduleEventCard(event: event),
                        );
                      },
                      childCount: state.data!.events.length,
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

class _ScheduleSummarySection extends StatelessWidget {
  const _ScheduleSummarySection({
    required this.summary,
    this.selectedProjectName,
  });

  final ScheduleSummaryData summary;
  final String? selectedProjectName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((summary.projectName ?? selectedProjectName)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              summary.projectName ?? selectedProjectName!,
              style: AppTypography.bodyMedium(context).copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _ScheduleSummaryCard(
                title: 'Сегодня',
                value: summary.todayCount.toString(),
                icon: Icons.today_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScheduleSummaryCard(
                title: '7 дней',
                value: summary.upcomingCount.toString(),
                icon: Icons.date_range_rounded,
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
                title: 'Блокирующие',
                value: summary.blockingCount.toString(),
                icon: Icons.block_rounded,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScheduleSummaryCard(
                title: 'В работе',
                value: summary.inProgressCount.toString(),
                icon: Icons.play_circle_outline_rounded,
                color: AppColors.secondary,
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

class _ScheduleEventCard extends StatelessWidget {
  const _ScheduleEventCard({required this.event});

  final ScheduleEventModel event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: AppTypography.h2(context),
                ),
              ),
              if (event.isBlocking)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Блокирует',
                    style: AppTypography.caption(context).copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${event.eventTypeLabel} • ${event.statusLabel}',
            style: AppTypography.bodyMedium(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (event.location?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              event.location!,
              style: AppTypography.bodyMedium(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(event.eventDate),
                  style: AppTypography.bodyMedium(context),
                ),
              ),
              Text(
                event.isAllDay ? 'Весь день' : (event.eventTime ?? 'Без времени'),
                style: AppTypography.bodyMedium(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (event.projectName?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Объект: ${event.projectName}',
              style: AppTypography.caption(context),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Приоритет: ${event.priorityLabel}',
            style: AppTypography.caption(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Дата не указана';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
