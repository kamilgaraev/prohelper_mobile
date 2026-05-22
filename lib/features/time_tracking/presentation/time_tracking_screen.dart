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
import '../data/time_entry_model.dart';
import '../domain/time_tracking_provider.dart';

class TimeTrackingScreen extends ConsumerStatefulWidget {
  const TimeTrackingScreen({super.key});

  @override
  ConsumerState<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends ConsumerState<TimeTrackingScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timeTrackingProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final projectId = selectedProject?.serverId;
    final date = _dateKey(_selectedDate);

    if ((state.projectId != projectId || state.date != date) &&
        !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncAndLoad();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Учет времени'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  projectId == null
                      ? null
                      : () =>
                          ref
                              .read(timeTrackingProvider.notifier)
                              .loadDailySummary(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body:
            projectId == null
                ? const AppEmptyState(
                  icon: Icons.domain_disabled_outlined,
                  title: 'Выберите объект',
                  description:
                      'Учет времени ведется по конкретному объекту. Выберите объект на главном экране.',
                )
                : state.isLoading && state.entries.isEmpty
                ? const AppLoadingState(message: 'Загружаем учет времени')
                : state.error != null && state.entries.isEmpty
                ? AppErrorState(
                  title:
                      state.permissionDenied
                          ? 'Нет доступа к учету времени'
                          : state.malformedContract
                          ? 'Данные учета времени требуют проверки'
                          : 'Не удалось загрузить учет времени',
                  description: state.error,
                  onRetry:
                      () =>
                          ref
                              .read(timeTrackingProvider.notifier)
                              .loadDailySummary(),
                )
                : RefreshIndicator(
                  onRefresh:
                      () =>
                          ref
                              .read(timeTrackingProvider.notifier)
                              .loadDailySummary(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _ScopePanel(
                        selectedDate: _selectedDate,
                        projectName: selectedProject?.name,
                        onPickDate: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      _TimeSummaryStrip(state: state),
                      const SizedBox(height: 12),
                      _TimeActionsPanel(
                        activeTimer: state.activeTimer,
                        onStart: () => _showStartTimerSheet(context, ref),
                        onManual: () => _showManualEntrySheet(context, ref),
                        onStop:
                            state.activeTimer == null
                                ? null
                                : () => _showStopTimerSheet(
                                  context,
                                  ref,
                                  state.activeTimer!,
                                ),
                      ),
                      const SizedBox(height: 12),
                      if (state.entries.isEmpty)
                        const AppEmptyState(
                          icon: Icons.timer_outlined,
                          title: 'Записей за день нет',
                          description:
                              'Запустите таймер или добавьте ручную запись по фактически выполненной работе.',
                        )
                      else
                        ...state.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TimeEntryCard(
                              entry: entry,
                              onOpen: () => _openDetail(entry.id),
                              onStop:
                                  entry.canStop
                                      ? () => _showStopTimerSheet(
                                        context,
                                        ref,
                                        entry,
                                      )
                                      : null,
                              onSubmit:
                                  entry.canSubmit
                                      ? () => _submitEntry(context, ref, entry)
                                      : null,
                              onCorrection:
                                  entry.canCorrect
                                      ? () => _showCorrectionSheet(
                                        context,
                                        ref,
                                        entry,
                                      )
                                      : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }

  void _syncAndLoad() {
    final selectedProject = ref.read(projectsProvider).selectedProject;
    final notifier = ref.read(timeTrackingProvider.notifier);
    notifier.syncScope(
      date: _dateKey(_selectedDate),
      projectId: selectedProject?.serverId,
    );

    if (selectedProject?.serverId != null) {
      notifier.loadDailySummary();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
    _syncAndLoad();
  }

  void _openDetail(int entryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimeEntryDetailScreen(entryId: entryId),
      ),
    );
  }
}

class TimeEntryDetailScreen extends ConsumerStatefulWidget {
  const TimeEntryDetailScreen({required this.entryId, super.key});

  final int entryId;

  @override
  ConsumerState<TimeEntryDetailScreen> createState() =>
      _TimeEntryDetailScreenState();
}

class _TimeEntryDetailScreenState extends ConsumerState<TimeEntryDetailScreen> {
  late Future<TimeEntryModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(timeTrackingProvider.notifier)
        .fetchEntry(widget.entryId);
  }

  void _reload() {
    setState(() {
      _future = ref
          .read(timeTrackingProvider.notifier)
          .fetchEntry(widget.entryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Запись времени'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<TimeEntryModel>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppLoadingState(message: 'Загружаем запись времени');
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AppErrorState(
                title: 'Не удалось загрузить запись времени',
                description: snapshot.error?.toString(),
                onRetry: _reload,
              );
            }

            final entry = snapshot.data!;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  _TimeEntryDetails(entry: entry),
                  const SizedBox(height: 16),
                  _TimeEntryActionPanel(
                    entry: entry,
                    onStop:
                        entry.canStop
                            ? () => _showStopTimerSheet(
                              context,
                              ref,
                              entry,
                              onDone: _reload,
                            )
                            : null,
                    onSubmit:
                        entry.canSubmit
                            ? () => _submitEntry(
                              context,
                              ref,
                              entry,
                              onDone: _reload,
                            )
                            : null,
                    onCorrection:
                        entry.canCorrect
                            ? () => _showCorrectionSheet(
                              context,
                              ref,
                              entry,
                              onDone: _reload,
                            )
                            : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScopePanel extends StatelessWidget {
  const _ScopePanel({
    required this.selectedDate,
    required this.projectName,
    required this.onPickDate,
  });

  final DateTime selectedDate;
  final String? projectName;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Объект', style: AppTypography.caption(context)),
                const SizedBox(height: 4),
                Text(
                  projectName ?? 'Объект не выбран',
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_readableDate(selectedDate)),
          ),
        ],
      ),
    );
  }
}

class _TimeSummaryStrip extends StatelessWidget {
  const _TimeSummaryStrip({required this.state});

  final TimeTrackingState state;

  @override
  Widget build(BuildContext context) {
    final totals = state.totals;
    final submitted = totals?.byStatus['submitted'] ?? 0;
    final approved = totals?.byStatus['approved'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Часы',
            value: _hoursText(totals?.totalHours ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(label: 'На проверке', value: '$submitted'),
        ),
        const SizedBox(width: 8),
        Expanded(child: _SummaryTile(label: 'Согласовано', value: '$approved')),
      ],
    );
  }
}

class _TimeActionsPanel extends StatelessWidget {
  const _TimeActionsPanel({
    required this.activeTimer,
    required this.onStart,
    required this.onManual,
    required this.onStop,
  });

  final TimeEntryModel? activeTimer;
  final VoidCallback onStart;
  final VoidCallback onManual;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeTimer != null) ...[
            Row(
              children: [
                const Icon(Icons.timer_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeTimer!.title,
                    style: AppTypography.bodyLarge(
                      context,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Начало: ${activeTimer!.startTime}',
              style: AppTypography.caption(context),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: activeTimer == null ? onStart : onStop,
                icon: Icon(
                  activeTimer == null
                      ? Icons.play_arrow_rounded
                      : Icons.stop_rounded,
                ),
                label: Text(activeTimer == null ? 'Запустить' : 'Остановить'),
              ),
              OutlinedButton.icon(
                onPressed: onManual,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Ручная запись'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeEntryCard extends StatelessWidget {
  const _TimeEntryCard({
    required this.entry,
    required this.onOpen,
    required this.onStop,
    required this.onSubmit,
    required this.onCorrection,
  });

  final TimeEntryModel entry;
  final VoidCallback onOpen;
  final VoidCallback? onStop;
  final VoidCallback? onSubmit;
  final VoidCallback? onCorrection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusBadge(status: entry.status, label: entry.statusLabel),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: _formatDate(entry.workDate),
              ),
              if (entry.hoursWorked != null)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: _hoursText(entry.hoursWorked!),
                ),
              if (entry.startTime != null)
                _InfoChip(
                  icon: Icons.play_arrow_outlined,
                  label: entry.startTime!,
                ),
              if (entry.endTime != null)
                _InfoChip(icon: Icons.flag_outlined, label: entry.endTime!),
              _InfoChip(
                icon:
                    entry.isBillable
                        ? Icons.payments_outlined
                        : Icons.money_off_csred_outlined,
                label: entry.isBillable ? 'Оплачиваемое' : 'Без оплаты',
              ),
            ],
          ),
          if (entry.description != null) ...[
            const SizedBox(height: 8),
            Text(
              entry.description!,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (entry.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              entry.rejectionReason!,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 12),
          _TimeEntryActionPanel(
            entry: entry,
            onOpen: onOpen,
            onStop: onStop,
            onSubmit: onSubmit,
            onCorrection: onCorrection,
          ),
        ],
      ),
    );
  }
}

