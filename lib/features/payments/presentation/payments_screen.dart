import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/payment_document_model.dart';
import '../data/payments_repository.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _items = <PaymentDocumentModel>[];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  int? _projectId;
  bool _canCreate = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectsProvider).selectedProject;
    final id = project?.serverId;
    if (_projectId != id && !_loading) {
      _projectId = id;
      _items.clear();
      _page = 1;
      _canCreate = false;
      if (id != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Финансовые документы'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: id == null ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton:
          id == null || !_canCreate
              ? null
              : FloatingActionButton.extended(
                onPressed: () => _create(id),
                icon: const Icon(Icons.add),
                label: const Text('Документ'),
              ),
      body:
          id == null
              ? const Center(child: Text('Выберите объект'))
              : _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _items.isEmpty
              ? _ErrorPanel(message: _error!, retry: () => _load(reset: true))
              : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    if (_error != null)
                      _ErrorPanel(
                        message: _error!,
                        retry: () => _load(reset: true),
                      ),
                    if (_items.isEmpty && !_loading)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(
                          child: Text('Финансовые документы не найдены'),
                        ),
                      ),
                    for (final item in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ProCard(
                          onTap: () => _open(item.id),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.status}${item.amount.isEmpty ? '' : ' · ${item.amount}'}',
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    if (_page <= _lastPage)
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _loadMore,
                          child: Text(_loading ? 'Загрузка…' : 'Загрузить ещё'),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Future<void> _load({bool reset = false}) async {
    final id = _projectId;
    if (id == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });
    try {
      final result = await ref
          .read(paymentsRepositoryProvider)
          .list(projectId: id, page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _canCreate = result.canCreate;
        _lastPage = result.lastPage;
        _page = result.currentPage + 1;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _loadMore() => _load();
  Future<void> _open(int id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaymentDocumentDetailScreen(id: id)),
    );
    if (changed == true) _load(reset: true);
  }

  Future<void> _create(int projectId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentDocumentFormScreen(projectId: projectId),
      ),
    );
    if (changed == true) _load(reset: true);
  }
}

class PaymentDocumentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDocumentDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<PaymentDocumentDetailScreen> createState() =>
      _PaymentDocumentDetailScreenState();
}

class _PaymentDocumentDetailScreenState
    extends ConsumerState<PaymentDocumentDetailScreen> {
  PaymentDocumentModel? _document;
  String? _error;
  bool _busy = false;
  DateTime _paymentDate = DateTime.now();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String _paymentMethod = 'bank_transfer';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await ref
          .read(paymentsRepositoryProvider)
          .detail(widget.id);
      if (mounted) {
        setState(() {
          _document = value;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    return Scaffold(
      appBar: AppBar(title: const Text('Документ')),
      body:
          _error != null && doc == null
              ? _ErrorPanel(message: _error!, retry: _load)
              : doc == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(doc.status),
                        for (final row in _displayValues(doc.values))
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('${row.key}: ${row.value}'),
                          ),
                      ],
                    ),
                  ),
                  if (doc.canEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _edit(doc),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Изменить'),
                      ),
                    ),
                  if (doc.canSubmit)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: const Text('Отправить на согласование'),
                      ),
                    ),
                  if (doc.canApprove || doc.canReject)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (doc.canApprove)
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _decide(true),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Согласовать'),
                            ),
                          if (doc.canReject)
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _decide(false),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Отклонить'),
                            ),
                        ],
                      ),
                    ),
                  if (doc.canRegisterPayment)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: ProCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Зафиксировать оплату',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Сумма',
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: _paymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'Способ оплаты',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Наличные'),
                                ),
                                DropdownMenuItem(
                                  value: 'bank_transfer',
                                  child: Text('Банковский перевод'),
                                ),
                                DropdownMenuItem(
                                  value: 'card',
                                  child: Text('Карта'),
                                ),
                                DropdownMenuItem(
                                  value: 'online',
                                  child: Text('Онлайн'),
                                ),
                                DropdownMenuItem(
                                  value: 'offset',
                                  child: Text('Взаимозачёт'),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Text('Другое'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _paymentMethod = value);
                                }
                              },
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Дата оплаты'),
                              subtitle: Text(_dateLabel(_paymentDate)),
                              trailing: const Icon(
                                Icons.calendar_month_outlined,
                              ),
                              onTap: _busy ? null : _pickPaymentDate,
                            ),
                            TextField(
                              controller: _reference,
                              decoration: const InputDecoration(
                                labelText: 'Номер подтверждения',
                              ),
                            ),
                            TextField(
                              controller: _notes,
                              decoration: const InputDecoration(
                                labelText: 'Комментарий',
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _busy ? null : _registerPayment,
                              child: const Text('Сохранить оплату'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ErrorPanel(message: _error!, retry: _load),
                    ),
                ],
              ),
    );
  }

  Future<void> _submit() async {
    if (!await _hasNetwork()) {
      setState(() => _error = 'Для отправки подключитесь к интернету.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(paymentsRepositoryProvider).submit(widget.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _decide(bool approve) async {
    var draft = '';
    final comment = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              approve ? 'Согласовать документ' : 'Отклонить документ',
            ),
            content: TextField(
              onChanged: (value) => draft = value,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: approve ? 'Комментарий' : 'Причина отклонения',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, draft.trim()),
                child: Text(approve ? 'Согласовать' : 'Отклонить'),
              ),
            ],
          ),
    );
    if (!mounted || comment == null) {
      return;
    }
    if (!approve && comment.length < 3) {
      setState(() => _error = 'Укажите причину отклонения');
      return;
    }
    if (!await _hasNetwork()) {
      if (mounted) {
        setState(() => _error = 'Для решения подключитесь к интернету.');
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .decide(widget.id, approve: approve, comment: comment);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _registerPayment() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Укажите сумму больше нуля');
      return;
    }
    if (!await _hasNetwork()) {
      setState(() => _error = 'Для фиксации оплаты подключитесь к интернету.');
      return;
    }
    final payload = {
      'amount': amount,
      'payment_method': _paymentMethod,
      'reference_number': _reference.text.trim(),
      'transaction_date': _dateKey(_paymentDate),
      'notes': _notes.text.trim(),
    };
    final fingerprint = jsonEncode({
      'user_id': ref.read(authProvider).user?.serverId,
      'document_id': widget.id,
      ...payload,
    });
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final storage = ref.read(secureStorageProvider);
      final paymentKey = await storage.getOrCreateOperationKey(
        namespace: 'payment-document-register-payment',
        fingerprint: fingerprint,
      );
      await ref
          .read(paymentsRepositoryProvider)
          .registerPayment(widget.id, payload, idempotencyKey: paymentKey);
      await storage.clearOperationKey(
        namespace: 'payment-document-register-payment',
        fingerprint: fingerprint,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _pickPaymentDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null && mounted) {
      setState(() => _paymentDate = selected);
    }
  }

  Future<void> _edit(PaymentDocumentModel doc) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => PaymentDocumentFormScreen(
              projectId: _projectId(doc.values),
              document: doc,
            ),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }
}

