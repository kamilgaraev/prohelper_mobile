import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/permission_service.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/month_timekeeping_model.dart';
import '../domain/month_timekeeping_provider.dart';
import 'timekeeping_cell_editor.dart';
import 'timekeeping_action_sheet.dart';

const _months = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

String _errorMessage(Object error) =>
    error is ApiException
        ? error.message
        : 'Не удалось выполнить действие. Проверьте соединение и повторите попытку.';

class MonthTimekeepingScreen extends ConsumerStatefulWidget {
  const MonthTimekeepingScreen({super.key});
  @override
  ConsumerState<MonthTimekeepingScreen> createState() =>
      _MonthTimekeepingScreenState();
}

class _MonthTimekeepingScreenState
    extends ConsumerState<MonthTimekeepingScreen> {
  bool _creating = false;

  Future<void> _open(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimekeepingPeriodScreen(periodId: id),
      ),
    );
    if (mounted) await ref.read(monthTimekeepingProvider.notifier).load();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final period = await ref.read(monthTimekeepingProvider.notifier).create();
      if (mounted) await _open(period.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monthTimekeepingProvider);
    final notifier = ref.read(monthTimekeepingProvider.notifier);
    final projects = ref.watch(projectsProvider).projects.toList();
    final canManage = ref
        .watch(permissionServiceProvider)
        .hasPermission('workforce.timekeeping.manage');
    return PopScope(
      canPop: !_creating,
      child: Scaffold(
        appBar: AppBar(title: const Text('Месячные табели')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Предыдущий месяц',
                        onPressed:
                            _creating
                                ? null
                                : () => notifier.load(
                                  selectedMonth: DateTime(
                                    notifier.month.year,
                                    notifier.month.month - 1,
                                  ),
                                ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed:
                              _creating
                                  ? null
                                  : () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: notifier.month,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100, 12, 31),
                                    );
                                    if (date != null && mounted) {
                                      await notifier.load(selectedMonth: date);
                                    }
                                  },
                          child: Text(
                            '${_months[notifier.month.month - 1]} ${notifier.month.year}',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Следующий месяц',
                        onPressed:
                            _creating
                                ? null
                                : () => notifier.load(
                                  selectedMonth: DateTime(
                                    notifier.month.year,
                                    notifier.month.month + 1,
                                  ),
                                ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey('scope-${notifier.projectId}'),
                    initialValue:
                        projects.any((p) => p.serverId == notifier.projectId)
                            ? notifier.projectId
                            : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Область табеля',
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Вся организация'),
                      ),
                      ...projects.map(
                        (p) => DropdownMenuItem(
                          value: p.serverId,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged:
                        _creating
                            ? null
                            : (id) => notifier.load(
                              selectedProjectId: id,
                              changeScope: true,
                            ),
                  ),
                ],
              ),
            ),
            if (_creating) const LinearProgressIndicator(),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) => _Retry(
                      message: _errorMessage(error),
                      retry: () => notifier.load(),
                    ),
                data:
                    (data) => RefreshIndicator(
                      onRefresh: () => notifier.load(),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            data.periods.isEmpty ? 1 : data.periods.length + 1,
                        itemBuilder: (context, index) {
                          if (data.periods.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'За этот месяц табелей пока нет. Создайте табель, чтобы внести часы сотрудников.',
                              ),
                            );
                          }
                          if (index == data.periods.length) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Предыдущая страница',
                                  onPressed:
                                      _creating || data.page <= 1
                                          ? null
                                          : () => notifier.load(
                                            selectedPage: data.page - 1,
                                          ),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('${data.page} из ${data.lastPage}'),
                                IconButton(
                                  tooltip: 'Следующая страница',
                                  onPressed:
                                      _creating || data.page >= data.lastPage
                                          ? null
                                          : () => notifier.load(
                                            selectedPage: data.page + 1,
                                          ),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            );
                          }
                          final period = data.periods[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                'Табель №${period.id} · ${period.statusLabel}',
                              ),
                              subtitle: Text(
                                'Сотрудников: ${period.summary['employee_count'] ?? 0} · Часов: ${timekeepingHours(period.summary['fact_minutes'] as num? ?? 0)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _creating ? null : () => _open(period.id),
                            ),
                          );
                        },
                      ),
                    ),
              ),
            ),
          ],
        ),
        bottomNavigationBar:
            canManage
                ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed:
                          _creating || state.isLoading || state.hasError
                              ? null
                              : _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Создать или открыть табель'),
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}

