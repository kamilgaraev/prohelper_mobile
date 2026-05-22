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
  String? _selectedWorkDate;

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
    final visiblePlans =
        _selectedWorkDate == null
            ? state.plans
            : state.plans
                .where((plan) => plan.workDate == _selectedWorkDate)
                .toList();

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
                  title:
                      state.permissionDenied
                          ? 'Недостаточно прав'
                          : 'Не удалось загрузить дневные планы',
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _DailyPlanDateNavigator(
                    plans: state.plans,
                    selectedWorkDate: _selectedWorkDate,
                    onChanged: (workDate) {
                      setState(() {
                        _selectedWorkDate = workDate;
                      });
                    },
                  ),
                ),
              ),
              if (visiblePlans.isEmpty)
                const SliverFillRemaining(
                  child: AppEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'На выбранную дату планов нет',
                    description: 'Выберите другую дату или покажите все планы.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == visiblePlans.length - 1 ? 0 : 12,
                        ),
                        child: _DailyPlanCard(plan: visiblePlans[index]),
                      ),
                      childCount: visiblePlans.length,
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

class _DailyPlanDateNavigator extends StatelessWidget {
  const _DailyPlanDateNavigator({
    required this.plans,
    required this.selectedWorkDate,
    required this.onChanged,
  });

  final List<DailyWorkPlanModel> plans;
  final String? selectedWorkDate;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final dates =
        plans.map((plan) => plan.workDate).toSet().toList()
          ..sort((left, right) => left.compareTo(right));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selectedWorkDate == null,
              label: const Text('Все'),
              onSelected: (_) => onChanged(null),
            ),
          ),
          ...dates.map(
            (workDate) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selectedWorkDate == workDate,
                label: Text(_formatDate(workDate)),
                onSelected: (_) => onChanged(workDate),
              ),
            ),
          ),
        ],
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
                        plan.scheduleName,
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
                if (plan.hasAction(ScheduleActionKeys.submit))
                  OutlinedButton.icon(
                    onPressed: () => _showSubmitSheet(context, ref),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('На приемку'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...plan.assignments.map(
              (assignment) => _DailyAssignmentTile(
                assignment: assignment,
                canRecordFact: plan.hasAction(ScheduleActionKeys.recordFact),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubmitSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _SubmitDailyPlanSheet(
            plan: plan,
            onSubmit:
                (summaryComment) => ref
                    .read(dailyWorkPlansProvider.notifier)
                    .submit(plan, summaryComment: summaryComment),
          ),
    );
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
                  constraint.hasAction(ScheduleActionKeys.createLinkedAction) &&
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
                assignment.scheduleTaskName,
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
                      onPressed: () => _showFactSheet(context, ref),
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

  Future<void> _showFactSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _DailyFactSheet(
            assignment: assignment,
            onSubmit:
                (input) => ref
                    .read(dailyWorkPlansProvider.notifier)
                    .recordFact(assignment, input),
          ),
    );
  }

  Future<void> _createLinkedAction(
    BuildContext context,
    WidgetRef ref,
    DailyWorkConstraintModel constraint,
  ) async {
    try {
      await ref
          .read(dailyWorkPlansProvider.notifier)
          .createLinkedConstraintAction(constraint, null);
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

class _SubmitDailyPlanSheet extends StatefulWidget {
  const _SubmitDailyPlanSheet({required this.plan, required this.onSubmit});

  final DailyWorkPlanModel plan;
  final Future<void> Function(String? summaryComment) onSubmit;

  @override
  State<_SubmitDailyPlanSheet> createState() => _SubmitDailyPlanSheetState();
}

class _SubmitDailyPlanSheetState extends State<_SubmitDailyPlanSheet> {
  final TextEditingController _summaryController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Передать на приемку', style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Text(
            widget.plan.scheduleName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _summaryController,
            enabled: !_isSubmitting,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Что важно учесть при приемке',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon:
                  _isSubmitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_rounded),
              label: const Text('Передать'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final summary = _summaryController.text.trim();
      await widget.onSubmit(summary.isEmpty ? null : summary);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дневной план передан на приемку')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _DailyFactSheet extends StatefulWidget {
  const _DailyFactSheet({required this.assignment, required this.onSubmit});

  final DailyWorkPlanAssignmentModel assignment;
  final Future<void> Function(DailyWorkFactInput input) onSubmit;

  @override
  State<_DailyFactSheet> createState() => _DailyFactSheetState();
}

class _DailyFactSheetState extends State<_DailyFactSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _completedQuantityController =
      TextEditingController();
  final TextEditingController _actualWorkHoursController =
      TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _failureReasonController =
      TextEditingController();
  String? _status;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _completedQuantityController.dispose();
    _actualWorkHoursController.dispose();
    _commentController.dispose();
    _failureReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isNotDone = _status == 'not_done';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Факт дневного задания', style: AppTypography.h2(context)),
              const SizedBox(height: 8),
              Text(
                widget.assignment.scheduleTaskName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Результат',
                  border: OutlineInputBorder(),
                ),
                items:
                    widget.assignment.factStatusOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.status,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                onChanged:
                    _isSubmitting
                        ? null
                        : (value) {
                          setState(() {
                            _status = value;
                          });
                        },
                validator:
                    (value) =>
                        value == null ? 'Выберите результат работ.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _completedQuantityController,
                enabled: !_isSubmitting && !isNotDone,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Выполненный объем',
                  hintText:
                      widget.assignment.plannedQuantity == null
                          ? null
                          : 'План: ${_formatNumber(widget.assignment.plannedQuantity)}',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _validateQuantity(value, isNotDone),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _actualWorkHoursController,
                enabled: !_isSubmitting && !isNotDone,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Фактические часы',
                  hintText:
                      widget.assignment.plannedWorkHours == null
                          ? null
                          : 'План: ${_formatNumber(widget.assignment.plannedWorkHours)}',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _validateQuantity(value, isNotDone),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commentController,
                enabled: !_isSubmitting,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  hintText: 'Что было выполнено на объекте',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _failureReasonController,
                enabled: !_isSubmitting,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Причина невыполнения',
                  hintText: 'Заполните, если работы не выполнены',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_status != 'not_done') {
                    return null;
                  }

                  return value == null || value.trim().isEmpty
                      ? 'Укажите причину невыполнения.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon:
                      _isSubmitting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.fact_check_outlined),
                  label: const Text('Сохранить факт'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateQuantity(String? value, bool isNotDone) {
    if (isNotDone) {
      return null;
    }

    final parsed = _parseNonNegativeNumber(value);
    if (parsed == null) {
      return 'Введите число.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(
        DailyWorkFactInput(
          status: _status!,
          completedQuantity:
              _status == 'not_done'
                  ? null
                  : _parseNonNegativeNumber(_completedQuantityController.text),
          actualWorkHours:
              _status == 'not_done'
                  ? null
                  : _parseNonNegativeNumber(_actualWorkHoursController.text),
          factComment: _commentController.text,
          failureReason: _failureReasonController.text,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Факт дневного задания зафиксирован')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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
    return 'Не указано';
  }

  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
}

double? _parseNonNegativeNumber(String? value) {
  final normalized = value?.trim().replaceAll(',', '.') ?? '';
  if (normalized.isEmpty) {
    return null;
  }

  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    return null;
  }

  return parsed;
}
