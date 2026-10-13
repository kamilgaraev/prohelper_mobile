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
import '../../auth/domain/auth_provider.dart';
import '../../design_management/data/design_package_file_service.dart';
import '../data/journal_photo_picker.dart';
import 'journal_entry_form_screen.dart';
import 'include_journal_entry_dialog.dart';
import 'journal_contract_assignment_dialog.dart';

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
  int? _projectId;
  Object? _boundActor;

  @override
  void initState() {
    super.initState();
    _projectId =
        widget.projectId ??
        ref.read(projectsProvider).selectedProject?.serverId;
    _boundActor = _actorContext;
  }

  Object get _actorContext {
    final auth = ref.read(authProvider);
    return (
      user: auth.user?.serverId,
      organization: auth.user?.currentOrganizationId,
      session: auth is AuthAuthenticated ? auth.sessionIdentity : null,
    );
  }

  bool _attachmentContextCurrent(Object actor) =>
      _isProjectCurrent && actor == _actorContext && actor == _boundActor;

  bool get _isProjectCurrent =>
      mounted &&
      _projectId != null &&
      ref.read(projectsProvider).selectedProject?.serverId == _projectId;

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(
      projectsProvider.select((state) => state.selectedProject?.serverId),
      (previous, next) {
        if (widget.projectId == null && _projectId == null && next != null) {
          setState(() => _projectId = next);
        }
      },
    );
    final navigator = Navigator.of(context);
    ref.watch(authProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final journalId = widget.journalId;
    final entryId = widget.entryId;
    final selectedProjectId = ref.watch(
      projectsProvider.select((state) => state.selectedProject?.serverId),
    );
    final projectId = _projectId;
    final projectMatches = projectId != null && selectedProjectId == projectId;
    final scope = (entryId: entryId, projectId: projectId);
    final state = ref.watch(constructionJournalEntryDetailProvider(scope));
    final notifier = ref.read(
      constructionJournalEntryDetailProvider(scope).notifier,
    );

    if (!projectMatches) {
      return Scaffold(
        appBar: AppBar(title: const Text('Запись журнала')),
        body: const AppEmptyState(
          icon: Icons.apartment_outlined,
          title: 'Выбран другой объект',
          description: 'Откройте запись из журнала выбранного объекта.',
        ),
      );
    }

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
    final attachmentsContextCurrent = _attachmentContextCurrent(_boundActor!);
    if (entry.id != entryId || entry.journalId != journalId) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.event_note_outlined,
          title: 'Запись не найдена',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Запись №${entry.entryNumber}'),
        actions: [
          IconButton(
            onPressed: _isProjectCurrent ? notifier.load : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isProjectCurrent) await notifier.load();
        },
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeader =
                      constraints.maxWidth < 400 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.15;
                  final titleAndDate = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Запись №${entry.entryNumber}',
                        key: const ValueKey('journal-entry-card-title'),
                        maxLines: 1,
                        softWrap: false,
                        style: AppTypography.h2(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(entry.entryDate),
                        key: const ValueKey('journal-entry-card-date'),
                        maxLines: 1,
                        softWrap: false,
                        style: AppTypography.caption(context),
                      ),
                    ],
                  );
                  final status = _StatusBadge(
                    status: entry.status,
                    label: entry.statusLabel,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (compactHeader) ...[
                        titleAndDate,
                        const SizedBox(height: 8),
                        status,
                      ] else
                        Row(children: [Expanded(child: titleAndDate), status]),
                      const SizedBox(height: 16),
                      if (entry.performingOrganizationName != null) ...[
                        Text(
                          'Компания: ${entry.performingOrganizationName}',
                          style: AppTypography.bodyMedium(context),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        entry.workDescription,
                        style: AppTypography.bodyMedium(context),
                      ),
                      if ((entry.problemsDescription ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Section(
                          title: 'Проблемы',
                          value: entry.problemsDescription!,
                        ),
                      ],
                      if ((entry.safetyNotes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Section(
                          title: 'Безопасность',
                          value: entry.safetyNotes!,
                        ),
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
                  );
                },
              ),
            ),
            if (entry.blockers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _BlockersCard(blockers: entry.blockers),
            ],
            if (entry.sourceEntry != null) ...[
              const SizedBox(height: 16),
              IndustrialCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Принятая запись из журнала ${entry.sourceEntry!.organizationName ?? 'подчинённой компании'}',
                      style: AppTypography.h2(context),
                    ),
                    Text(
                      'Журнал №${entry.sourceEntry!.journalNumber ?? entry.sourceEntry!.journalId}, запись №${entry.sourceEntry!.entryNumber} от ${entry.sourceEntry!.entryDate ?? '—'}. Проверил: ${entry.sourceEntry!.approvedByName ?? '—'}. Факты сохранены без повторного учёта.',
                    ),
                    if (entry.originEntry != null &&
                        entry.originEntry!.id != entry.sourceEntry!.id)
                      Text(
                        'Первичный исполнитель: ${entry.originEntry!.organizationName ?? '—'}, запись №${entry.originEntry!.entryNumber}.',
                      ),
                    if (entry.reportComment?.isNotEmpty == true)
                      Text('Комментарий к отчёту: ${entry.reportComment}'),
                    TextButton(
                      onPressed:
                          projectMatches
                              ? () => navigator.push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => JournalEntryDetailScreen(
                                        journalId: entry.sourceEntry!.journalId,
                                        entryId: entry.sourceEntry!.id,
                                        projectId: _projectId,
                                      ),
                                ),
                              )
                              : null,
                      child: const Text('Открыть источник и документы'),
                    ),
                  ],
                ),
              ),
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
            _WorkVolumesReadOnlyCard(
              volumes: entry.workVolumes,
              canManageContracts: entry.canManageContracts,
            ),
            const SizedBox(height: 16),
            IndustrialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Фото записи', style: AppTypography.h2(context)),
                  if (!attachmentsContextCurrent)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Объект или организация изменились. Откройте запись заново.',
                      ),
                    ),
                  if (attachmentsContextCurrent && entry.attachments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Фото пока нет.'),
                    ),
                  if (attachmentsContextCurrent)
                    for (final attachment in entry.attachments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.image_outlined),
                        title: Text(attachment.fileName),
                        subtitle:
                            attachment.uploadedByName == null
                                ? null
                                : Text(attachment.uploadedByName!),
                        trailing: const Icon(Icons.open_in_new_outlined),
                        onTap:
                            _activeAction == null &&
                                    entry.hasAction(
                                      ConstructionJournalActionKeys.view,
                                    ) &&
                                    _attachmentContextCurrent(_boundActor!)
                                ? () => _openAttachment(entry, attachment)
                                : null,
                      ),
                  if (attachmentsContextCurrent &&
                      entry.hasAction(
                        ConstructionJournalActionKeys.uploadAttachment,
                      ))
                    OutlinedButton.icon(
                      onPressed:
                          _activeAction == null &&
                                  !state.fromCache &&
                                  !state.hasDirtyLocal &&
                                  _attachmentContextCurrent(_boundActor!)
                              ? () => _uploadAttachment(entry, notifier)
                              : null,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Добавить фото'),
                    ),
                  if (entry.hasAction(
                        ConstructionJournalActionKeys.uploadAttachment,
                      ) &&
                      (state.fromCache || state.hasDirtyLocal))
                    const Text(
                      'Для загрузки фото обновите запись при подключении к интернету.',
                    ),
                  if (_activeAction?.startsWith('attachment') == true)
                    const LinearProgressIndicator(),
                ],
              ),
            ),
            if (entry.approvalHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              _FieldResourcesCard(
                title: 'История согласования',
                lines:
                    entry.approvalHistory
                        .map(
                          (event) => [
                            event.eventLabel,
                            if (event.actorName != null) event.actorName!,
                            if (event.actorOrganizationName != null)
                              event.actorOrganizationName!,
                            if (event.occurredAt != null)
                              _formatDate(event.occurredAt!),
                            if (event.reason != null) event.reason!,
                          ].join(' · '),
                        )
                        .toList(),
              ),
            ],
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
                              '${worker.specialty}: ${worker.workersCount} чел.${worker.hoursWorked == null ? '' : ', ${worker.hoursWorked} ч на человека'}',
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
                              '${item.name}: ${item.quantity} ед.${item.hoursUsed == null ? '' : ', ${item.hoursUsed} ч на единицу техники'}',
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
                        _activeAction == null &&
                                projectMatches &&
                                entry.id == entryId &&
                                entry.journalId == journalId
                            ? () async {
                              if (!_isProjectCurrent ||
                                  entry.id != entryId ||
                                  entry.journalId != journalId) {
                                return;
                              }
                              final updated = await navigator.push<bool>(
                                MaterialPageRoute(
                                  builder:
                                      (_) => JournalEntryFormScreen(
                                        journalId: journalId,
                                        projectId: scope.projectId,
                                        initialEntry: entry,
                                      ),
                                ),
                              );
                              if (updated == true &&
                                  mounted &&
                                  _isProjectCurrent) {
                                await notifier.load();
                              }
                            }
                            : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Редактировать'),
                  ),
                if (entry.hasAction(
                  ConstructionJournalActionKeys.includeInJournal,
                ))
                  FilledButton.icon(
                    onPressed:
                        _activeAction == null &&
                                projectMatches &&
                                attachmentsContextCurrent
                            ? () async {
                              final report = await showDialog<
                                ConstructionJournalEntryModel
                              >(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (_) => IncludeJournalEntryDialog(
                                      sourceId: entryId,
                                      isContextCurrent:
                                          () => _attachmentContextCurrent(
                                            _boundActor!,
                                          ),
                                    ),
                              );
                              if (report != null &&
                                  mounted &&
                                  _attachmentContextCurrent(_boundActor!)) {
                                await navigator.push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => JournalEntryDetailScreen(
                                          journalId: report.journalId,
                                          entryId: report.id,
                                          projectId: _projectId,
                                        ),
                                  ),
                                );
                                if (mounted && _isProjectCurrent) {
                                  await notifier.load();
                                }
                              }
                            }
                            : null,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Включить в свой журнал'),
                  ),
                if (entry.hasAction(ConstructionJournalActionKeys.updateReport))
                  OutlinedButton(
                    onPressed:
                        _activeAction == null &&
                                projectMatches &&
                                attachmentsContextCurrent
                            ? () async {
                              final controller = TextEditingController(
                                text: entry.reportComment,
                              );
                              final comment = await showDialog<String>(
                                context: context,
                                builder:
                                    (dialogContext) => AlertDialog(
                                      title: const Text('Комментарий к отчёту'),
                                      content: TextField(
                                        controller: controller,
                                        maxLength: 4000,
                                        minLines: 2,
                                        maxLines: 4,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(dialogContext),
                                          child: const Text('Отмена'),
                                        ),
                                        FilledButton(
                                          onPressed:
                                              () => Navigator.pop(
                                                dialogContext,
                                                controller.text,
                                              ),
                                          child: const Text('Сохранить'),
                                        ),
                                      ],
                                    ),
                              );
                              controller.dispose();
                              if (comment != null) {
                                await _runAction('update_report', () async {
                                  await ref
                                      .read(
                                        constructionJournalRepositoryProvider,
                                      )
                                      .updateReportComment(entryId, comment);
                                  await notifier.load();
                                });
                              }
                            }
                            : null,
                    child: const Text('Комментарий к отчёту'),
                  ),
                if (entry.hasAction(
                  ConstructionJournalActionKeys.assignContract,
                ))
                  OutlinedButton.icon(
                    onPressed:
                        _activeAction == null &&
                                projectMatches &&
                                entry.journalId == journalId
                            ? () => _runAction('assign_contract', () async {
                              final actor = _actorContext;
                              final changed = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (
                                      context,
                                    ) => JournalContractAssignmentDialog(
                                      entry: entry,
                                      repository: ref.read(
                                        constructionJournalRepositoryProvider,
                                      ),
                                      isContextCurrent:
                                          () =>
                                              _attachmentContextCurrent(actor),
                                    ),
                              );
                              if (changed == true &&
                                  _attachmentContextCurrent(actor)) {
                                await notifier.load();
                                await ref
                                    .read(
                                      constructionJournalDetailProvider((
                                        journalId: journalId,
                                        projectId: projectId,
                                      )).notifier,
                                    )
                                    .load();
                              }
                            })
                            : null,
                    icon: const Icon(Icons.link),
                    label: const Text('Назначить договор строке'),
                  ),
                if (entry.hasAction(ConstructionJournalActionKeys.submit))
                  ElevatedButton.icon(
                    onPressed:
                        _activeAction == null &&
                                projectMatches &&
                                entry.id == entryId &&
                                entry.journalId == journalId
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
                        _activeAction == null &&
                                projectMatches &&
                                entry.id == entryId &&
                                entry.journalId == journalId
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
                        _activeAction == null &&
                                projectMatches &&
                                entry.id == entryId &&
                                entry.journalId == journalId
                            ? () {
                              if (!_isProjectCurrent ||
                                  entry.id != entryId ||
                                  entry.journalId != journalId) {
                                return;
                              }
                              _showRejectDialog(
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
                              );
                            }
                            : null,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Отклонить'),
                  ),
                if (entry.hasAction(ConstructionJournalActionKeys.delete))
                  OutlinedButton.icon(
                    onPressed:
                        _activeAction == null &&
                                projectMatches &&
                                entry.id == entryId &&
                                entry.journalId == journalId
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
                        _activeAction == null &&
                                projectMatches &&
                                entry.id == entryId &&
                                entry.journalId == journalId
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
    if (_activeAction != null || !_attachmentContextCurrent(_boundActor!)) {
      return false;
    }
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

  Future<void> _uploadAttachment(
    ConstructionJournalEntryModel entry,
    ConstructionJournalEntryDetailNotifier notifier,
  ) async {
    if (!entry.hasAction(ConstructionJournalActionKeys.uploadAttachment)) {
      return;
    }
    final actor = _actorContext;
    if (!_attachmentContextCurrent(actor)) return;
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Снять фото'),
                  onTap: () => Navigator.pop(sheetContext, true),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Выбрать фото'),
                  onTap: () => Navigator.pop(sheetContext, false),
                ),
              ],
            ),
          ),
    );
    if (camera == null || !_attachmentContextCurrent(actor)) return;
    await _runAction('attachment_upload', () async {
      final path = await ref
          .read(journalPhotoPickerProvider)
          .pick(camera: camera);
      if (path == null || !_attachmentContextCurrent(actor)) return;
      await ref
          .read(constructionJournalRepositoryProvider)
          .uploadAttachment(entry.id, path);
      if (!_attachmentContextCurrent(actor)) return;
      await notifier.load();
    });
  }

  Future<void> _openAttachment(
    ConstructionJournalEntryModel entry,
    ConstructionJournalAttachment attachment,
  ) async {
    final actor = _actorContext;
    if (!_attachmentContextCurrent(actor) ||
        !entry.hasAction(ConstructionJournalActionKeys.view)) {
      return;
    }
    await _runAction('attachment_open', () async {
      final service = ref.read(designPackageFileServiceProvider);
      String? path;
      try {
        final grant = await ref
            .read(constructionJournalRepositoryProvider)
            .attachmentDownload(entry.id, attachment.id);
        if (!_attachmentContextCurrent(actor)) return;
        path = await service.download(grant.url, attachment.fileName);
        if (!_attachmentContextCurrent(actor)) return;
        final opened = await service.openLocalFile(path);
        if (!_attachmentContextCurrent(actor)) return;
        if (!opened) {
          throw const FormatException(
            'Не удалось открыть фото. Проверьте приложение для просмотра изображений.',
          );
        }
        service.scheduleCleanup(path);
        path = null;
      } finally {
        if (path != null) await service.deleteDownloaded(path);
      }
    });
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
  const _WorkVolumesReadOnlyCard({
    required this.volumes,
    required this.canManageContracts,
  });

  final bool canManageContracts;

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
                      volume.title ??
                          volume.workName ??
                          volume.estimateItem?.name ??
                          'Работа',
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${volume.quantity} ${volume.measurementUnitName ?? volume.estimateItem?.measurementUnit?.displayName ?? '-'}',
                      style: AppTypography.caption(context),
                    ),
                    if (volume.estimateItem?.estimatePlannedQuantity != null)
                      Text(
                        'План по смете: ${volume.estimateItem!.estimatePlannedQuantity}',
                        style: AppTypography.caption(context),
                      ),
                    if (canManageContracts &&
                        volume.estimateItem?.contractAgreedQuantity != null)
                      Text(
                        'Согласовано по договору: ${volume.estimateItem!.contractAgreedQuantity}',
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