class _TimeEntryDetails extends StatelessWidget {
  const _TimeEntryDetails({required this.entry});

  final TimeEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title, style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(status: entry.status, label: entry.statusLabel),
              if (entry.workTypeLabel != null)
                _InfoChip(
                  icon: Icons.engineering_outlined,
                  label: entry.workTypeLabel!,
                ),
              if (entry.taskLabel != null)
                _InfoChip(
                  icon: Icons.task_alt_outlined,
                  label: entry.taskLabel!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailLine(label: 'Объект', value: entry.projectLabel),
          _DetailLine(label: 'Дата', value: _formatDate(entry.workDate)),
          if (entry.startTime != null)
            _DetailLine(label: 'Начало', value: entry.startTime!),
          if (entry.endTime != null)
            _DetailLine(label: 'Окончание', value: entry.endTime!),
          if (entry.hoursWorked != null)
            _DetailLine(label: 'Часы', value: _hoursText(entry.hoursWorked!)),
          if (entry.breakTime != null)
            _DetailLine(label: 'Перерыв', value: _hoursText(entry.breakTime!)),
          _DetailLine(
            label: 'Оплата',
            value: entry.isBillable ? 'Оплачиваемое время' : 'Без оплаты',
          ),
          if (entry.description != null)
            _DetailLine(label: 'Описание', value: entry.description!),
          if (entry.approvedByLabel != null)
            _DetailLine(label: 'Проверил', value: entry.approvedByLabel!),
          if (entry.rejectionReason != null)
            _DetailLine(label: 'Причина', value: entry.rejectionReason!),
          if (entry.corrections.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Корректировки', style: AppTypography.h2(context)),
            const SizedBox(height: 8),
            ...entry.corrections.map(
              (correction) => _CorrectionRow(correction: correction),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeEntryActionPanel extends StatelessWidget {
  const _TimeEntryActionPanel({
    required this.entry,
    this.onOpen,
    this.onStop,
    this.onSubmit,
    this.onCorrection,
  });

  final TimeEntryModel entry;
  final VoidCallback? onOpen;
  final VoidCallback? onStop;
  final VoidCallback? onSubmit;
  final VoidCallback? onCorrection;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onOpen != null)
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Подробнее'),
          ),
        if (onStop != null)
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Остановить'),
          ),
        if (onSubmit != null)
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Отправить'),
          ),
        if (onCorrection != null)
          OutlinedButton.icon(
            onPressed: onCorrection,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Корректировка'),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'submitted' => AppColors.warning,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

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

class _CorrectionRow extends StatelessWidget {
  const _CorrectionRow({required this.correction});

  final TimeEntryCorrectionModel correction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_note_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_hoursText(correction.newHours)}: ${correction.reason}',
                  style: AppTypography.bodyMedium(context),
                ),
                Text(
                  _formatDate(correction.createdAt),
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

Future<void> _showStartTimerSheet(BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final startController = TextEditingController();
  final descriptionController = TextEditingController();
  var isBillable = true;
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
                    Text('Запустить таймер', style: AppTypography.h2(context)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Работа'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: startController,
                      decoration: const InputDecoration(
                        labelText: 'Время начала, ЧЧ:ММ',
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Описание'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isBillable,
                      onChanged: (value) {
                        setSheetState(() => isBillable = value);
                      },
                      title: const Text('Оплачиваемое время'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          submitting
                              ? null
                              : () async {
                                if (!_hasText(titleController.text) ||
                                    !_hasText(startController.text)) {
                                  _message(
                                    context,
                                    'Укажите работу и время начала',
                                  );
                                  return;
                                }

                                setSheetState(() => submitting = true);
                                try {
                                  await ref
                                      .read(timeTrackingProvider.notifier)
                                      .startTimer(
                                        startTime: startController.text,
                                        title: titleController.text,
                                        isBillable: isBillable,
                                        description: descriptionController.text,
                                      );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    _message(context, error.toString());
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setSheetState(() => submitting = false);
                                  }
                                }
                              },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(submitting ? 'Запускаем...' : 'Запустить'),
                    ),
                  ],
                ),
              ),
        ),
  );
}

