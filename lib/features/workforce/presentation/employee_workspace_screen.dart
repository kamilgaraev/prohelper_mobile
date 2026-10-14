import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/permission_service.dart';
import '../data/employee_workspace_model.dart';
import '../domain/employee_workspace_provider.dart';

class EmployeeWorkspaceScreen extends ConsumerWidget {
  const EmployeeWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(employeeWorkspaceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои кадровые данные'),
        actions: [
          IconButton(
            tooltip: 'Выбрать месяц',
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null && context.mounted) {
                await ref
                    .read(employeeWorkspaceProvider.notifier)
                    .load(
                      selectedMonth:
                          '${date.year}-${date.month.toString().padLeft(2, '0')}',
                    );
              }
            },
          ),
        ],
      ),
      body: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Не удалось открыть кадровые данные. Проверьте подключение и привязку учётной записи к сотруднику.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          () =>
                              ref
                                  .read(employeeWorkspaceProvider.notifier)
                                  .load(),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
        data:
            (data) => RefreshIndicator(
              onRefresh:
                  () => ref.read(employeeWorkspaceProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    data.employeeName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Табельный номер: ${data.personnelNumber}'),
                  const SizedBox(height: 16),
                  Text(
                    'Подтверждённое время',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (data.periods.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'За выбранный месяц пока нет утверждённых табелей.',
                      ),
                    ),
                  ...data.periods.map(
                    (period) => Card(
                      child: ExpansionTile(
                        subtitle:
                            period.contractNumber == null
                                ? null
                                : Text('Договор №${period.contractNumber}'),
                        title: Text(
                          'Табель №${period.id} — ${period.status == 'closed' ? 'закрыт' : 'утверждён'}',
                        ),
                        children:
                            period.days
                                .map(
                                  (day) => ListTile(
                                    title: Text(day.date),
                                    subtitle: Text(
                                      'План: ${(day.plannedMinutes / 60).toStringAsFixed(2)} ч',
                                    ),
                                    trailing: Text(
                                      'Факт: ${(day.factMinutes / 60).toStringAsFixed(2)} ч',
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Мои документы',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (data.documents.isEmpty)
                    const ListTile(title: Text('Документов пока нет')),
                  ...data.documents.map(
                    (document) => Card(
                      child: ListTile(
                        title: Text(document.title),
                        subtitle: Text(
                          document.evidenceKind == 'paper_signed'
                              ? 'Бумажная подпись учтена'
                              : 'Без подтверждённой подписи',
                        ),
                        trailing: IconButton(
                          tooltip: 'Открыть документ',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () async {
                            try {
                              final uri = await ref
                                  .read(employeeWorkspaceProvider.notifier)
                                  .download(document.id);
                              if (context.mounted &&
                                  !await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  ) &&
                                  context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Не удалось открыть документ.',
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Не удалось загрузить документ.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Мои заявки',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (ref
                      .read(permissionServiceProvider)
                      .hasPermission('workforce.self-service.request'))
                    FilledButton.icon(
                      onPressed:
                          () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const _EmployeeRequestSheet(),
                          ),
                      icon: const Icon(Icons.add),
                      label: const Text('Подать заявку'),
                    ),
                  if (data.requests.isEmpty)
                    const ListTile(title: Text('Заявок пока нет')),
                  ...data.requests.map((request) => _RequestCard(request)),
                  if (data.requests.isNotEmpty)
                    TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => const _EmployeeRequestArchiveScreen(),
                            ),
                          ),
                      child: const Text('Все заявки'),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(this.request);
  final EmployeeRequestModel request;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(
        request.kind == 'absence' ? 'Отсутствие' : 'Исправление явки',
      ),
      subtitle: Text(
        '${request.dateFrom} — ${request.dateTo}\n${request.basis}\n${switch (request.status) {
          'submitted' => 'На рассмотрении руководителя',
          'awaiting_hr' => 'На проверке кадровой службы',
          'fulfilled' => 'Принято кадровой службой',
          'rejected' => 'Отклонено',
          _ => 'Статус уточняется',
        }}${request.managerBasis == null ? '' : '\nРуководитель: ${request.managerBasis}'}${request.hrBasis == null ? '' : '\nКадровая служба: ${request.hrBasis}'}',
      ),
    ),
  );
}

class _EmployeeRequestSheet extends ConsumerStatefulWidget {
  const _EmployeeRequestSheet();
  @override
  ConsumerState<_EmployeeRequestSheet> createState() =>
      _EmployeeRequestSheetState();
}

class _EmployeeRequestSheetState extends ConsumerState<_EmployeeRequestSheet> {
  final _form = GlobalKey<FormState>();
  final _basis = TextEditingController();
  final _hours = TextEditingController();
  final _key = _requestKey();
  String _kind = 'absence';
  String _absence = 'vacation';
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _sending = false;
  String? _error;
  bool _retryLocked = false;
  @override
  void dispose() {
    _basis.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Заявка сотрудника',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Заявка не заменяет кадровый документ или юридическую подпись. Окончательное решение принимает кадровая служба.',
            ),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Вид заявки'),
              items: const [
                DropdownMenuItem(value: 'absence', child: Text('Отсутствие')),
                DropdownMenuItem(
                  value: 'correction',
                  child: Text('Исправление явки'),
                ),
              ],
              onChanged:
                  (_sending || _retryLocked)
                      ? null
                      : (value) => setState(() {
                        _kind = value!;
                        if (_kind == 'correction') {
                          _to = _from;
                        }
                      }),
            ),
            if (_kind == 'absence')
              DropdownButtonFormField<String>(
                initialValue: _absence,
                decoration: const InputDecoration(
                  labelText: 'Причина отсутствия',
                ),
                items: const [
                  DropdownMenuItem(value: 'vacation', child: Text('Отпуск')),
                  DropdownMenuItem(
                    value: 'sick_leave',
                    child: Text('Больничный'),
                  ),
                  DropdownMenuItem(
                    value: 'unpaid_leave',
                    child: Text('Без сохранения зарплаты'),
                  ),
                  DropdownMenuItem(
                    value: 'absence',
                    child: Text('Другое отсутствие'),
                  ),
                ],
                onChanged:
                    (_sending || _retryLocked)
                        ? null
                        : (value) => setState(() => _absence = value!),
              ),
            ListTile(
              title: Text('С ${_date(_from)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: (_sending || _retryLocked) ? null : () => _pickDate(true),
            ),
            if (_kind == 'absence')
              ListTile(
                title: Text('По ${_date(_to)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap:
                    (_sending || _retryLocked) ? null : () => _pickDate(false),
              ),
            if (_kind == 'correction')
              TextFormField(
                controller: _hours,
                enabled: !_sending && !_retryLocked,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Отработанные часы',
                ),
                validator: (value) {
                  final hours = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  return hours == null || hours < 0 || hours > 24
                      ? 'Укажите от 0 до 24 часов.'
                      : null;
                },
              ),
            TextFormField(
              controller: _basis,
              enabled: !_sending && !_retryLocked,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Обоснование'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Укажите обоснование.'
                          : null,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? 'Отправка…' : 'Подать заявку'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickDate(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: start ? DateTime(2020) : _from,
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (date != null && mounted) {
      setState(() {
        if (start) {
          _from = date;
          if (_to.isBefore(date) || _kind == 'correction') {
            _to = date;
          }
        } else {
          _to = date;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _sending = true;
      _retryLocked = true;
      _error = null;
    });
    try {
      await ref
          .read(employeeWorkspaceProvider.notifier)
          .submit(
            idempotencyKey: _key,
            kind: _kind,
            dateFrom: _date(_from),
            dateTo: _date(_to),
            basis: _basis.text.trim(),
            requestedData:
                _kind == 'absence'
                    ? {'absence_type_code': _absence}
                    : {
                      'status': 'at_work',
                      'hours': double.parse(_hours.text.replaceAll(',', '.')),
                    },
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Не удалось подать заявку. Повторите отправку.';
        });
      }
    }
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _requestKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _EmployeeRequestArchiveScreen extends ConsumerWidget {
  const _EmployeeRequestArchiveScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('История моих заявок')),
    body: ref
        .watch(employeeRequestsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (_, _) => Center(
                child: FilledButton(
                  onPressed:
                      () => ref.read(employeeRequestsProvider.notifier).load(),
                  child: const Text('Повторить загрузку заявок'),
                ),
              ),
          data:
              (page) => Column(
                children: [
                  Expanded(
                    child:
                        page.requests.isEmpty
                            ? const Center(child: Text('Заявок пока нет'))
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: page.requests.length,
                              itemBuilder:
                                  (_, index) =>
                                      _RequestCard(page.requests[index]),
                            ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Предыдущая страница',
                            icon: const Icon(Icons.chevron_left),
                            onPressed:
                                page.currentPage > 1
                                    ? () => ref
                                        .read(employeeRequestsProvider.notifier)
                                        .load(page: page.currentPage - 1)
                                    : null,
                          ),
                          Expanded(
                            child: Text(
                              'Страница ${page.currentPage} из ${page.lastPage}. Всего: ${page.total}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Следующая страница',
                            icon: const Icon(Icons.chevron_right),
                            onPressed:
                                page.currentPage < page.lastPage
                                    ? () => ref
                                        .read(employeeRequestsProvider.notifier)
                                        .load(page: page.currentPage + 1)
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        ),
  );
}
