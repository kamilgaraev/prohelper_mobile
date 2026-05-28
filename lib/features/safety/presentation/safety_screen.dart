import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/design/pro_status.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../../core/widgets/pro_metric_tile.dart';
import '../../../core/widgets/pro_status_banner.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/safety_model.dart';
import '../domain/safety_provider.dart';

class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(safetyProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      if (selectedProject != null) {
        notifier.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(safetyProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(safetyProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        if (selectedProject != null) {
          notifier.load();
        }
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Охрана труда'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  selectedProject == null
                      ? null
                      : () => ref.read(safetyProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton:
            selectedProject == null
                ? null
                : FloatingActionButton.extended(
                  onPressed: () => _showCreateSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Запись'),
                ),
        body:
            selectedProject == null
                ? const AppEmptyState(
                  icon: Icons.apartment_rounded,
                  title: 'Выберите проект',
                  description:
                      'Записи охраны труда ведутся в контексте конкретного проекта.',
                )
                : state.isLoading &&
                    state.permits.isEmpty &&
                    state.incidents.isEmpty &&
                    state.violations.isEmpty
                ? const AppLoadingState(message: 'Загружаем охрану труда')
                : state.error != null &&
                    state.permits.isEmpty &&
                    state.incidents.isEmpty &&
                    state.violations.isEmpty
                ? AppErrorState(
                  title:
                      state.permissionDenied
                          ? 'Нет доступа к охране труда'
                          : 'Не удалось загрузить охрану труда',
                  description: state.error,
                  onRetry: () => ref.read(safetyProvider.notifier).load(),
                )
                : RefreshIndicator(
                  onRefresh: () => ref.read(safetyProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _ProjectContextCard(
                        name: selectedProject.name,
                        address: selectedProject.address,
                      ),
                      const SizedBox(height: 12),
                      _SummaryStrip(state: state),
                      const SizedBox(height: 12),
                      _SafetyFilterBar(
                        state: state,
                        onPermitStatusChanged:
                            (status) => ref
                                .read(safetyProvider.notifier)
                                .setPermitStatusFilter(status),
                        onIncidentStatusChanged:
                            (status) => ref
                                .read(safetyProvider.notifier)
                                .setIncidentStatusFilter(status),
                        onViolationStatusChanged:
                            (status) => ref
                                .read(safetyProvider.notifier)
                                .setViolationStatusFilter(status),
                      ),
                      const SizedBox(height: 12),
                      _PermitsSection(
                        permits: state.permits,
                        onOpen: (permit) => _showPermitSheet(context, permit),
                      ),
                      const SizedBox(height: 12),
                      _IncidentsSection(incidents: state.incidents),
                      const SizedBox(height: 12),
                      _ViolationsSection(
                        violations: state.violations,
                        onResolve:
                            (violation) =>
                                _showResolveSheet(context, violation),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    if (selectedProject == null) {
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final immediateActionsController = TextEditingController();
    final correctiveActionController = TextEditingController();
    var mode = 'incident';
    String? severity;
    String? incidentType;
    DateTime? occurredAt;
    DateTime? dueDate;
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Новая запись охраны труда',
                          style: AppTypography.h2(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedProject.name,
                          style: AppTypography.caption(context),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'incident',
                              label: Text('Происшествие'),
                              icon: Icon(Icons.report_problem_outlined),
                            ),
                            ButtonSegment(
                              value: 'violation',
                              label: Text('Нарушение'),
                              icon: Icon(Icons.gpp_bad_outlined),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged:
                              (value) =>
                                  setSheetState(() => mode = value.first),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Название',
                          ),
                        ),
                        TextField(
                          controller: locationController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Локация',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          value: severity,
                          decoration: const InputDecoration(
                            labelText: 'Тяжесть',
                          ),
                          hint: const Text('Выберите тяжесть'),
                          items: const [
                            DropdownMenuItem(
                              value: 'minor',
                              child: Text('Низкая'),
                            ),
                            DropdownMenuItem(
                              value: 'major',
                              child: Text('Серьезная'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('Высокая'),
                            ),
                            DropdownMenuItem(
                              value: 'critical',
                              child: Text('Критичная'),
                            ),
                          ],
                          onChanged:
                              (value) => setSheetState(() {
                                if (value != null) {
                                  severity = value;
                                }
                              }),
                        ),
                        TextField(
                          controller: descriptionController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Описание',
                          ),
                        ),
                        if (mode == 'incident') ...[
                          DropdownButtonFormField<String>(
                            value: incidentType,
                            decoration: const InputDecoration(
                              labelText: 'Тип происшествия',
                            ),
                            hint: const Text('Выберите тип'),
                            items: const [
                              DropdownMenuItem(
                                value: 'unsafe_condition',
                                child: Text('Опасное условие'),
                              ),
                              DropdownMenuItem(
                                value: 'near_miss',
                                child: Text('Почти происшествие'),
                              ),
                              DropdownMenuItem(
                                value: 'injury',
                                child: Text('Травма'),
                              ),
                              DropdownMenuItem(
                                value: 'property_damage',
                                child: Text('Ущерб имуществу'),
                              ),
                              DropdownMenuItem(
                                value: 'environmental',
                                child: Text('Экология'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('Другое'),
                              ),
                            ],
                            onChanged:
                                (value) => setSheetState(() {
                                  if (value != null) {
                                    incidentType = value;
                                  }
                                }),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final selectedDate = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now(),
                                initialDate: occurredAt ?? DateTime.now(),
                              );
                              if (selectedDate == null || !context.mounted) {
                                return;
                              }

                              final selectedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                  occurredAt ?? DateTime.now(),
                                ),
                              );
                              if (selectedTime == null) {
                                return;
                              }

                              setSheetState(
                                () =>
                                    occurredAt = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      selectedTime.hour,
                                      selectedTime.minute,
                                    ),
                              );
                            },
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              occurredAt == null
                                  ? 'Когда произошло'
                                  : 'Когда: ${_formatDateTime(occurredAt!)}',
                            ),
                          ),
                          TextField(
                            controller: immediateActionsController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Немедленные меры',
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final selected = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDate: dueDate ?? DateTime.now(),
                              );

                              if (selected != null) {
                                setSheetState(() => dueDate = selected);
                              }
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              dueDate == null
                                  ? 'Срок устранения'
                                  : 'Срок: ${_formatDate(_apiDate(dueDate!))}',
                            ),
                          ),
                          TextField(
                            controller: correctiveActionController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Что нужно сделать',
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                submitting
                                    ? null
                                    : () async {
                                      final title = titleController.text.trim();
                                      if (title.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Укажите название'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (severity == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Выберите тяжесть'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (mode == 'incident' &&
                                          incidentType == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Выберите тип происшествия',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (mode == 'incident' &&
                                          occurredAt == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Укажите время происшествия',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      final selectedSeverity = severity!;
                                      final selectedIncidentType = incidentType;
                                      final selectedOccurredAt = occurredAt;

                                      setSheetState(() => submitting = true);
                                      try {
                                        final data = {
                                          'project_id':
                                              selectedProject.serverId,
                                          'title': title,
                                          'severity': selectedSeverity,
                                          if (locationController.text
                                              .trim()
                                              .isNotEmpty)
                                            'location_name':
                                                locationController.text.trim(),
                                          if (descriptionController.text
                                              .trim()
                                              .isNotEmpty)
                                            'description':
                                                descriptionController.text
                                                    .trim(),
                                        };

                                        if (mode == 'incident') {
                                          await ref
                                              .read(safetyProvider.notifier)
                                              .createIncident({
                                                ...data,
                                                'incident_type':
                                                    selectedIncidentType!,
                                                'occurred_at':
                                                    selectedOccurredAt!
                                                        .toIso8601String(),
                                                if (immediateActionsController
                                                    .text
                                                    .trim()
                                                    .isNotEmpty)
                                                  'immediate_actions':
                                                      immediateActionsController
                                                          .text
                                                          .trim(),
                                              });
                                        } else {
                                          await ref
                                              .read(safetyProvider.notifier)
                                              .createViolation({
                                                ...data,
                                                if (dueDate != null)
                                                  'due_date': _apiDate(
                                                    dueDate!,
                                                  ),
                                                if (correctiveActionController
                                                    .text
                                                    .trim()
                                                    .isNotEmpty)
                                                  'corrective_action':
                                                      correctiveActionController
                                                          .text
                                                          .trim(),
                                              });
                                        }

                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setSheetState(
                                            () => submitting = false,
                                          );
                                        }
                                      }
                                    },
                            child: Text(
                              submitting ? 'Сохранение...' : 'Сохранить',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _showPermitSheet(
    BuildContext context,
    SafetyWorkPermitModel permit,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Наряд-допуск', style: AppTypography.h2(sheetContext)),
                  const SizedBox(height: 6),
                  Text(
                    permit.title,
                    style: AppTypography.bodyLarge(sheetContext),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.badge_outlined,
                        label: permit.permitNumber,
                      ),
                      _InfoChip(
                        icon: Icons.verified_user_outlined,
                        label: permit.statusLabel,
                      ),
                      _InfoChip(
                        icon: Icons.shield_outlined,
                        label: _riskLabel(permit.riskLevel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PermitDetailLine(
                    label: 'Тип',
                    value: _permitTypeLabel(permit.permitType),
                  ),
                  if (permit.projectName != null)
                    _PermitDetailLine(
                      label: 'Проект',
                      value: permit.projectName!,
                    ),
                  if (permit.locationName != null)
                    _PermitDetailLine(
                      label: 'Локация',
                      value: permit.locationName!,
                    ),
                  _PermitDetailLine(
                    label: 'Начало',
                    value: _formatDate(permit.validFrom),
                  ),
                  _PermitDetailLine(
                    label: 'Окончание',
                    value: _formatDate(permit.validUntil),
                  ),
                  if (permit.requiredControls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Меры контроля',
                      style: AppTypography.caption(sheetContext),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          permit.requiredControls
                              .map(
                                (control) => Chip(
                                  avatar: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                  ),
                                  label: Text(control),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                    ),
                  ],
                  if (permit.approvalComment != null)
                    _PermitDetailLine(
                      label: 'Комментарий согласования',
                      value: permit.approvalComment!,
                    ),
                  if (permit.rejectionReason != null)
                    _PermitDetailLine(
                      label: 'Причина отклонения',
                      value: permit.rejectionReason!,
                    ),
                  if (permit.suspensionReason != null)
                    _PermitDetailLine(
                      label: 'Причина приостановки',
                      value: permit.suspensionReason!,
                    ),
                  if (permit.closeComment != null)
                    _PermitDetailLine(
                      label: 'Итог закрытия',
                      value: permit.closeComment!,
                    ),
                  _ProblemFlags(flags: permit.problemFlags),
                  if (permit.availableActions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Действия', style: AppTypography.h2(sheetContext)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          permit.availableActions
                              .map(
                                (action) => FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _executePermitAction(
                                      context,
                                      permit,
                                      action,
                                    );
                                  },
                                  icon: Icon(_permitActionIcon(action)),
                                  label: Text(_permitActionLabel(action)),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _executePermitAction(
    BuildContext context,
    SafetyWorkPermitModel permit,
    String action,
  ) async {
    if (action == 'approve' ||
        action == 'suspend' ||
        action == 'reject' ||
        action == 'close') {
      await _showPermitActionSheet(context, permit, action);
      return;
    }

    await _runPermitMutation(
      context,
      () => _performPermitAction(permit, action),
    );
  }

  Future<void> _showPermitActionSheet(
    BuildContext context,
    SafetyWorkPermitModel permit,
    String action,
  ) async {
    final controller = TextEditingController();
    final requiredText = action != 'approve';
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _permitActionTitle(action),
                          style: AppTypography.h2(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          permit.title,
                          style: AppTypography.bodyMedium(context),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: _permitActionInputLabel(action),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                submitting
                                    ? null
                                    : () async {
                                      final text = controller.text.trim();
                                      if (requiredText && text.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              _permitActionEmptyMessage(action),
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setSheetState(() => submitting = true);
                                      final completed =
                                          await _runPermitMutation(
                                            context,
                                            () => _performPermitAction(
                                              permit,
                                              action,
                                              text: text,
                                            ),
                                          );
                                      if (completed && sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                      if (context.mounted) {
                                        setSheetState(() => submitting = false);
                                      }
                                    },
                            icon: Icon(_permitActionIcon(action)),
                            label: Text(
                              submitting
                                  ? 'Сохранение...'
                                  : _permitActionLabel(action),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<bool> _runPermitMutation(
    BuildContext context,
    Future<void> Function() mutation,
  ) async {
    try {
      await mutation();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Действие выполнено')));
      }

      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }

      return false;
    }
  }

  Future<void> _performPermitAction(
    SafetyWorkPermitModel permit,
    String action, {
    String? text,
  }) {
    final notifier = ref.read(safetyProvider.notifier);

    return switch (action) {
      'submit' => notifier.submitPermit(permit.id),
      'approve' => notifier.approvePermit(
        permit.id,
        approvalComment: text == null || text.isEmpty ? null : text,
      ),
      'activate' => notifier.activatePermit(permit.id),
      'suspend' => notifier.suspendPermit(permit.id, reason: text ?? ''),
      'resume' => notifier.resumePermit(permit.id),
      'reject' => notifier.rejectPermit(permit.id, reason: text ?? ''),
      'close' => notifier.closePermit(permit.id, closeComment: text ?? ''),
      _ => Future<void>.error('Действие недоступно'),
    };
  }

  Future<void> _showResolveSheet(
    BuildContext context,
    SafetyViolationModel violation,
  ) async {
    final commentController = TextEditingController();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Устранить нарушение',
                          style: AppTypography.h2(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          violation.title,
                          style: AppTypography.bodyMedium(context),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: commentController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Что сделано',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                submitting
                                    ? null
                                    : () async {
                                      final comment =
                                          commentController.text.trim();
                                      if (comment.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Укажите результат устранения',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setSheetState(() => submitting = true);
                                      try {
                                        await ref
                                            .read(safetyProvider.notifier)
                                            .resolveViolation(
                                              violation.id,
                                              comment,
                                            );
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setSheetState(
                                            () => submitting = false,
                                          );
                                        }
                                      }
                                    },
                            child: Text(
                              submitting ? 'Сохранение...' : 'Сохранить',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.state});

  final SafetyState state;

  @override
  Widget build(BuildContext context) {
    final openIncidents =
        state.incidents.where((incident) => incident.status != 'closed').length;
    final openViolations =
        state.violations
            .where((violation) => violation.status == 'open')
            .length;
    final riskFlags = [
      ...state.permits.expand((permit) => permit.problemFlags),
      ...state.incidents.expand((incident) => incident.problemFlags),
      ...state.violations.expand((violation) => violation.problemFlags),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Допуски',
                value: state.permits.length.toString(),
                icon: Icons.assignment_turned_in_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'Происшествия',
                value: openIncidents.toString(),
                icon: Icons.report_problem_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'Нарушения',
                value: openViolations.toString(),
                icon: Icons.gpp_bad_outlined,
              ),
            ),
          ],
        ),
        if (riskFlags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _RiskBanner(flags: riskFlags),
        ],
      ],
    );
  }
}

class _ProjectContextCard extends StatelessWidget {
  const _ProjectContextCard({required this.name, this.address});

  final String name;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Row(
        children: [
          Icon(Icons.apartment_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodyLarge(context)),
                if (address != null && address!.trim().isNotEmpty)
                  Text(address!, style: AppTypography.caption(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyFilterBar extends StatelessWidget {
  const _SafetyFilterBar({
    required this.state,
    required this.onPermitStatusChanged,
    required this.onIncidentStatusChanged,
    required this.onViolationStatusChanged,
  });

  final SafetyState state;
  final ValueChanged<String?> onPermitStatusChanged;
  final ValueChanged<String?> onIncidentStatusChanged;
  final ValueChanged<String?> onViolationStatusChanged;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterGroup(
            title: 'Наряды-допуски',
            options: _permitStatusFilters,
            selectedValue: state.permitStatusFilter,
            onChanged: onPermitStatusChanged,
          ),
          const SizedBox(height: 12),
          _FilterGroup(
            title: 'Происшествия',
            options: _incidentStatusFilters,
            selectedValue: state.incidentStatusFilter,
            onChanged: onIncidentStatusChanged,
          ),
          const SizedBox(height: 12),
          _FilterGroup(
            title: 'Нарушения',
            options: _violationStatusFilters,
            selectedValue: state.violationStatusFilter,
            onChanged: onViolationStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final List<_SafetyFilterOption> options;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.caption(context)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option.label),
                      selected: selectedValue == option.value,
                      onSelected: (_) => onChanged(option.value),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}

class _RiskBanner extends StatelessWidget {
  const _RiskBanner({required this.flags});

  final List<SafetyProblemFlagModel> flags;

  @override
  Widget build(BuildContext context) {
    final criticalCount =
        flags.where((flag) => flag.severity == 'critical').length;

    return ProStatusBanner(
      title:
          criticalCount > 0
              ? 'Критичные риски: $criticalCount'
              : 'Есть предупреждения по охране труда',
      tone: criticalCount > 0 ? ProStatusTone.danger : ProStatusTone.warning,
    );
  }
}

class _PermitsSection extends StatelessWidget {
  const _PermitsSection({required this.permits, required this.onOpen});

  final List<SafetyWorkPermitModel> permits;
  final ValueChanged<SafetyWorkPermitModel> onOpen;

  @override
  Widget build(BuildContext context) {
    if (permits.isEmpty) {
      return const _EmptySection(
        title: 'Наряды-допуски',
        icon: Icons.assignment_turned_in_outlined,
        message: 'Нарядов-допусков нет',
      );
    }

    return _Section(
      title: 'Наряды-допуски',
      children:
          permits
              .map((permit) => _PermitCard(permit: permit, onOpen: onOpen))
              .toList(),
    );
  }
}

class _IncidentsSection extends StatelessWidget {
  const _IncidentsSection({required this.incidents});

  final List<SafetyIncidentModel> incidents;

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return const _EmptySection(
        title: 'Происшествия',
        icon: Icons.report_problem_outlined,
        message: 'Происшествий пока нет',
      );
    }

    return _Section(
      title: 'Происшествия',
      children:
          incidents
              .map((incident) => _IncidentCard(incident: incident))
              .toList(),
    );
  }
}

class _ViolationsSection extends StatelessWidget {
  const _ViolationsSection({required this.violations, required this.onResolve});

  final List<SafetyViolationModel> violations;
  final ValueChanged<SafetyViolationModel> onResolve;

  @override
  Widget build(BuildContext context) {
    if (violations.isEmpty) {
      return const _EmptySection(
        title: 'Нарушения',
        icon: Icons.gpp_bad_outlined,
        message: 'Нарушений пока нет',
      );
    }

    return _Section(
      title: 'Нарушения',
      children:
          violations
              .map(
                (violation) =>
                    _ViolationCard(violation: violation, onResolve: onResolve),
              )
              .toList(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h2(context)),
        const SizedBox(height: 8),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
        ),
      ],
    );
  }
}

class _PermitDetailLine extends StatelessWidget {
  const _PermitDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: AppTypography.caption(context)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium(context)),
          ),
        ],
      ),
    );
  }
}

class _PermitCard extends StatelessWidget {
  const _PermitCard({required this.permit, required this.onOpen});

  final SafetyWorkPermitModel permit;
  final ValueChanged<SafetyWorkPermitModel> onOpen;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: permit.title,
            label: permit.statusLabel,
            icon: Icons.assignment_turned_in_outlined,
          ),
          const SizedBox(height: 8),
          Text(permit.permitNumber, style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.shield_outlined,
                label: _riskLabel(permit.riskLevel),
              ),
              if (permit.projectName != null)
                _InfoChip(
                  icon: Icons.apartment_rounded,
                  label: permit.projectName!,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (permit.locationName != null)
            Text(
              permit.locationName!,
              style: AppTypography.bodyMedium(context),
            ),
          Text(
            'Действует до: ${_formatDate(permit.validUntil)}',
            style: AppTypography.bodyMedium(context),
          ),
          _ProblemFlags(flags: permit.problemFlags),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => onOpen(permit),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Подробнее'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final SafetyIncidentModel incident;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: incident.title,
            label: incident.statusLabel,
            icon: Icons.report_problem_outlined,
          ),
          const SizedBox(height: 8),
          Text(incident.incidentNumber, style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.speed_rounded,
                label: _severityLabel(incident.severity),
              ),
              if (incident.locationName != null)
                _InfoChip(
                  icon: Icons.place_outlined,
                  label: incident.locationName!,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Дата: ${_formatDate(incident.occurredAt)}',
            style: AppTypography.bodyMedium(context),
          ),
          if (incident.description != null)
            Text(
              incident.description!,
              style: AppTypography.bodyMedium(context),
            ),
          if (incident.immediateActions != null)
            Text(
              'Немедленные меры: ${incident.immediateActions!}',
              style: AppTypography.bodyMedium(context),
            ),
          _ProblemFlags(flags: incident.problemFlags),
        ],
      ),
    );
  }
}

