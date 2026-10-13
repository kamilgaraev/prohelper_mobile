import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/design/pro_status.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../../core/widgets/pro_status_banner.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';
import '../domain/construction_journal_provider.dart';
import 'journal_entry_detail_screen.dart';
import 'journal_entry_form_screen.dart';
import 'journal_form_screen.dart';
import '../../auth/domain/auth_provider.dart';

class ConstructionJournalDetailScreen extends ConsumerStatefulWidget {
  const ConstructionJournalDetailScreen({
    super.key,
    required this.journalId,
    required this.projectId,
  });

  final int journalId;
  final int projectId;

  @override
  ConsumerState<ConstructionJournalDetailScreen> createState() =>
      _ConstructionJournalDetailScreenState();
}

class _ConstructionJournalDetailScreenState
    extends ConsumerState<ConstructionJournalDetailScreen> {
  int get journalId => widget.journalId;
  int get projectId => widget.projectId;
  int _contractFilter = 0;
  int _filterEpoch = 0;
  bool _filterLoading = false;
  String? _filterError;
  ConstructionJournalDetailPayload? _filtered;
  Future<ConstructionJournalEntryFormOptions>? _options;
  Object? _boundActor;

  Object get _actorContext {
    final auth = ref.read(authProvider);
    return (
      user: auth.user?.serverId,
      organization: auth.user?.currentOrganizationId,
      session: auth is AuthAuthenticated ? auth.sessionIdentity : null,
      journalId: journalId,
      projectId: projectId,
    );
  }

  Future<void> _setContractFilter(int value) async {
    final epoch = ++_filterEpoch;
    final actor = _actorContext;
    setState(() {
      _contractFilter = value;
      _filtered = null;
      _filterError = null;
      _filterLoading = value != 0;
    });
    if (value == 0) return;
    try {
      final payload = await ref
          .read(constructionJournalRepositoryProvider)
          .fetchJournalDetail(
            journalId,
            contractId: value > 0 ? value : null,
            unassignedOnly: value == -1,
          );
      if (mounted &&
          epoch == _filterEpoch &&
          actor == _actorContext &&
          ref.read(projectsProvider).selectedProject?.serverId == projectId) {
        setState(() => _filtered = payload);
      }
    } catch (_) {
      if (mounted && epoch == _filterEpoch && actor == _actorContext) {
        setState(
          () =>
              _filterError =
                  'Не удалось применить фильтр. Проверьте подключение или выберите все записи.',
        );
      }
    } finally {
      if (mounted && epoch == _filterEpoch && actor == _actorContext) {
        setState(() => _filterLoading = false);
      }
    }
  }

  Future<void> _reload() async {
    if (!mounted ||
        ref.read(projectsProvider).selectedProject?.serverId != projectId) {
      return;
    }
    final actor = _actorContext;
    await ref
        .read(
          constructionJournalDetailProvider((
            journalId: journalId,
            projectId: projectId,
          )).notifier,
        )
        .load();
    if (mounted && actor == _actorContext && _contractFilter != 0) {
      await _setContractFilter(_contractFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    if (_boundActor != _actorContext) {
      _boundActor = _actorContext;
      _filterEpoch++;
      _contractFilter = 0;
      _filtered = null;
      _filterError = null;
      _filterLoading = false;
      _options = ref
          .read(constructionJournalRepositoryProvider)
          .fetchEntryFormOptions(journalId);
    }
    final selectedProjectId = ref.watch(
      projectsProvider.select((state) => state.selectedProject?.serverId),
    );
    final scope = (journalId: journalId, projectId: projectId);
    final state = ref.watch(constructionJournalDetailProvider(scope));
    final visibleEntries =
        _contractFilter == 0
            ? state.entries
            : (_filtered?.entries ?? const <ConstructionJournalEntryModel>[]);
    final visibleSummary =
        _contractFilter == 0
            ? state.entriesSummary
            : (_filtered?.entriesSummary ?? const ConstructionJournalSummary());

    bool projectIsCurrent() =>
        ref.read(projectsProvider).selectedProject?.serverId == projectId;
    Future<void> transition(String action) async {
      if (!projectIsCurrent() || state.journal?.projectId != projectId) return;
      await ref
          .read(constructionJournalRepositoryProvider)
          .transitionJournal(journalId, action);
      await _reload();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка журнала'),
        actions: [
          IconButton(
            onPressed: selectedProjectId == projectId ? _reload : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (projectIsCurrent()) await _reload();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (selectedProjectId != projectId ||
                (state.journal != null &&
                    state.journal!.projectId != projectId))
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.apartment_outlined,
                  title: 'Выбран другой объект',
                  description:
                      'Вернитесь к списку журналов выбранного объекта.',
                ),
              )
            else if (state.isLoading && state.journal == null)
              const SliverFillRemaining(
                child: AppLoadingState(message: 'Загружаем журнал'),
              )
            else if (state.error != null && state.journal == null)
              SliverFillRemaining(
                child: AppErrorState(
                  title: 'Не удалось загрузить журнал',
                  description: state.error,
                  onRetry: _reload,
                ),
              )
            else if (state.journal == null)
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Журнал не найден',
                ),
              )
            else ...[
              if (state.fromCache || state.hasDirtyLocal)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: ProStatusBanner(
                      title:
                          state.hasDirtyLocal
                              ? 'Есть локальные изменения'
                              : 'Показаны сохранённые данные',
                      description:
                          state.error ??
                          'Актуальность данных не подтверждена сетью.',
                      tone:
                          state.hasDirtyLocal
                              ? ProStatusTone.warning
                              : ProStatusTone.info,
                      fullText: true,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: IndustrialCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.journal!.name,
                          style: AppTypography.h2(context),
                        ),
                        if (state.journal!.performingOrganizationName !=
                            null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Компания: ${state.journal!.performingOrganizationName}',
                            style: AppTypography.bodyMedium(context),
                          ),
                        ],
                        if (state.journal!.approvalContextMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            state.journal!.approvalContextMessage!,
                            style: AppTypography.bodyMedium(context),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Журнал №${state.journal!.journalNumber.isEmpty ? '-' : state.journal!.journalNumber}',
                          style: AppTypography.bodyMedium(context).copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Badge(
                              label: 'Всего ${state.journal!.totalEntries}',
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            _Badge(
                              label:
                                  'Утверждено ${state.journal!.approvedEntries}',
                              color: AppColors.success,
                            ),
                            _Badge(
                              label:
                                  'На проверке ${state.journal!.submittedEntries}',
                              color: AppColors.warning,
                            ),
                            _Badge(
                              label:
                                  'Отклонено ${state.journal!.rejectedEntries}',
                              color: AppColors.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (state.availableActions.hasAction(
                              ConstructionJournalActionKeys.createEntry,
                            ))
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (!projectIsCurrent() ||
                                      state.journal!.projectId != projectId) {
                                    return;
                                  }
                                  final created = await Navigator.of(
                                    context,
                                  ).push<bool>(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => JournalEntryFormScreen(
                                            journalId: journalId,
                                            projectId: projectId,
                                            submissionBlocker:
                                                state.journal!.submissionBlocked
                                                    ? state
                                                            .journal!
                                                            .approvalContextMessage ??
                                                        'Настройте порядок согласования компаний проекта перед отправкой записи.'
                                                    : null,
                                          ),
                                    ),
                                  );

                                  if (created == true && projectIsCurrent()) {
                                    await _reload();
                                  }
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Новая запись'),
                              ),
                            if (state.availableActions.hasAction(
                              ConstructionJournalActionKeys.update,
                            ))
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (!projectIsCurrent() ||
                                      state.journal!.projectId != projectId) {
                                    return;
                                  }
                                  final updated = await Navigator.of(
                                    context,
                                  ).push<bool>(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => JournalFormScreen(
                                            initialJournal: state.journal,
                                          ),
                                    ),
                                  );

                                  if (updated == true && projectIsCurrent()) {
                                    await _reload();
                                  }
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Редактировать'),
                              ),
                            if (state.journal?.canManageContracts == true &&
                                state.availableActions.hasAction(
                                  ConstructionJournalActionKeys.export,
                                ))
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (!projectIsCurrent() ||
                                      state.journal!.projectId != projectId) {
                                    return;
                                  }
                                  await _showExportRangeDialog(
                                    context,
                                    ref,
                                    state.journal!,
                                  );
                                },
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Экспорт КС-6'),
                              ),
                            if (state.availableActions.hasAction(
                              ConstructionJournalActionKeys.close,
                            ))
                              OutlinedButton.icon(
                                onPressed:
                                    () => transition(
                                      ConstructionJournalActionKeys.close,
                                    ),
                                icon: const Icon(Icons.lock_outline_rounded),
                                label: const Text('Закрыть журнал'),
                              ),
                            if (state.availableActions.hasAction(
                              ConstructionJournalActionKeys.archive,
                            ))
                              OutlinedButton.icon(
                                onPressed:
                                    () => transition(
                                      ConstructionJournalActionKeys.archive,
                                    ),
                                icon: const Icon(Icons.archive_outlined),
                                label: const Text('В архив'),
                              ),
                            if (state.availableActions.hasAction(
                              ConstructionJournalActionKeys.reopen,
                            ))
                              OutlinedButton.icon(
                                onPressed:
                                    () => transition(
                                      ConstructionJournalActionKeys.reopen,
                                    ),
                                icon: const Icon(Icons.lock_open_rounded),
                                label: const Text('Открыть снова'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Всего записей',
                          value: visibleSummary.totalEntries.toString(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'Утверждено',
                          value: visibleSummary.approvedEntries.toString(),
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Записи журнала',
                    style: AppTypography.h2(context),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<ConstructionJournalEntryFormOptions>(
                    future: _options,
                    builder:
                        (context, snapshot) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (snapshot.data?.canManageContracts == true)
                              DropdownButtonFormField<int>(
                                key: ValueKey(_contractFilter),
                                initialValue: _contractFilter,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Договор',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 0,
                                    child: Text(
                                      'Все договоры и строки без договора',
                                    ),
                                  ),
                                  const DropdownMenuItem(
                                    value: -1,
                                    child: Text('Без договора'),
                                  ),
                                  for (final contract
                                      in snapshot.data?.contracts ??
                                          const <
                                            ConstructionJournalContractOption
                                          >[])
                                    DropdownMenuItem(
                                      value: contract.id,
                                      child: Text(
                                        contract.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged:
                                    selectedProjectId != projectId ||
                                            _filterLoading
                                        ? null
                                        : (value) {
                                          if (value != null) {
                                            _setContractFilter(value);
                                          }
                                        },
                              ),
                            if (snapshot.hasError)
                              const Text(
                                'Не удалось загрузить договоры проекта.',
                              ),
                            if (snapshot.data?.canManageContracts == true &&
                                visibleSummary.unassignedRows != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Строк без договора: ${visibleSummary.unassignedRows}',
                                ),
                              ),
                            if (_filterLoading) const LinearProgressIndicator(),
                            if (_filterError != null)
                              Text(
                                _filterError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                  ),
                ),
              ),
              if (visibleEntries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'Записей пока нет',
                    description:
                        'Добавьте первую запись по выполненным работам.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = visibleEntries[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IndustrialCard(
                          onTap:
                              !projectIsCurrent()
                                  ? null
                                  : () async {
                                    if (!projectIsCurrent() ||
                                        state.journal?.projectId != projectId) {
                                      return;
                                    }
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => JournalEntryDetailScreen(
                                              journalId: journalId,
                                              entryId: entry.id,
                                              projectId: projectId,
                                            ),
                                      ),
                                    );
                                    await _reload();
                                  },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Запись №${entry.entryNumber}',
                                          style: AppTypography.bodyLarge(
                                            context,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(entry.entryDate),
                                          style: AppTypography.caption(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _Badge(
                                    label: entry.statusLabel,
                                    color: _entryStatusColor(entry.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                entry.workDescription,
                                style: AppTypography.bodyMedium(context),
                              ),
                              if ((entry.rejectionReason ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Причина отклонения: ${entry.rejectionReason}',
                                  style: AppTypography.caption(
                                    context,
                                  ).copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }, childCount: visibleEntries.length),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.caption(context)),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.h2(context).copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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

Color _entryStatusColor(String status) {
  return switch (status) {
    'approved' => AppColors.success,
    'submitted' => AppColors.warning,
    'rejected' => AppColors.error,
    'draft' => AppColors.secondary,
    _ => throw StateError('Unknown construction journal entry status: $status'),
  };
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

Future<void> _showExportDialog(BuildContext context, String url) async {
  if (url.isNotEmpty) {
    await Clipboard.setData(ClipboardData(text: url));
  }

  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Ссылка на экспорт готова'),
        content: SelectableText(
          url.isEmpty
              ? 'Ссылка не получена от сервера.'
              : '$url\n\nСсылка уже скопирована в буфер обмена.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
}

Future<void> _showExportRangeDialog(
  BuildContext context,
  WidgetRef ref,
  ConstructionJournalModel journal,
) async {
  var dateFrom = _parseIsoDate(journal.startDate);
  var dateTo = _parseIsoDate(journal.endDate ?? journal.startDate);
  var isExporting = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (sheetContext, setDialogState) {
          Future<void> pickDate(bool isStart) async {
            final picked = await showDatePicker(
              context: sheetContext,
              initialDate: isStart ? dateFrom : dateTo,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );

            if (picked == null) {
              return;
            }

            setDialogState(() {
              if (isStart) {
                dateFrom = picked;
                if (dateTo.isBefore(dateFrom)) {
                  dateTo = picked;
                }
              } else {
                dateTo = picked;
              }
            });
          }

          return AlertDialog(
            title: const Text('Экспорт КС-6'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Начало периода'),
                  subtitle: Text(_formatDateValue(dateFrom)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: isExporting ? null : () => pickDate(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Окончание периода'),
                  subtitle: Text(_formatDateValue(dateTo)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: isExporting ? null : () => pickDate(false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    isExporting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton.icon(
                onPressed:
                    isExporting
                        ? null
                        : () async {
                          if (ref
                                  .read(projectsProvider)
                                  .selectedProject
                                  ?.serverId !=
                              journal.projectId) {
                            return;
                          }
                          if (dateTo.isBefore(dateFrom)) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Дата окончания не может быть раньше даты начала.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isExporting = true;
                          });

                          var dialogClosed = false;
                          try {
                            final url = await ref
                                .read(constructionJournalRepositoryProvider)
                                .exportJournal(
                                  journalId: journal.id,
                                  dateFrom: _toIsoDate(dateFrom),
                                  dateTo: _toIsoDate(dateTo),
                                );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.of(dialogContext).pop();
                            dialogClosed = true;
                            if (context.mounted) {
                              await _showExportDialog(context, url);
                            }
                          } finally {
                            if (!dialogClosed && dialogContext.mounted) {
                              setDialogState(() {
                                isExporting = false;
                              });
                            }
                          }
                        },
                icon:
                    isExporting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.download_rounded),
                label: const Text('Сформировать'),
              ),
            ],
          );
        },
      );
    },
  );
}

DateTime _parseIsoDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw StateError('Invalid construction journal date: $value');
  }

  return date;
}

String _formatDateValue(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _toIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