Future<void> _showManualEntrySheet(BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final hoursController = TextEditingController();
  final startController = TextEditingController();
  final endController = TextEditingController();
  final breakController = TextEditingController();
  final descriptionController = TextEditingController();
  var isBillable = true;
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ручная запись', style: AppTypography.h2(context)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Работа'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: hoursController,
                        decoration: const InputDecoration(labelText: 'Часы'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startController,
                              decoration: const InputDecoration(
                                labelText: 'Начало',
                              ),
                              keyboardType: TextInputType.datetime,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: endController,
                              decoration: const InputDecoration(
                                labelText: 'Окончание',
                              ),
                              keyboardType: TextInputType.datetime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: breakController,
                        decoration: const InputDecoration(
                          labelText: 'Перерыв, ч',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isBillable,
                        onChanged: (value) {
                          setSheetState(() => isBillable = value);
                        },
                        title: const Text('Оплачиваемое время'),
                      ),
                      FilledButton.icon(
                        onPressed:
                            submitting
                                ? null
                                : () async {
                                  final hours = _parseNumber(
                                    hoursController.text,
                                  );
                                  if (!_hasText(titleController.text) ||
                                      hours == null) {
                                    _message(context, 'Укажите работу и часы');
                                    return;
                                  }

                                  setSheetState(() => submitting = true);
                                  try {
                                    await ref
                                        .read(timeTrackingProvider.notifier)
                                        .createManualEntry(
                                          hoursWorked: hours,
                                          title: titleController.text,
                                          isBillable: isBillable,
                                          startTime: startController.text,
                                          endTime: endController.text,
                                          breakTime: _parseNumber(
                                            breakController.text,
                                          ),
                                          description:
                                              descriptionController.text,
                                        );
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      _message(context, error.toString());
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(() => submitting = false);
                                    }
                                  }
                                },
                        icon: const Icon(Icons.save_outlined),
                        label: Text(submitting ? 'Сохраняем...' : 'Сохранить'),
                      ),
                    ],
                  ),
                ),
              ),
        ),
  );
}