class _ViolationCard extends StatelessWidget {
  const _ViolationCard({required this.violation, required this.onResolve});

  final SafetyViolationModel violation;
  final ValueChanged<SafetyViolationModel> onResolve;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: violation.title,
            label: violation.statusLabel,
            icon: Icons.gpp_bad_outlined,
          ),
          const SizedBox(height: 8),
          Text(
            violation.violationNumber,
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.speed_rounded,
                label: _severityLabel(violation.severity),
              ),
              if (violation.locationName != null)
                _InfoChip(
                  icon: Icons.place_outlined,
                  label: violation.locationName!,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (violation.dueDate != null)
            Text(
              'Срок: ${_formatDate(violation.dueDate!)}',
              style: AppTypography.bodyMedium(context),
            ),
          if (violation.description != null)
            Text(
              violation.description!,
              style: AppTypography.bodyMedium(context),
            ),
          if (violation.correctiveAction != null)
            Text(
              violation.correctiveAction!,
              style: AppTypography.bodyMedium(context),
            ),
          _ProblemFlags(flags: violation.problemFlags),
          if (violation.availableActions.contains('resolve')) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => onResolve(violation),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Устранить'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.label,
    required this.icon,
  });

  final String title;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Chip(label: Text(label), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ProblemFlags extends StatelessWidget {
  const _ProblemFlags({required this.flags});

  final List<SafetyProblemFlagModel> flags;

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            flags
                .map(
                  (flag) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          flag.severity == 'critical'
                              ? Icons.error_outline_rounded
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color:
                              flag.severity == 'critical'
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            flag.message,
                            style: AppTypography.bodyMedium(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ProMetricTile(label: label, value: value, icon: icon);
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h2(context)),
        const SizedBox(height: 8),
        AppEmptyState(icon: icon, title: message, minHeight: 180),
      ],
    );
  }
}