class PaymentDocumentFormScreen extends ConsumerStatefulWidget {
  const PaymentDocumentFormScreen({
    super.key,
    required this.projectId,
    this.document,
  });
  final int projectId;
  final PaymentDocumentModel? document;
  @override
  ConsumerState<PaymentDocumentFormScreen> createState() =>
      _PaymentDocumentFormScreenState();
}

class _PaymentDocumentFormScreenState
    extends ConsumerState<PaymentDocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _purpose = TextEditingController(
    text: '${widget.document?.values['payment_purpose'] ?? ''}',
  );
  late final _amount = TextEditingController(
    text: '${widget.document?.values['amount'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.document?.values['description'] ?? ''}',
  );
  bool _busy = false;
  String? _error;
  DateTime _documentDate = DateTime.now();
  @override
  void dispose() {
    _purpose.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.document == null ? 'Новый документ' : 'Изменить документ',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _purpose,
            decoration: const InputDecoration(labelText: 'Назначение'),
            validator:
                (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Заполните назначение'
                        : null,
          ),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Сумма'),
            validator:
                (v) =>
                    double.tryParse((v ?? '').replaceAll(',', '.')) == null
                        ? 'Укажите сумму'
                        : null,
          ),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Комментарий'),
            maxLines: 3,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Дата документа'),
            subtitle: Text(_dateLabel(_documentDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _busy ? null : _pickDocumentDate,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Сохраняем…' : 'Сохранить'),
          ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _hasNetwork()) {
      setState(() => _error = 'Для сохранения подключитесь к интернету.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final values = {
      'project_id': widget.projectId,
      'document_type':
          widget.document?.values['document_type'] ?? 'payment_order',
      'amount': double.parse(_amount.text.replaceAll(',', '.')),
      'payment_purpose': _purpose.text.trim(),
      'description': _description.text.trim(),
      'document_date': _dateKey(_documentDate),
    };
    try {
      final repo = ref.read(paymentsRepositoryProvider);
      if (widget.document == null) {
        final fingerprint = jsonEncode({
          'user_id': ref.read(authProvider).user?.serverId,
          ...values,
        });
        final storage = ref.read(secureStorageProvider);
        final key = await storage.getOrCreateOperationKey(
          namespace: 'payment-document-create',
          fingerprint: fingerprint,
        );
        await repo.create(values, idempotencyKey: key);
        await storage.clearOperationKey(
          namespace: 'payment-document-create',
          fingerprint: fingerprint,
        );
      } else {
        await repo.update(widget.document!.id, values);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _pickDocumentDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null && mounted) {
      setState(() => _documentDate = selected);
    }
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(onPressed: retry, child: const Text('Повторить')),
      ],
    ),
  );
}

List<MapEntry<String, String>> _displayValues(Map<String, dynamic> values) {
  const labels = {
    'amount': 'Сумма',
    'payment_purpose': 'Назначение',
    'description': 'Комментарий',
    'document_date': 'Дата документа',
    'due_date': 'Срок оплаты',
    'direction': 'Направление',
    'invoice_type': 'Тип счета',
  };
  return labels.entries
      .where((e) => values[e.key] != null && '${values[e.key]}'.isNotEmpty)
      .map((e) => MapEntry(e.value, '${values[e.key]}'))
      .toList();
}

int _projectId(Map<String, dynamic> values) {
  final value = values['project_id'];
  return value is int ? value : int.tryParse('$value') ?? 0;
}

String _message(Object error) =>
    error is ApiException
        ? error.message
        : 'Не удалось выполнить операцию. Проверьте связь и повторите.';

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

Future<bool> _hasNetwork() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}