Future<void> _showStopTimerSheet(
  BuildContext context,
  WidgetRef ref,
  TimeEntryModel entry, {
  VoidCallback? onDone,
}) async {
  final endController = TextEditingController();
  final breakController = TextEditingController();
  final notesController = TextEditingController();
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
                    Text('Остановить таймер', style: AppTypography.h2(context)),
                    const SizedBox(height: 8),
                    Text(entry.title, style: AppTypography.bodyLarge(context)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: endController,
                      decoration: const InputDecoration(
                        labelText: 'Время окончания, ЧЧ:ММ',
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: breakController,
                      decoration: const InputDecoration(
                        labelText: 'Перерыв, ч',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Примечание',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          submitting
                              ? null
                              : () async {
                                final breakTime = _parseNumber(
                                  breakController.text,
                                );
                                if (!_hasText(endController.text) ||
                                    breakTime == null) {
                                  _message(
                                    context,
                                    'Укажите время окончания и перерыв',
                                  );
                                  return;
                                }

                                setSheetState(() => submitting = true);
                                try {
                                  await ref
                                      .read(timeTrackingProvider.notifier)
                                      .stopTimer(
                                        id: entry.id,
                                        endTime: endController.text,
                                        breakTime: breakTime,
                                        notes: notesController.text,
                                      );
                                  onDone?.call();
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    _message(context, error.toString());
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setSheetState(() => submitting = false);
                                  }
                                }
                              },
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(
                        submitting ? 'Останавливаем...' : 'Остановить',
                      ),
                    ),
                  ],
                ),
              ),
        ),
  );
}

Future<void> _showCorrectionSheet(
  BuildContext context,
  WidgetRef ref,
  TimeEntryModel entry, {
  VoidCallback? onDone,
}) async {
  final hoursController = TextEditingController(
    text: entry.hoursWorked?.toString() ?? '',
  );
  final reasonController = TextEditingController();
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
                    Text('Корректировка', style: AppTypography.h2(context)),
                    const SizedBox(height: 8),
                    Text(entry.title, style: AppTypography.bodyLarge(context)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hoursController,
                      decoration: const InputDecoration(labelText: 'Часы'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(labelText: 'Причина'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          submitting
                              ? null
                              : () async {
                                final hours = _parseNumber(
                                  hoursController.text,
                                );
                                if (hours == null ||
                                    !_hasText(reasonController.text)) {
                                  _message(context, 'Укажите часы и причину');
                                  return;
                                }

                                setSheetState(() => submitting = true);
                                try {
                                  await ref
                                      .read(timeTrackingProvider.notifier)
                                      .submitCorrection(
                                        id: entry.id,
                                        hoursWorked: hours,
                                        correctionReason: reasonController.text,
                                      );
                                  onDone?.call();
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    _message(context, error.toString());
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setSheetState(() => submitting = false);
                                  }
                                }
                              },
                      icon: const Icon(Icons.send_rounded),
                      label: Text(submitting ? 'Отправляем...' : 'Отправить'),
                    ),
                  ],
                ),
              ),
        ),
  );
}

Future<void> _submitEntry(
  BuildContext context,
  WidgetRef ref,
  TimeEntryModel entry, {
  VoidCallback? onDone,
}) async {
  try {
    await ref.read(timeTrackingProvider.notifier).submitEntry(entry.id);
    onDone?.call();
  } catch (error) {
    if (context.mounted) {
      _message(context, error.toString());
    }
  }
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

String _readableDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return _readableDate(parsed);
}

String _hoursText(double value) {
  final text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

  return '$text ч';
}

double? _parseNumber(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return double.tryParse(trimmed.replaceAll(',', '.'));
}

bool _hasText(String value) {
  return value.trim().isNotEmpty;
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