class _SafetyFilterOption {
  const _SafetyFilterOption(this.value, this.label);

  final String? value;
  final String label;
}

const _permitStatusFilters = [
  _SafetyFilterOption(null, 'Все'),
  _SafetyFilterOption('draft', 'Черновики'),
  _SafetyFilterOption('pending_approval', 'На согласовании'),
  _SafetyFilterOption('approved', 'Согласованные'),
  _SafetyFilterOption('active', 'Активные'),
  _SafetyFilterOption('suspended', 'Приостановленные'),
  _SafetyFilterOption('rejected', 'Отклоненные'),
  _SafetyFilterOption('closed', 'Закрытые'),
];

const _incidentStatusFilters = [
  _SafetyFilterOption(null, 'Все'),
  _SafetyFilterOption('reported', 'Зарегистрированы'),
  _SafetyFilterOption('triage', 'Разбор'),
  _SafetyFilterOption('investigation', 'Расследование'),
  _SafetyFilterOption('corrective_actions', 'Корректировка'),
  _SafetyFilterOption('closed', 'Закрытые'),
  _SafetyFilterOption('cancelled', 'Отмененные'),
];

const _violationStatusFilters = [
  _SafetyFilterOption(null, 'Все'),
  _SafetyFilterOption('open', 'Открытые'),
  _SafetyFilterOption('resolved', 'Устраненные'),
  _SafetyFilterOption('closed', 'Закрытые'),
];

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

