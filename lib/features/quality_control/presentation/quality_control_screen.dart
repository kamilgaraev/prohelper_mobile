import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/quality_defect_model.dart';
import '../domain/quality_control_provider.dart';

class QualityControlScreen extends ConsumerStatefulWidget {
  const QualityControlScreen({super.key});

  @override
  ConsumerState<QualityControlScreen> createState() =>
      _QualityControlScreenState();
}

class _QualityControlScreenState extends ConsumerState<QualityControlScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(qualityControlProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.loadDefects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(qualityControlProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(qualityControlProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        notifier.loadDefects();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Контроль качества'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  () => ref.read(qualityControlProvider.notifier).loadDefects(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed:
              selectedProject == null ? null : () => _showCreateSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Замечание'),
        ),
        body:
            state.isLoading && state.defects.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.defects.isEmpty
                ? AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить замечания',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed:
                        () =>
                            ref
                                .read(qualityControlProvider.notifier)
                                .loadDefects(),
                    child: const Text('Повторить'),
                  ),
                )
                : RefreshIndicator(
                  onRefresh:
                      () =>
                          ref
                              .read(qualityControlProvider.notifier)
                              .loadDefects(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _SummaryStrip(defects: state.defects),
                      const SizedBox(height: 12),
                      if (state.defects.isEmpty)
                        const AppStateView(
                          icon: Icons.fact_check_outlined,
                          title: 'Замечаний по качеству нет',
                          description:
                              'Создайте замечание, когда нужно зафиксировать дефект на объекте.',
                        )
                      else
                        ...state.defects.map(
                          (defect) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _QualityDefectCard(
                              defect: defect,
                              onStart:
                                  () => _submitAction(
                                    context,
                                    defect,
                                    _QualityAction.start,
                                  ),
                              onResolve:
                                  () => _submitAction(
                                    context,
                                    defect,
                                    _QualityAction.resolve,
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

  Future<void> _showCreateSheet(BuildContext context) async {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    if (selectedProject == null) {
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    var severity = 'major';
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
                          labelText: 'Название',
                        ),
                      ),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Локация'),
                      ),
                      DropdownButtonFormField<String>(
                        value: severity,
                        decoration: const InputDecoration(
                          labelText: 'Критичность',
                        ),
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
                            (value) => setSheetState(
                              () => severity = value ?? 'major',
                            ),
                      ),
                      TextField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            submitting
                                ? null
                                : () async {
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Укажите название замечания',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => submitting = true);
                                  try {
                                    await ref
                                        .read(qualityControlProvider.notifier)
                                        .createDefect({
                                          'project_id':
                                              selectedProject.serverId,
                                          'title': titleController.text.trim(),
                                          'severity': severity,
                                          if (descriptionController.text
                                              .trim()
                                              .isNotEmpty)
                                            'description':
                                                descriptionController.text
                                                    .trim(),
                                          if (locationController.text
                                              .trim()
                                              .isNotEmpty)
                                            'location_name':
                                                locationController.text.trim(),
                                          'inspection_required': true,
                                        });

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(() => submitting = false);
                                    }
                                  }
                                },
                        child: Text(submitting ? 'Создание...' : 'Создать'),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _submitAction(
    BuildContext context,
    QualityDefectModel defect,
    _QualityAction action,
  ) async {
    final commentController = TextEditingController();
    final photoController = TextEditingController();
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
                        action == _QualityAction.start
                            ? 'Взять в работу'
                            : 'Отправить на проверку',
                        style: AppTypography.h2(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        defect.title,
                        style: AppTypography.bodyMedium(context),
                      ),
                      TextField(
                        controller: commentController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий',
                        ),
                      ),
                      if (action == _QualityAction.resolve)
                        TextField(
                          controller: photoController,
                          decoration: const InputDecoration(
                            labelText: 'Ссылка на фото результата',
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            submitting
                                ? null
                                : () async {
                                  if (action == _QualityAction.resolve &&
                                      defect.inspectionRequired &&
                                      commentController.text.trim().isEmpty &&
                                      photoController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Добавьте комментарий или фото результата',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => submitting = true);
                                  try {
                                    if (action == _QualityAction.start) {
                                      await ref
                                          .read(qualityControlProvider.notifier)
                                          .startDefect(
                                            defect.id,
                                            comment: commentController.text,
                                          );
                                    } else {
                                      await ref
                                          .read(qualityControlProvider.notifier)
                                          .resolveDefect(
                                            defect.id,
                                            comment: commentController.text,
                                            photoUrl: photoController.text,
                                          );
                                    }

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
                          submitting ? 'Выполнение...' : 'Подтвердить',
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.defects});

  final List<QualityDefectModel> defects;

  @override
  Widget build(BuildContext context) {
    final open = defects.where((defect) => defect.status != 'resolved').length;
    final review =
        defects.where((defect) => defect.status == 'ready_for_review').length;
    final critical =
        defects.where((defect) => defect.severity == 'critical').length;

    return Row(
      children: [
        Expanded(child: _SummaryTile(label: 'Открыто', value: open.toString())),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(label: 'Проверка', value: review.toString()),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(label: 'Критично', value: critical.toString()),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(context)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.h2(context)),
        ],
      ),
    );
  }
}

class _QualityDefectCard extends StatelessWidget {
  const _QualityDefectCard({
    required this.defect,
    required this.onStart,
    required this.onResolve,
  });

  final QualityDefectModel defect;
  final VoidCallback onStart;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canStart = defect.availableActions.contains('start');
    final canResolve = defect.availableActions.contains('resolve');

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  defect.title,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusBadge(status: defect.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            defect.defectNumber,
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (defect.locationName?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              defect.locationName!,
              style: AppTypography.bodyMedium(context),
            ),
          ],
          if (defect.problemFlags.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...defect.problemFlags.map(
              (flag) => Text(
                flag.message,
                style: AppTypography.caption(
                  context,
                ).copyWith(color: AppColors.warning),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _SeverityPill(severity: defect.severity),
              const Spacer(),
              if (canStart)
                TextButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('В работу'),
                ),
              if (canResolve)
                FilledButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('На проверку'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'open' => 'Открыт',
      'assigned' => 'Назначен',
      'in_progress' => 'В работе',
      'ready_for_review' => 'Проверка',
      'resolved' => 'Закрыт',
      'rejected' => 'Отклонен',
      _ => status,
    };

    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final label = switch (severity) {
      'minor' => 'Низкая',
      'critical' => 'Критичная',
      _ => 'Средняя',
    };
    final color =
        severity == 'critical'
            ? AppColors.error
            : severity == 'major'
            ? AppColors.warning
            : Theme.of(context).colorScheme.primary;

    return Text(
      label,
      style: AppTypography.caption(
        context,
      ).copyWith(color: color, fontWeight: FontWeight.w800),
    );
  }
}

enum _QualityAction { start, resolve }
