import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/schedule_model.dart';
import '../domain/schedule_provider.dart';

class ScheduleDailyPlansScreen extends ConsumerStatefulWidget {
  const ScheduleDailyPlansScreen({super.key});

  @override
  ConsumerState<ScheduleDailyPlansScreen> createState() =>
      _ScheduleDailyPlansScreenState();
}

class _ScheduleDailyPlansScreenState
    extends ConsumerState<ScheduleDailyPlansScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectId = ref.read(projectsProvider).selectedProject?.serverId;
      ref.read(dailyWorkPlansProvider.notifier).load(projectId: projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyWorkPlansProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    return Scaffold(
      appBar: AppBar(title: const Text('Дневные планы'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh:
            () => ref
                .read(dailyWorkPlansProvider.notifier)
                .load(projectId: selectedProject?.serverId),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (selectedProject == null)
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.domain_outlined,
                  title: 'Объект не выбран',
                  description:
                      'Сначала выберите объект, чтобы открыть дневные планы работ.',
                ),
              )
            else if (state.isLoading && state.plans.isEmpty)
              const SliverFillRemaining(
                child: AppLoadingState(message: 'Загружаем дневные планы'),
              )
            else if (state.error != null && state.plans.isEmpty)
              SliverFillRemaining(
                child: AppErrorState(
                  title: 'Не удалось загрузить дневные планы',
                  description: state.error,
                  onRetry:
                      () => ref
                          .read(dailyWorkPlansProvider.notifier)
                          .load(projectId: selectedProject.serverId),
                ),
              )
            else if (state.plans.isEmpty)
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Дневных планов нет',
                  description:
                      'Когда инженер выпустит дневной план, он появится здесь для фиксации факта.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    selectedProject.name,
                    style: AppTypography.h2(context),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == state.plans.length - 1 ? 0 : 12,
                      ),
                      child: _DailyPlanCard(plan: state.plans[index]),
                    ),
                    childCount: state.plans.length,
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

class _DailyPlanCard extends ConsumerWidget {
  const _DailyPlanCard({required this.plan});

  final DailyWorkPlanModel plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IndustrialCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        plan.scheduleName ?? 'График ${plan.scheduleId}',
                        style: AppTypography.bodyLarge(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDate(plan.workDate)} · ${plan.statusLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (plan.availableActions.contains('submit'))
                  OutlinedButton.icon(
                    onPressed: () => _submit(context, ref),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('На приемку'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.assignments.map(
              (assignment) => _DailyAssignmentTile(
                assignment: assignment,
                canRecordFact: plan.availableActions.contains('record_fact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(dailyWorkPlansProvider.notifier).submit(plan);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Дневной план передан на приемку')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _DailyAssignmentTile extends ConsumerWidget {
  const _DailyAssignmentTile({
    required this.assignment,
    required this.canRecordFact,
  });

  final DailyWorkPlanAssignmentModel assignment;
  final bool canRecordFact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hardConstraints =
        assignment.constraints
            .where(
              (constraint) =>
                  constraint.severity == 'hard' && constraint.status == 'open',
            )
            .toList();
    final actionableHardConstraints =
        hardConstraints
            .where(
              (constraint) =>
                  constraint.availableActions.contains(
                    'create_linked_action',
                  ) &&
                  constraint.linkedAction == null,
            )
            .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignment.scheduleTaskName ??
                    'Задача ${assignment.scheduleTaskId}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'План: ${_formatNumber(assignment.plannedQuantity)} ед., ${_formatNumber(assignment.plannedWorkHours)} ч. · Факт: ${_formatNumber(assignment.completedQuantity)} ед.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (hardConstraints.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      hardConstraints
                          .map(
                            (constraint) => Chip(
                              avatar: const Icon(
                                Icons.report_problem_outlined,
                                size: 16,
                              ),
                              label: Text(constraint.title),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                ),
              ],
              if (canRecordFact) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _recordFact(context, ref),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Факт выполнен'),
                    ),
                    if (actionableHardConstraints.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed:
                            () => _createLinkedAction(
                              context,
                              ref,
                              actionableHardConstraints.first,
                            ),
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('Зафиксировать препятствие'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordFact(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(dailyWorkPlansProvider.notifier).recordFact(assignment);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Факт дневного задания зафиксирован')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _createLinkedAction(
    BuildContext context,
    WidgetRef ref,
    DailyWorkConstraintModel constraint,
  ) async {
    try {
      await ref
          .read(dailyWorkPlansProvider.notifier)
          .createLinkedConstraintAction(constraint);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Препятствие зафиксировано')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) {
    return 'Дата не задана';
  }

  final parts = value.split('-');
  if (parts.length == 3) {
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  return value;
}

String _formatNumber(double? value) {
  if (value == null) {
    return '0';
  }

  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}