String _apiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  final date = _formatDate(_apiDate(value));
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  return '$date $time';
}

String _severityLabel(String value) {
  return switch (value) {
    'minor' => 'Низкая',
    'major' => 'Серьезная',
    'high' => 'Высокая',
    'critical' => 'Критичная',
    _ => value,
  };
}

String _riskLabel(String value) {
  return switch (value) {
    'low' => 'Низкий риск',
    'medium' => 'Средний риск',
    'high' => 'Высокий риск',
    'critical' => 'Критичный риск',
    _ => value,
  };
}

String _permitTypeLabel(String value) {
  return switch (value) {
    'hot_work' => 'Огневые работы',
    'height_work' => 'Высотные работы',
    'confined_space' => 'Замкнутое пространство',
    'electrical' => 'Электромонтажные работы',
    'lifting' => 'Подъемные работы',
    _ => 'Другой тип работ',
  };
}

String _permitActionLabel(String value) {
  return switch (value) {
    'submit' => 'Отправить',
    'approve' => 'Согласовать',
    'reject' => 'Отклонить',
    'activate' => 'Активировать',
    'suspend' => 'Приостановить',
    'resume' => 'Возобновить',
    'close' => 'Закрыть',
    _ => 'Действие',
  };
}

IconData _permitActionIcon(String value) {
  return switch (value) {
    'submit' => Icons.send_rounded,
    'approve' => Icons.verified_rounded,
    'reject' => Icons.block_rounded,
    'activate' => Icons.play_arrow_rounded,
    'suspend' => Icons.pause_rounded,
    'resume' => Icons.restart_alt_rounded,
    'close' => Icons.done_all_rounded,
    _ => Icons.touch_app_rounded,
  };
}

String _permitActionTitle(String value) {
  return switch (value) {
    'approve' => 'Согласовать наряд-допуск',
    'reject' => 'Отклонить наряд-допуск',
    'suspend' => 'Приостановить наряд-допуск',
    'close' => 'Закрыть наряд-допуск',
    _ => _permitActionLabel(value),
  };
}

String _permitActionInputLabel(String value) {
  return switch (value) {
    'approve' => 'Комментарий',
    'reject' => 'Причина отклонения',
    'suspend' => 'Причина приостановки',
    'close' => 'Итог закрытия',
    _ => 'Комментарий',
  };
}

String _permitActionEmptyMessage(String value) {
  return switch (value) {
    'reject' => 'Укажите причину отклонения',
    'suspend' => 'Укажите причину приостановки',
    'close' => 'Укажите итог закрытия',
    _ => 'Заполните поле',
  };
}
