import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../../core/widgets/pro_metric_tile.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/quality_defect_model.dart';
import '../data/quality_photo_picker.dart';
import '../domain/quality_control_provider.dart';

const int _qualityPhotoLimit = 3;

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
                ? const AppLoadingState(message: 'Загружаем замечания')
                : state.error != null && state.defects.isEmpty
                ? AppErrorState(
                  title:
                      state.permissionDenied
                          ? 'Нет доступа к контролю качества'
                          : 'Не удалось загрузить замечания',
                  description: state.error,
                  onRetry:
                      () =>
                          ref
                              .read(qualityControlProvider.notifier)
                              .loadDefects(),
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
                      _QualityFilterBar(
                        state: state,
                        onStatusChanged: _changeStatusFilter,
                        onSeverityChanged: _changeSeverityFilter,
                        onOverdueChanged: _changeOverdueFilter,
                      ),
                      const SizedBox(height: 12),
                      if (state.defects.isEmpty)
                        const AppEmptyState(
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
                              onOpen: () => _showDefectDetail(context, defect),
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
                              onVerify:
                                  () => _submitAction(
                                    context,
                                    defect,
                                    _QualityAction.verify,
                                  ),
                              onReject:
                                  () => _submitAction(
                                    context,
                                    defect,
                                    _QualityAction.reject,
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

  void _changeStatusFilter(String? status) {
    final notifier = ref.read(qualityControlProvider.notifier);
    notifier.setStatusFilter(status);
    notifier.loadDefects();
  }

  void _changeSeverityFilter(String? severity) {
    final notifier = ref.read(qualityControlProvider.notifier);
    notifier.setSeverityFilter(severity);
    notifier.loadDefects();
  }

  void _changeOverdueFilter(bool overdueOnly) {
    final notifier = ref.read(qualityControlProvider.notifier);
    notifier.setOverdueOnly(overdueOnly);
    notifier.loadDefects();
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    if (selectedProject == null) {
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    String? severity;
    bool? inspectionRequired;
    final beforePhotoPaths = <String>[];
    var submitting = false;
    var pickingPhoto = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => _QualitySheetFrame(
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Локация'),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<bool>(
                        value: inspectionRequired,
                        decoration: const InputDecoration(
                          labelText: 'Проверка результата',
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
                              inspectionRequired = value;
                            }),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed:
                            pickingPhoto ||
                                    beforePhotoPaths.length >=
                                        _qualityPhotoLimit
                                ? null
                                : () async {
                                  setSheetState(() => pickingPhoto = true);
                                  try {
                                    final path =
                                        await ref
                                            .read(qualityPhotoPickerProvider)
                                            .pickInitialPhoto();
                                    if (path != null && path.isNotEmpty) {
                                      setSheetState(() {
                                        if (!beforePhotoPaths.contains(path) &&
                                            beforePhotoPaths.length <
                                                _qualityPhotoLimit) {
                                          beforePhotoPaths.add(path);
                                        }
                                      });
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(() => pickingPhoto = false);
                                    }
                                  }
                                },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          _photoButtonLabel(
                            beforePhotoPaths.length,
                            empty: 'Добавить фото до исправления',
                            more: 'Добавить еще фото',
                            full: 'Добавлено 3 фото до исправления',
                          ),
                        ),
                      ),
                      if (beforePhotoPaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SelectedPhotoList(
                          paths: beforePhotoPaths,
                          onRemove:
                              (path) => setSheetState(
                                () => beforePhotoPaths.remove(path),
                              ),
                        ),
                      ],
                      const SizedBox(height: 20),
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
                                  if (severity == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Выберите критичность'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (inspectionRequired == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Укажите, нужна ли проверка результата',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final selectedSeverity = severity!;
                                  final selectedInspectionRequired =
                                      inspectionRequired!;

                                  setSheetState(() => submitting = true);
                                  try {
                                    await ref
                                        .read(qualityControlProvider.notifier)
                                        .createDefect(
                                          {
                                            'project_id':
                                                selectedProject.serverId,
                                            'title':
                                                titleController.text.trim(),
                                            'severity': selectedSeverity,
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
                                                  locationController.text
                                                      .trim(),
                                            'inspection_required':
                                                selectedInspectionRequired,
                                          },
                                          photoPaths: List<String>.from(
                                            beforePhotoPaths,
                                          ),
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
                        child: Text(submitting ? 'Создание...' : 'Создать'),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _showDefectDetail(
    BuildContext context,
    QualityDefectModel defect,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => FutureBuilder<QualityDefectModel>(
            future: ref
                .read(qualityControlProvider.notifier)
                .fetchDefect(defect.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _QualitySheetFrame(
                  child: AppLoadingState(
                    message: 'Загружаем замечание',
                    minHeight: 260,
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _QualitySheetFrame(
                  child: AppErrorState(
                    title: 'Не удалось загрузить замечание',
                    description: snapshot.error?.toString(),
                    minHeight: 260,
                  ),
                );
              }

              final detail = snapshot.data!;

              return _QualitySheetFrame(
                child: _QualityDefectDetail(defect: detail),
              );
            },
          ),
    );
  }

  Future<void> _submitAction(
    BuildContext context,
    QualityDefectModel defect,
    _QualityAction action,
  ) async {
    final commentController = TextEditingController();
    final resultPhotoPaths = <String>[];
    var submitting = false;
    var pickingPhoto = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => _QualitySheetFrame(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _qualityActionTitle(action),
                        style: AppTypography.h2(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        defect.title,
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
                      if (action == _QualityAction.resolve)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton.icon(
                            onPressed:
                                pickingPhoto ||
                                        resultPhotoPaths.length >=
                                            _qualityPhotoLimit
                                    ? null
                                    : () async {
                                      setSheetState(() => pickingPhoto = true);
                                      try {
                                        final path =
                                            await ref
                                                .read(
                                                  qualityPhotoPickerProvider,
                                                )
                                                .pickResultPhoto();
                                        if (path != null && path.isNotEmpty) {
                                          setSheetState(() {
                                            if (!resultPhotoPaths.contains(
                                                  path,
                                                ) &&
                                                resultPhotoPaths.length <
                                                    _qualityPhotoLimit) {
                                              resultPhotoPaths.add(path);
                                            }
                                          });
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setSheetState(
                                            () => pickingPhoto = false,
                                          );
                                        }
                                      }
                                    },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(
                              _photoButtonLabel(
                                resultPhotoPaths.length,
                                empty: 'Сделать фото результата',
                                more: 'Добавить еще фото результата',
                                full: 'Добавлено 3 фото результата',
                              ),
                            ),
                          ),
                        ),
                      if (resultPhotoPaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SelectedPhotoList(
                          paths: resultPhotoPaths,
                          onRemove:
                              (path) => setSheetState(
                                () => resultPhotoPaths.remove(path),
                              ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed:
                            submitting
                                ? null
                                : () async {
                                  final comment = commentController.text.trim();
                                  if (action == _QualityAction.reject &&
                                      comment.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Укажите причину возврата',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (action == _QualityAction.resolve &&
                                      defect.inspectionRequired &&
                                      comment.isEmpty &&
                                      resultPhotoPaths.isEmpty) {
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
                                    final notifier = ref.read(
                                      qualityControlProvider.notifier,
                                    );
                                    switch (action) {
                                      case _QualityAction.start:
                                        await notifier.startDefect(
                                          defect.id,
                                          comment: comment,
                                        );
                                      case _QualityAction.resolve:
                                        await notifier.resolveDefect(
                                          defect.id,
                                          comment: comment,
                                          photoPaths: List<String>.from(
                                            resultPhotoPaths,
                                          ),
                                        );
                                      case _QualityAction.verify:
                                        await notifier.verifyDefect(
                                          defect.id,
                                          comment: comment,
                                        );
                                      case _QualityAction.reject:
                                        await notifier.rejectDefect(
                                          defect.id,
                                          comment: comment,
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
                          submitting
                              ? 'Выполнение...'
                              : _qualityActionButton(action),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}

class _QualitySheetFrame extends StatelessWidget {
  const _QualitySheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.viewInsets.bottom -
        media.padding.top -
        media.padding.bottom -
        32;
    final sheetCap = media.size.height * 0.82;
    final minHeight = sheetCap < 260 ? sheetCap : 260.0;
    final maxHeight = availableHeight.clamp(minHeight, sheetCap).toDouble();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: media.viewInsets.bottom + 20,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SelectedPhotoList extends StatelessWidget {
  const _SelectedPhotoList({required this.paths, required this.onRemove});

  final List<String> paths;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: paths
          .map(
            (path) => InputChip(
              avatar: const Icon(Icons.image_outlined, size: 18),
              label: Text(
                _photoFileName(path),
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: () => onRemove(path),
            ),
          )
          .toList(growable: false),
    );
  }
}

String _photoButtonLabel(
  int count, {
  required String empty,
  required String more,
  required String full,
}) {
  if (count <= 0) {
    return empty;
  }

  if (count >= _qualityPhotoLimit) {
    return full;
  }

  return '$more ($count/$_qualityPhotoLimit)';
}

String _photoFileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');

  return parts.isEmpty ? path : parts.last;
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
        Expanded(
          child: _SummaryTile(
            label: 'Открыто',
            value: open.toString(),
            icon: Icons.fact_check_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'Проверка',
            value: review.toString(),
            icon: Icons.rule_folder_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'Критично',
            value: critical.toString(),
            icon: Icons.priority_high_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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

class _QualityFilterBar extends StatelessWidget {
  const _QualityFilterBar({
    required this.state,
    required this.onStatusChanged,
    required this.onSeverityChanged,
    required this.onOverdueChanged,
  });

  final QualityControlState state;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onSeverityChanged;
  final ValueChanged<bool> onOverdueChanged;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Статус', style: AppTypography.caption(context)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _qualityStatusFilters
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option.label),
                        selected: state.statusFilter == option.value,
                        onSelected: (_) => onStatusChanged(option.value),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 12),
          Text('Критичность', style: AppTypography.caption(context)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._qualitySeverityFilters.map(
                (option) => ChoiceChip(
                  label: Text(option.label),
                  selected: state.severityFilter == option.value,
                  onSelected: (_) => onSeverityChanged(option.value),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              FilterChip(
                label: const Text('Просроченные'),
                selected: state.overdueOnly,
                onSelected: onOverdueChanged,
                avatar: const Icon(Icons.event_busy_rounded, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityDefectDetail extends StatelessWidget {
  const _QualityDefectDetail({required this.defect});

  final QualityDefectModel defect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Замечание качества', style: AppTypography.h2(context)),
        const SizedBox(height: 6),
        Text(defect.title, style: AppTypography.bodyLarge(context)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusBadge(status: defect.status, label: defect.statusLabel),
            _InfoChip(
              icon: Icons.confirmation_number_outlined,
              label: defect.defectNumber,
            ),
            _InfoChip(
              icon: Icons.fact_check_outlined,
              label:
                  defect.inspectionRequired
                      ? 'Проверка требуется'
                      : 'Проверка не требуется',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _QualityDetailLine(label: 'Критичность', value: _severityText(defect)),
        if (defect.projectName.isNotEmpty)
          _QualityDetailLine(label: 'Проект', value: defect.projectName),
        if (defect.assignedUserName.isNotEmpty)
          _QualityDetailLine(
            label: 'Ответственный',
            value: defect.assignedUserName,
          ),
        if (defect.locationName?.isNotEmpty == true)
          _QualityDetailLine(label: 'Локация', value: defect.locationName!),
        if (defect.dueDate?.isNotEmpty == true)
          _QualityDetailLine(
            label: 'Срок',
            value: _formatQualityDate(defect.dueDate!),
          ),
        if (defect.description?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text('Описание', style: AppTypography.caption(context)),
          const SizedBox(height: 4),
          Text(defect.description!, style: AppTypography.bodyMedium(context)),
        ],
        if (defect.photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Фото', style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          ...defect.photos.map((photo) => _QualityPhotoRow(photo: photo)),
        ],
        if (defect.statusHistory.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('История', style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          ...defect.statusHistory.map(
            (entry) => _QualityHistoryRow(entry: entry),
          ),
        ],
      ],
    );
  }
}

class _QualityDetailLine extends StatelessWidget {
  const _QualityDetailLine({required this.label, required this.value});

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
            width: 120,
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

class _QualityPhotoRow extends StatelessWidget {
  const _QualityPhotoRow({required this.photo});

  final QualityDefectPhotoModel photo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayUrl = photo.displayUrl;
    final canPreview = _isNetworkUrl(displayUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.36),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPreview)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                displayUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder:
                    (context, error, stackTrace) =>
                        const _PhotoPreviewFallback(),
              ),
            )
          else
            const _PhotoPreviewFallback(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.photo_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    photo.caption ?? _photoTypeLabel(photo.type),
                    style: AppTypography.bodyMedium(context),
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

class _PhotoPreviewFallback extends StatelessWidget {
  const _PhotoPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, size: 32),
          const SizedBox(height: 8),
          Text('Фото недоступно', style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _QualityHistoryRow extends StatelessWidget {
  const _QualityHistoryRow({required this.entry});

  final QualityDefectHistoryModel entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _qualityStatusLabel(entry.toStatus),
                  style: AppTypography.bodyMedium(context),
                ),
                if (entry.comment != null)
                  Text(entry.comment!, style: AppTypography.caption(context)),
                if (entry.changedAt != null)
                  Text(
                    _formatQualityDate(entry.changedAt!),
                    style: AppTypography.caption(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityDefectCard extends StatelessWidget {
  const _QualityDefectCard({
    required this.defect,
    required this.onOpen,
    required this.onStart,
    required this.onResolve,
    required this.onVerify,
    required this.onReject,
  });

  final QualityDefectModel defect;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onResolve;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canStart = defect.availableActions.contains('start');
    final canResolve = defect.availableActions.contains('resolve');
    final canVerify = defect.availableActions.contains('verify');
    final canReject = defect.availableActions.contains('reject');

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
              _StatusBadge(status: defect.status, label: defect.statusLabel),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SeverityPill(
                severity: defect.severity,
                label: defect.severityLabel,
              ),
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Подробнее'),
              ),
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
              if (canVerify)
                FilledButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Подтвердить'),
                ),
              if (canReject)
                OutlinedButton.icon(
                  onPressed: onReject,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final visibleLabel =
        label ??
        switch (status) {
          'open' => 'Открыт',
          'assigned' => 'Назначен',
          'in_progress' => 'В работе',
          'ready_for_review' => 'Проверка',
          'resolved' => 'Закрыт',
          'rejected' => 'Отклонен',
          'cancelled' => 'Отменен',
          _ => throw ArgumentError.value(status, 'status'),
        };

    return Chip(
      label: Text(visibleLabel),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.severity, this.label});

  final String severity;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final visibleLabel =
        label ??
        switch (severity) {
          'minor' => 'Низкая',
          'critical' => 'Критичная',
          'major' => 'Средняя',
          _ => throw ArgumentError.value(severity, 'severity'),
        };
    final color =
        severity == 'critical'
            ? AppColors.error
            : severity == 'major'
            ? AppColors.warning
            : Theme.of(context).colorScheme.primary;

    return Text(
      visibleLabel,
      style: AppTypography.caption(
        context,
      ).copyWith(color: color, fontWeight: FontWeight.w800),
    );
  }
}

String _severityText(QualityDefectModel defect) {
  return defect.severityLabel ??
      switch (defect.severity) {
        'minor' => 'Низкая',
        'major' => 'Средняя',
        'critical' => 'Критичная',
        _ => throw ArgumentError.value(defect.severity, 'severity'),
      };
}

String _qualityStatusLabel(String status) {
  return switch (status) {
    'draft' => 'Черновик',
    'open' => 'Открыт',
    'assigned' => 'Назначен',
    'in_progress' => 'В работе',
    'ready_for_review' => 'На проверке',
    'resolved' => 'Устранен',
    'rejected' => 'Возвращен',
    'cancelled' => 'Отменен',
    _ => throw ArgumentError.value(status, 'status'),
  };
}

String _photoTypeLabel(String type) {
  return switch (type) {
    'before' => 'До устранения',
    'after' => 'После устранения',
    'evidence' => 'Подтверждение',
    'other' => 'Фото',
    _ => throw ArgumentError.value(type, 'type'),
  };
}

String _formatQualityDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

bool _isNetworkUrl(String value) {
  final uri = Uri.tryParse(value);

  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

String _qualityActionTitle(_QualityAction action) {
  return switch (action) {
    _QualityAction.start => 'Взять в работу',
    _QualityAction.resolve => 'Отправить на проверку',
    _QualityAction.verify => 'Подтвердить результат',
    _QualityAction.reject => 'Вернуть на доработку',
  };
}

String _qualityActionButton(_QualityAction action) {
  return switch (action) {
    _QualityAction.start => 'Взять в работу',
    _QualityAction.resolve => 'Отправить',
    _QualityAction.verify => 'Подтвердить',
    _QualityAction.reject => 'Вернуть',
  };
}

enum _QualityAction { start, resolve, verify, reject }

class _QualityFilterOption {
  const _QualityFilterOption(this.value, this.label);

  final String? value;
  final String label;
}

const _qualityStatusFilters = [
  _QualityFilterOption(null, 'Все'),
  _QualityFilterOption('open', 'Открытые'),
  _QualityFilterOption('assigned', 'Назначенные'),
  _QualityFilterOption('in_progress', 'В работе'),
  _QualityFilterOption('ready_for_review', 'Проверка'),
  _QualityFilterOption('resolved', 'Закрытые'),
  _QualityFilterOption('rejected', 'Возвращенные'),
  _QualityFilterOption('cancelled', 'Отмененные'),
];

const _qualitySeverityFilters = [
  _QualityFilterOption(null, 'Все'),
  _QualityFilterOption('minor', 'Низкая'),
  _QualityFilterOption('major', 'Средняя'),
  _QualityFilterOption('critical', 'Критичная'),
];