class TimekeepingPeriodScreen extends ConsumerStatefulWidget {
  const TimekeepingPeriodScreen({super.key, required this.periodId});
  final int periodId;
  @override
  ConsumerState<TimekeepingPeriodScreen> createState() =>
      _TimekeepingPeriodScreenState();
}

class _TimekeepingPeriodScreenState
    extends ConsumerState<TimekeepingPeriodScreen> {
  late int _periodId;
  String _search = '';
  bool _showPlan = false;

  @override
  void initState() {
    super.initState();
    _periodId = widget.periodId;
  }

  Future<void> _perform(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  Future<void> _openDocument(Future<Uri> Function() call) => _perform(() async {
    final uri = await call();
    if (mounted &&
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const ApiException(
        'Не удалось открыть документ. Повторите экспорт.',
      );
    }
  });

  Future<void> _actionSheet(
    TimekeepingPeriod period,
    TimekeepingAction action,
  ) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TimekeepingActionSheet(period: period, action: action),
    );
    if (id != null && mounted) {
      setState(() => _periodId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timekeepingDetailProvider(_periodId));
    final notifier = ref.read(timekeepingDetailProvider(_periodId).notifier);
    final permissions = ref.watch(permissionServiceProvider);
    final busy = state.isLoading;
    final canManage = permissions.hasPermission('workforce.timekeeping.manage');
    final canPrivate = permissions.hasPermission('workforce.hr.private.read');
    final canExport =
        canPrivate && permissions.hasPermission('workforce.timekeeping.export');
    return PopScope(
      canPop: !busy || !state.hasValue,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Табель сотрудников'),
          actions: [
            IconButton(
              tooltip: 'Обновить табель',
              onPressed: busy ? null : () => notifier.load(),
              icon: const Icon(Icons.refresh),
            ),
            if (canExport)
              PopupMenuButton<String>(
                enabled: !busy && state.hasValue,
                tooltip: 'Экспортировать',
                onSelected:
                    (format) => _openDocument(() => notifier.export(format)),
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 'xlsx', child: Text('Excel')),
                      PopupMenuItem(value: 'pdf', child: Text('PDF')),
                      PopupMenuItem(value: 'csv', child: Text('CSV')),
                    ],
                icon: const Icon(Icons.file_download_outlined),
              ),
          ],
        ),
        body: state.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => _Retry(
                message: _errorMessage(error),
                retry: () => notifier.load(),
              ),
          data: (period) {
            final rows =
                period.rows
                    .where(
                      (row) => '${row.name} ${row.personnelNumber}'
                          .toLowerCase()
                          .contains(_search.toLowerCase()),
                    )
                    .toList();
            return CustomScrollView(
              slivers: [
                if (busy)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${period.month} · ${period.projectId == null ? 'Вся организация' : 'Объект'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${period.statusLabel} · Сотрудников: ${period.rows.map((r) => r.employeeId).toSet().length} · Часов: ${timekeepingHours(period.summary['fact_minutes'] as num? ?? 0)}',
                        ),
                        if (period.status == 'submitted' ||
                            period.status == 'verified')
                          const Text(
                            'Изменение часов вернёт табель в черновик.',
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Сотрудник или табельный номер',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Показывать план и факт'),
                          value: _showPlan,
                          onChanged:
                              (value) => setState(() => _showPlan = value),
                        ),
                        if (period.issues.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: Text('Замечания: ${period.issues.length}'),
                            onPressed:
                                () => showModalBottomSheet<void>(
                                  context: context,
                                  useSafeArea: true,
                                  builder:
                                      (_) => ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: period.issues.length,
                                        itemBuilder: (context, index) {
                                          final issue = period.issues[index];
                                          final people = period.rows.where(
                                            (row) =>
                                                row.employeeId ==
                                                issue.employeeId,
                                          );
                                          return ListTile(
                                            leading: Icon(
                                              issue.blocking
                                                  ? Icons.error_outline
                                                  : Icons.info_outline,
                                            ),
                                            title: Text(issue.label),
                                            subtitle: Text(
                                              [
                                                if (people.isNotEmpty)
                                                  people.first.name,
                                                if (issue.date != null)
                                                  issue.date!,
                                                issue.blocking
                                                    ? 'Блокирует подтверждение'
                                                    : 'Требует внимания',
                                              ].join(' · '),
                                            ),
                                          );
                                        },
                                      ),
                                ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (canManage && period.editable)
                              OutlinedButton(
                                onPressed:
                                    busy
                                        ? null
                                        : () =>
                                            _perform(() => notifier.refresh()),
                                child: const Text('Обновить из источников'),
                              ),
                            ...period.actions
                                .where(
                                  (action) =>
                                      action.enabled &&
                                      action.permission != null &&
                                      permissions.hasPermission(
                                        action.permission!,
                                      ) &&
                                      (action.code != 'approve' ||
                                          (canPrivate && canExport)),
                                )
                                .map(
                                  (action) => FilledButton.tonal(
                                    onPressed:
                                        busy
                                            ? null
                                            : () =>
                                                _actionSheet(period, action),
                                    child: Text(action.label),
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  sliver:
                      rows.isEmpty
                          ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                period.rows.isEmpty
                                    ? 'В этом табеле нет сотрудников. Проверьте состав сотрудников и обновите табель из источников.'
                                    : 'Сотрудники не найдены.',
                              ),
                            ),
                          )
                          : SliverList.builder(
                            itemCount:
                                rows.length +
                                (period.documents.isEmpty ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (index == rows.length) {
                                return ExpansionTile(
                                  title: const Text('Документы табеля'),
                                  children:
                                      period.documents
                                          .map(
                                            (doc) => ListTile(
                                              title: Text(doc.filename),
                                              subtitle: Text(
                                                'Версия ${doc.revision}',
                                              ),
                                              trailing: const Icon(
                                                Icons.open_in_new,
                                              ),
                                              onTap:
                                                  busy
                                                      ? null
                                                      : () => _openDocument(
                                                        () => notifier.download(
                                                          doc.id,
                                                        ),
                                                      ),
                                            ),
                                          )
                                          .toList(),
                                );
                              }
                              final row = rows[index];
                              final canEdit =
                                  canManage &&
                                  period.editable &&
                                  (row.hoursOnly ||
                                      permissions.hasPermission(
                                        'workforce.hr.private.write',
                                      ));
                              return Card(
                                child: ExpansionTile(
                                  key: PageStorageKey(
                                    '${period.id}:${row.key}',
                                  ),
                                  title: Text(row.name),
                                  subtitle: Text(
                                    '${row.personnelNumber} · ${row.hoursOnly ? 'Учёт часов без договора' : 'Договор №${row.contractNumber ?? 'не указан'}'}\nИтого: ${timekeepingHours(row.minutes)} ч',
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final columns =
                                              constraints.maxWidth < 310
                                                  ? 5
                                                  : 7;
                                          return GridView.builder(
                                            key: PageStorageKey(
                                              'days-${period.id}:${row.key}',
                                            ),
                                            primary: false,
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: columns,
                                                  mainAxisExtent:
                                                      MediaQuery.textScalerOf(
                                                        context,
                                                      ).scale(
                                                        _showPlan ? 70 : 52,
                                                      ) +
                                                      20,
                                                  crossAxisSpacing: 4,
                                                  mainAxisSpacing: 4,
                                                ),
                                            itemCount: row.days.length,
                                            itemBuilder: (context, dayIndex) {
                                              final day = row.days[dayIndex];
                                              return Semantics(
                                                label:
                                                    '${row.name}, ${day.date}, факт ${timekeepingHours(day.factMinutes)} часов',
                                                button: canEdit,
                                                child: Material(
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    onTap:
                                                        !canEdit || busy
                                                            ? null
                                                            : () => showModalBottomSheet<
                                                              void
                                                            >(
                                                              context: context,
                                                              isScrollControlled:
                                                                  true,
                                                              useSafeArea: true,
                                                              builder:
                                                                  (
                                                                    _,
                                                                  ) => TimekeepingCellEditor(
                                                                    period:
                                                                        period,
                                                                    row: row,
                                                                    day: day,
                                                                  ),
                                                            ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            day.date.substring(
                                                              8,
                                                            ),
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelMedium,
                                                          ),
                                                          Text(
                                                            '${timekeepingHours(day.factMinutes)} ч',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelLarge,
                                                          ),
                                                          if (_showPlan)
                                                            Text(
                                                              'П: ${timekeepingHours(day.plannedMinutes)}',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .labelSmall,
                                                            ),
                                                          if (day.absenceCode !=
                                                              null)
                                                            const Icon(
                                                              Icons.event_busy,
                                                              size: 14,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Повторить')),
        ],
      ),
    ),
  );
}
