import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/design/pro_status.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../../core/widgets/pro_status_banner.dart';
import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';
import '../domain/construction_journal_provider.dart';
import '../../projects/domain/projects_provider.dart';
import 'journal_entry_form_screen.dart';

class JournalEntryDetailScreen extends ConsumerStatefulWidget {
  const JournalEntryDetailScreen({
    super.key,
    required this.journalId,
    required this.entryId,
    this.projectId,
  });

  final int journalId;
  final int entryId;
  final int? projectId;

  @override
  ConsumerState<JournalEntryDetailScreen> createState() =>
      _JournalEntryDetailScreenState();
}

class _JournalEntryDetailScreenState
    extends ConsumerState<JournalEntryDetailScreen> {
  String? _activeAction;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final journalId = widget.journalId;
    final entryId = widget.entryId;
    final projectId = widget.projectId;
    final scope = (
      entryId: entryId,
      projectId:
          projectId ?? ref.watch(projectsProvider).selectedProject?.serverId,
    );
    final state = ref.watch(constructionJournalEntryDetailProvider(scope));
    final notifier = ref.read(
      constructionJournalEntryDetailProvider(scope).notifier,
    );

    if (state.isLoading && state.entry == null) {
      return const Scaffold(
        body: AppLoadingState(message: 'Загружаем запись журнала'),
      );
    }

    if (state.error != null && state.entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Запись журнала')),
        body: AppErrorState(
          title: 'Не удалось загрузить запись',
          description: state.error,
          onRetry: notifier.load,
        ),
      );
    }

    if (state.entry == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.event_note_outlined,
          title: 'Запись не найдена',
        ),
      );
    }

    final entry = state.entry!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Запись №${entry.entryNumber}'),
        actions: [
          IconButton(
            onPressed: notifier.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.fromCache || state.hasDirtyLocal)
              ProStatusBanner(
                title:
                    state.hasDirtyLocal
                        ? 'Есть локальные изменения'
                        : 'Показаны сохранённые данные',
                description:
                    state.error ?? 'Актуальность данных не подтверждена сетью.',
                tone:
                    state.hasDirtyLocal
                        ? ProStatusTone.warning
                        : ProStatusTone.info,
                fullText: true,
              ),
            if (state.fromCache || state.hasDirtyLocal)
              const SizedBox(height: 12),
            IndustrialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Запись №${entry.entryNumber}',
                              style: AppTypography.h2(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(entry.entryDate),
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(
                        status: entry.status,
                        label: entry.statusLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry.workDescription,
                    style: AppTypography.bodyMedium(context),
                  ),
                  if ((entry.problemsDescription ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Проблемы',
                      value: entry.problemsDescription!,
                    ),
                  ],
                  if ((entry.safetyNotes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(title: 'Безопасность', value: entry.safetyNotes!),
                  ],
                  if ((entry.visitorsNotes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Замечания посетителей',
                      value: entry.visitorsNotes!,
                    ),
                  ],
                  if ((entry.qualityNotes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(title: 'Качество', value: entry.qualityNotes!),
                  ],
                  if ((entry.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Причина отклонения',
                      value: entry.rejectionReason!,
                      color: AppColors.error,
                    ),
                  ],
                ],
              ),
            ),
            if (entry.blockers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _BlockersCard(blockers: entry.blockers),
            ],
            if (entry.completedWorks.isNotEmpty) ...[
              const SizedBox(height: 16),
              _FieldResourcesCard(
                title: 'Связанные работы',
                lines:
                    entry.completedWorks
                        .map((work) => work.displayLabel)
                        .toList(),
              ),
            ],
            const SizedBox(height: 16),
            _WorkVolumesReadOnlyCard(volumes: entry.workVolumes),
            if (entry.weatherConditions != null) ...[
              const SizedBox(height: 16),
              _FieldResourcesCard(
                title: 'Погодные условия',
                lines: [
                  if (entry.weatherConditions!.temperature != null)
                    'Температура: ${entry.weatherConditions!.temperature} °C',
                  if (entry.weatherConditions!.windSpeed != null)
                    'Ветер: ${entry.weatherConditions!.windSpeed} м/с',
                  if ((entry.weatherConditions!.precipitation ?? '').isNotEmpty)
                    'Погода: ${entry.weatherConditions!.precipitation}',
                ],
              ),
            ],
            if (entry.workers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _FieldResourcesCard(
                title: 'Работники',
                lines:
                    entry.workers
                        .map(
                          (worker) =>
                              '${worker.specialty}: ${worker.workersCount} чел.${worker.hoursWorked == null ? '' : ', ${worker.hoursWorked} ч'}',
                        )
                        .toList(),
              ),
            ],
            if (entry.equipment.isNotEmpty) ...[
              const SizedBox(height: 16),
              _FieldResourcesCard(
                title: 'Техника',
                lines:
                    entry.equipment
                        .map(
                          (item) =>
                              '${item.name}: ${item.quantity} ед.${item.hoursUsed == null ? '' : ', ${item.hoursUsed} моточ.'}',
                        )
                        .toList(),
              ),
            ],
            if (entry.materials.isNotEmpty) ...[
              const SizedBox(height: 16),
              _FieldResourcesCard(
                title: 'Материалы',
                lines:
                    entry.materials
                        .map(
                          (material) =>
                              '${material.materialName}: ${material.quantity} ${material.measurementUnit}',
                        )
                        .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.hasAction(ConstructionJournalActionKeys.update))
                  OutlinedButton.icon(
                    onPressed:
                        _activeAction == null
                            ? () async {
                              final updated = await navigator.push<bool>(
                                MaterialPageRoute(
                                  builder:
                                      (_) => JournalEntryFormScreen(
                                        journalId: journalId,
                                        initialEntry: entry,
                                      ),
                                ),
                              );
                              if (updated == true && mounted) {
                                await notifier.load();
                              }
                            }
                            : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Редактировать'),
                  ),
                if (entry.hasAction(ConstructionJournalActionKeys.submit))
                  ElevatedButton.icon(
                    onPressed:
                        _activeAction == null
                            ? () async => _runAction('submit', () async {
                              await ref
                                  .read(constructionJournalRepositoryProvider)
                                  .submitEntry(entryId);
                              await notifier.load();
                            })
                            : null,
                    icon: _actionIcon('submit', Icons.send_outlined),
                    label: Text(_actionLabel('submit', 'Отправить')),
                  ),
                if (entry.hasAction(ConstructionJournalActionKeys.approve))
                  ElevatedButton.icon(
                    onPressed:
                        _activeAction == null
                            ? () async => _runAction('approve', () async {
                              await ref
                                  .read(constructionJournalRepositoryProvider)
                                  .approveEntry(entryId);
                              await notifier.load();
                            })
                            : null,
                    icon: _actionIcon(
                      'approve',
                      Icons.check_circle_outline_rounded,
                    ),
                    label: Text(_actionLabel('approve', 'Утвердить')),
                  ),
                if (entry.hasAction(ConstructionJournalActionKeys.reject))
                  OutlinedButton.icon(
                    onPressed:
                        _activeAction == null
                            ? () => _showRejectDialog(
                              context,
                              onReject:
                                  (reason) => _runAction('reject', () async {
                                    await ref
                                        .read(
                                          constructionJournalRepositoryProvider,
                                        )
                                        .rejectEntry(entryId, reason);
                                    await notifier.load();
                                  }),
                            )
                            : null,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отклонить'),
                  ),
                if (entry.hasAction(ConstructionJournalActionKeys.delete))
                  OutlinedButton.icon(
                    onPressed:
                        _activeAction == null
                            ? () async => _runAction('delete', () async {
                              await ref
                                  .read(constructionJournalRepositoryProvider)
                                  .deleteEntry(entryId);
                              if (mounted) navigator.pop(true);
                            })
                            : null,
                    icon: _actionIcon('delete', Icons.delete_outline_rounded),
                    label: Text(_actionLabel('delete', 'Удалить')),
                  ),
                if (entry.hasAction(
                  ConstructionJournalActionKeys.exportDailyReport,
                ))
                  OutlinedButton.icon(
                    onPressed:
                        _activeAction == null
                            ? () async => _runAction('export', () async {
                              final url = await ref
                                  .read(constructionJournalRepositoryProvider)
                                  .exportDailyReport(entryId);
                              await Clipboard.setData(ClipboardData(text: url));
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ссылка на дневной отчет скопирована в буфер.',
                                    ),
                                  ),
                                );
                              }
                            })
                            : null,
                    icon: _actionIcon('export', Icons.download_outlined),
                    label: Text(_actionLabel('export', 'Дневной отчет')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _runAction(
    String action,
    Future<void> Function() perform,
  ) async {
    if (_activeAction != null) return false;
    setState(() => _activeAction = action);
    try {
      await perform();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Widget _actionIcon(String action, IconData icon) =>
      _activeAction == action
          ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
          : Icon(icon);

  String _actionLabel(String action, String label) =>
      _activeAction == action ? 'Выполняется…' : label;
}

class _FieldResourcesCard extends StatelessWidget {
  const _FieldResourcesCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: AppTypography.bodyMedium(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockersCard extends StatelessWidget {
  const _BlockersCard({required this.blockers});

  final List<ConstructionJournalBlockerModel> blockers;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Запись пока нельзя утвердить',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...blockers.map(
            (blocker) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                blocker.message,
                style: AppTypography.bodyMedium(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkVolumesReadOnlyCard extends StatelessWidget {
  const _WorkVolumesReadOnlyCard({required this.volumes});

  final List<ConstructionJournalWorkVolumeModel> volumes;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Объемы выполненных работ',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (volumes.isEmpty)
            Text('Список работ пуст', style: AppTypography.bodyMedium(context))
          else
            ...volumes.map(
              (volume) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      volume.title!,
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${volume.quantity} ${volume.measurementUnitName}',
                      style: AppTypography.caption(context),
                    ),
                    if ((volume.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        volume.notes!,
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.value, this.color});

  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.caption(
            context,
          ).copyWith(color: resolvedColor, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.bodyMedium(
            context,
          ).copyWith(color: resolvedColor),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColors.success,
      'submitted' => AppColors.warning,
      'rejected' => AppColors.error,
      'draft' => Theme.of(context).colorScheme.primary,
      _ =>
        throw StateError('Unknown construction journal entry status: $status'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Future<void> _showRejectDialog(
  BuildContext context, {
  required Future<bool> Function(String) onReject,
}) async {
  final controller = TextEditingController();
  var submitting = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Отклонить запись'),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Причина отклонения',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed:
                    submitting
                        ? null
                        : () async {
                          setDialogState(() => submitting = true);
                          final succeeded = await onReject(
                            controller.text.trim(),
                          );
                          if (succeeded && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          } else if (dialogContext.mounted) {
                            setDialogState(() => submitting = false);
                          }
                        },
                child: Text(submitting ? 'Выполняется…' : 'Отклонить'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
