import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/handover_acceptance_model.dart';
import '../domain/handover_acceptance_provider.dart';

class HandoverAcceptanceScreen extends ConsumerStatefulWidget {
  const HandoverAcceptanceScreen({super.key});

  @override
  ConsumerState<HandoverAcceptanceScreen> createState() =>
      _HandoverAcceptanceScreenState();
}

class _HandoverAcceptanceScreenState
    extends ConsumerState<HandoverAcceptanceScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(handoverAcceptanceProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.loadScopes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(handoverAcceptanceProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(handoverAcceptanceProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        notifier.loadScopes();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Приемка зон'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  () =>
                      ref
                          .read(handoverAcceptanceProvider.notifier)
                          .loadScopes(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body:
            state.isLoading && state.scopes.isEmpty
                ? const AppLoadingState(message: 'Загружаем зоны приемки')
                : state.error != null && state.scopes.isEmpty
                ? AppErrorState(
                  title: 'Не удалось загрузить приемку',
                  description: state.error,
                  onRetry:
                      () =>
                          ref
                              .read(handoverAcceptanceProvider.notifier)
                              .loadScopes(),
                )
                : RefreshIndicator(
                  onRefresh:
                      () =>
                          ref
                              .read(handoverAcceptanceProvider.notifier)
                              .loadScopes(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _SummaryStrip(scopes: state.scopes),
                      const SizedBox(height: 12),
                      if (state.scopes.isEmpty)
                        const AppEmptyState(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Зон приемки нет',
                          description:
                              'Когда зона будет готова к осмотру, она появится в этом списке.',
                        )
                      else
                        ...state.scopes.map(
                          (scope) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ScopeCard(
                              scope: scope,
                              onCreateFinding:
                                  () => _showFindingSheet(context, scope),
                              onResolveFinding:
                                  () => _resolveFirstFinding(context, scope),
                              onReadyForReinspection:
                                  () => _executeScopeAction(
                                    context,
                                    () => ref
                                        .read(
                                          handoverAcceptanceProvider.notifier,
                                        )
                                        .readyForReinspection(scope.id),
                                  ),
                              onStart:
                                  () => _executeScopeAction(
                                    context,
                                    () => ref
                                        .read(
                                          handoverAcceptanceProvider.notifier,
                                        )
                                        .startScope(scope.id),
                                  ),
                              onAccept: () => _showAcceptSheet(context, scope),
                              onHandover:
                                  () => _executeScopeAction(
                                    context,
                                    () => ref
                                        .read(
                                          handoverAcceptanceProvider.notifier,
                                        )
                                        .handoverScope(scope.id),
                                  ),
                              onReject:
                                  () => _showDecisionReasonSheet(
                                    context,
                                    scope,
                                    action: _HandoverScopeDecision.reject,
                                  ),
                              onReopen:
                                  () => _showDecisionReasonSheet(
                                    context,
                                    scope,
                                    action: _HandoverScopeDecision.reopen,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }

  Future<void> _showFindingSheet(
    BuildContext context,
    AcceptanceScopeModel scope,
  ) async {
    final session = scope.sessions.isEmpty ? null : scope.sessions.first;
    if (session == null) {
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String? severity;
    bool? createQualityDefect;
    bool? qualityDefectInspectionRequired;
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
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
                      Text('Новое замечание', style: AppTypography.h2(context)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Замечание',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
                        maxLines: 3,
                      ),
                      DropdownButtonFormField<String>(
                        value: severity,
                        decoration: const InputDecoration(
                          labelText: 'Критичность',
                        ),
                        hint: const Text('Выберите критичность'),
                        items: const [
                          DropdownMenuItem(
                            value: 'minor',
                            child: Text('Низкая'),
                          ),
                          DropdownMenuItem(
                            value: 'major',
                            child: Text('Средняя'),
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
                      DropdownButtonFormField<bool>(
                        value: createQualityDefect,
                        decoration: const InputDecoration(
                          labelText: 'Дефект качества',
                        ),
                        hint: const Text('Выберите действие'),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Создать')),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Не создавать'),
                          ),
                        ],
                        onChanged:
                            (value) => setSheetState(() {
                              createQualityDefect = value;
                              if (value != true) {
                                qualityDefectInspectionRequired = null;
                              }
                            }),
                      ),
                      if (createQualityDefect == true)
                        DropdownButtonFormField<bool>(
                          value: qualityDefectInspectionRequired,
                          decoration: const InputDecoration(
                            labelText: 'Проверка дефекта',
                          ),
                          hint: const Text('Выберите решение'),
                          items: const [
                            DropdownMenuItem(
                              value: true,
                              child: Text('Требуется'),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text('Не требуется'),
                            ),
                          ],
                          onChanged:
                              (value) => setSheetState(() {
                                qualityDefectInspectionRequired = value;
                              }),
                        ),
                      const SizedBox(height: 12),
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
                                          content: Text('Укажите замечание'),
                                        ),
                                      );
                                      return;
                                    }
                                    if (severity == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Выберите критичность'),
                                        ),
                                      );
                                      return;
                                    }
                                    if (createQualityDefect == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Укажите действие с дефектом качества',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (createQualityDefect == true &&
                                        qualityDefectInspectionRequired ==
                                            null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Укажите, нужна ли проверка дефекта качества',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final selectedSeverity = severity!;
                                    final shouldCreateQualityDefect =
                                        createQualityDefect!;
                                    final shouldInspectQualityDefect =
                                        shouldCreateQualityDefect
                                            ? qualityDefectInspectionRequired!
                                            : null;
                                    setSheetState(() => submitting = true);
                                    await ref
                                        .read(
                                          handoverAcceptanceProvider.notifier,
                                        )
                                        .createFinding(session.id, {
                                          'title': title,
                                          if (descriptionController.text
                                              .trim()
                                              .isNotEmpty)
                                            'description':
                                                descriptionController.text
                                                    .trim(),
                                          'severity': selectedSeverity,
                                          'create_quality_defect':
                                              shouldCreateQualityDefect,
                                          if (shouldCreateQualityDefect)
                                            'quality_defect_inspection_required':
                                                shouldInspectQualityDefect,
                                        });
                                    if (context.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                          child: const Text('Добавить'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _resolveFirstFinding(
    BuildContext context,
    AcceptanceScopeModel scope,
  ) async {
    AcceptanceFindingModel? finding;
    for (final item in scope.findings) {
      if (item.isOpen) {
        finding = item;
        break;
      }
    }

    if (finding == null) {
      return;
    }

    final openFinding = finding;
    final commentController = TextEditingController();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
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
                        'Подтвердить устранение',
                        style: AppTypography.h2(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        openFinding.title,
                        style: AppTypography.bodyMedium(context),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий об устранении',
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
                                          .read(
                                            handoverAcceptanceProvider.notifier,
                                          )
                                          .resolveFinding(
                                            openFinding.id,
                                            resolutionComment: comment,
                                          );
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setSheetState(() => submitting = false);
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
    );
  }

  Future<void> _showAcceptSheet(
    BuildContext context,
    AcceptanceScopeModel scope,
  ) async {
    final commentController = TextEditingController();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
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
                      Text('Принять зону', style: AppTypography.h2(context)),
                      const SizedBox(height: 8),
                      Text(
                        scope.title,
                        style: AppTypography.bodyMedium(context),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий',
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
                                    setSheetState(() => submitting = true);
                                    try {
                                      final comment =
                                          commentController.text.trim();
                                      await ref
                                          .read(
                                            handoverAcceptanceProvider.notifier,
                                          )
                                          .acceptScope(
                                            scope.id,
                                            comment:
                                                comment.isEmpty
                                                    ? null
                                                    : comment,
                                          );
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('$error')),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setSheetState(() => submitting = false);
                                      }
                                    }
                                  },
                          child: Text(submitting ? 'Сохранение...' : 'Принять'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _showDecisionReasonSheet(
    BuildContext context,
    AcceptanceScopeModel scope, {
    required _HandoverScopeDecision action,
  }) async {
    final reasonController = TextEditingController();
    var submitting = false;
    final title =
        action == _HandoverScopeDecision.reject
            ? 'Отклонить зону'
            : 'Вернуть зону';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
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
                      Text(title, style: AppTypography.h2(context)),
                      const SizedBox(height: 8),
                      Text(
                        scope.title,
                        style: AppTypography.bodyMedium(context),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: 'Причина'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              submitting
                                  ? null
                                  : () async {
                                    final reason = reasonController.text.trim();
                                    if (reason.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Укажите причину'),
                                        ),
                                      );
                                      return;
                                    }

                                    setSheetState(() => submitting = true);
                                    try {
                                      final notifier = ref.read(
                                        handoverAcceptanceProvider.notifier,
                                      );
                                      if (action ==
                                          _HandoverScopeDecision.reject) {
                                        await notifier.rejectScope(
                                          scope.id,
                                          reason: reason,
                                        );
                                      } else {
                                        await notifier.reopenScope(
                                          scope.id,
                                          reason: reason,
                                        );
                                      }
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('$error')),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setSheetState(() => submitting = false);
                                      }
                                    }
                                  },
                          child: Text(submitting ? 'Сохранение...' : title),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _executeScopeAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

enum _HandoverScopeDecision { reject, reopen }

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.scopes});

  final List<AcceptanceScopeModel> scopes;

  @override
  Widget build(BuildContext context) {
    final openFindings = scopes.fold<int>(
      0,
      (total, scope) => total + scope.openFindings,
    );
    final accepted =
        scopes
            .where(
              (scope) =>
                  scope.status == 'accepted' || scope.status == 'handed_over',
            )
            .length;

    return Row(
      children: [
        Expanded(child: _SummaryTile(label: 'Зоны', value: scopes.length)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Замечания', value: openFindings)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Принято', value: accepted)),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(context)),
          const SizedBox(height: 4),
          Text(value.toString(), style: AppTypography.h2(context)),
        ],
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.scope,
    required this.onCreateFinding,
    required this.onResolveFinding,
    required this.onReadyForReinspection,
    required this.onStart,
    required this.onAccept,
    required this.onHandover,
    required this.onReject,
    required this.onReopen,
  });

  final AcceptanceScopeModel scope;
  final VoidCallback onCreateFinding;
  final VoidCallback onResolveFinding;
  final VoidCallback onReadyForReinspection;
  final VoidCallback onStart;
  final VoidCallback onAccept;
  final VoidCallback onHandover;
  final VoidCallback onReject;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final package = scope.handoverPackage;
    final actions = scope.workflowSummary.availableActions.toSet();

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scope.title,
                  style: AppTypography.bodyLarge(context),
                ),
              ),
              _StatusChip(status: scope.status),
            ],
          ),
          if (scope.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(scope.locationLabel, style: AppTypography.bodySmall(context)),
          ],
          const SizedBox(height: 12),
          Text(
            'Открытые замечания: ${scope.openFindings}',
            style: AppTypography.bodyMedium(context),
          ),
          if (package != null)
            Text(
              'Документы: ${package.approvedRequiredDocuments}/${package.requiredDocuments}',
              style: AppTypography.bodyMedium(context),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (actions.contains('start'))
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Начать'),
                ),
              if (actions.contains('create_finding'))
                OutlinedButton.icon(
                  onPressed: onCreateFinding,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Замечание'),
                ),
              if (actions.contains('resolve_findings'))
                OutlinedButton.icon(
                  onPressed: scope.openFindings > 0 ? onResolveFinding : null,
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Устранено'),
                ),
              if (actions.contains('ready_for_reinspection'))
                FilledButton.icon(
                  onPressed:
                      scope.openFindings == 0 ? onReadyForReinspection : null,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('На проверку'),
                ),
              if (actions.contains('accept'))
                FilledButton.icon(
                  onPressed: scope.openFindings == 0 ? onAccept : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Принять'),
                ),
              if (actions.contains('handover'))
                FilledButton.icon(
                  onPressed: onHandover,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Передать'),
                ),
              if (actions.contains('reject'))
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Отклонить'),
                ),
              if (actions.contains('reopen'))
                OutlinedButton.icon(
                  onPressed: onReopen,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Вернуть'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' || 'handed_over' => AppColors.success,
      'findings_open' || 'reopened' => AppColors.warning,
      _ => AppColors.primary,
    };

    return Chip(
      label: Text(_statusLabel(status)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'planned' => 'Запланирована',
    'in_progress' => 'Осмотр',
    'findings_open' => 'Замечания',
    'ready_for_reinspection' => 'Проверка',
    'accepted' => 'Принята',
    'handed_over' => 'Передана',
    'reopened' => 'Повторно',
    'rejected' => 'Отклонена',
    _ => status,
  };
}
