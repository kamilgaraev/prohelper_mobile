import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/providers/module_provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/schedule_model.dart';
import '../data/schedule_repository.dart';
import '../../projects/domain/projects_provider.dart';

class ScheduleTaskDetailScreen extends ConsumerStatefulWidget {
  const ScheduleTaskDetailScreen({
    super.key,
    required this.taskId,
    this.projectId,
    this.allowedActions = const [],
  });

  final int taskId;
  final int? projectId;
  final List<String> allowedActions;

  @override
  ConsumerState<ScheduleTaskDetailScreen> createState() =>
      _ScheduleTaskDetailScreenState();
}

class _ScheduleTaskDetailScreenState
    extends ConsumerState<ScheduleTaskDetailScreen> {
  late Future<ScheduleTaskModel> _taskFuture;

  @override
  void initState() {
    super.initState();
    _taskFuture = ref.read(scheduleRepositoryProvider).fetchTask(widget.taskId);
  }

  void _reload() {
    setState(() {
      _taskFuture = ref
          .read(scheduleRepositoryProvider)
          .fetchTask(widget.taskId);
    });
  }

  Future<void> _editTask(ScheduleTaskModel task) async {
    final name = TextEditingController(text: task.name);
    final description = TextEditingController(text: task.description ?? '');
    final start = TextEditingController(text: task.plannedStartDate ?? '');
    final end = TextEditingController(text: task.plannedEndDate ?? '');
    final form = GlobalKey<FormState>();
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Изменить задачу'),
            content: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Название'),
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Укажите название'
                                  : null,
                    ),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Описание'),
                      maxLines: 3,
                    ),
                    TextFormField(
                      controller: start,
                      decoration: const InputDecoration(
                        labelText: 'Начало (ГГГГ-ММ-ДД)',
                      ),
                    ),
                    TextFormField(
                      controller: end,
                      decoration: const InputDecoration(
                        labelText: 'Окончание (ГГГГ-ММ-ДД)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(dialogContext, <String, dynamic>{
                      'name': name.text.trim(),
                      'description': description.text.trim(),
                      'planned_start_date':
                          start.text.trim().isEmpty ? null : start.text.trim(),
                      'planned_end_date':
                          end.text.trim().isEmpty ? null : end.text.trim(),
                    });
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
    );
    name.dispose();
    description.dispose();
    start.dispose();
    end.dispose();
    if (payload == null || !mounted) return;
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .saveTask(
            scheduleId: widget.taskId,
            taskId: widget.taskId,
            data: payload,
          );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Задача сохранена.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectId =
        ref.watch(projectsProvider).selectedProject?.serverId;
    final canEdit = canEditScheduleTask(
      allowedActions: widget.allowedActions,
      actionProjectId: widget.projectId,
      selectedProjectId: selectedProjectId,
      hasPermission: ref
          .watch(permissionServiceProvider)
          .hasPermission('schedule.edit'),
      hasModule: ref
          .watch(activeModulesProvider)
          .contains(AppModule.scheduleManagement),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Задача графика')),
      body: FutureBuilder<ScheduleTaskModel>(
        future: _taskFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Загружаем задачу');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Не удалось открыть задачу',
              description: UserMessage.fromError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final task = snapshot.data;
          if (task == null) {
            return AppErrorState(
              title: 'Задача не найдена',
              description: 'Обновите экран или проверьте доступ к задаче.',
              onRetry: _reload,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              IndustrialCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.name, style: AppTypography.h1(context)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(task.statusLabel)),
                        Chip(label: Text(task.taskTypeLabel)),
                        if (task.isCritical)
                          const Chip(label: Text('Критическая')),
                      ],
                    ),
                    if ((task.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        task.description!,
                        style: AppTypography.bodyMedium(context),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _editTask(task),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Изменить задачу'),
                ),
              ],
              const SizedBox(height: 12),
              IndustrialCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сроки и выполнение',
                      style: AppTypography.h2(context),
                    ),
                    const SizedBox(height: 12),
                    _DetailLine(label: 'Начало', value: task.plannedStartDate),
                    _DetailLine(label: 'Окончание', value: task.plannedEndDate),
                    _DetailLine(
                      label: 'Фактическое начало',
                      value: task.actualStartDate,
                    ),
                    _DetailLine(
                      label: 'Фактическое окончание',
                      value: task.actualEndDate,
                    ),
                    _DetailLine(
                      label: 'Прогресс',
                      value: '${task.progressPercent.toStringAsFixed(1)}%',
                    ),
                    if (task.quantity != null)
                      _DetailLine(
                        label: 'Объём',
                        value:
                            '${task.completedQuantity ?? 0} / ${task.quantity} ${task.measurementUnit ?? ''}'
                                .trim(),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

bool canEditScheduleTask({
  required List<String> allowedActions,
  required int? actionProjectId,
  required int? selectedProjectId,
  required bool hasPermission,
  required bool hasModule,
}) {
  return allowedActions.contains('update') &&
      actionProjectId != null &&
      actionProjectId == selectedProjectId &&
      hasPermission &&
      hasModule;
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if ((value ?? '').isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: AppTypography.caption(context)),
          ),
          Expanded(
            child: Text(value!, style: AppTypography.bodyMedium(context)),
          ),
        ],
      ),
    );
  }
}
