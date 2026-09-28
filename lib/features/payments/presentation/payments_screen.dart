import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        title: Text(
          MediaQuery.sizeOf(context).width < 390 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.15
              ? 'Документы'
              : 'Финансовые документы',
        ),
        actions: [
          if (id != null && _canCreate)
            IconButton(
              tooltip: 'Создать документ',
              onPressed: () => _create(id),
              icon: const Icon(Icons.add_rounded),
            ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: id == null ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                        for (final row in doc.detailValues)
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
                              key: const ValueKey('payment-register-amount'),
                              controller: _amount,
                              enabled: !_busy,
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
                              onChanged:
                                  _busy
                                      ? null
                                      : (value) {
                                        if (value != null) {
                                          setState(
                                            () => _paymentMethod = value,
                                          );
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
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'Номер подтверждения',
                              ),
                            ),
                            TextField(
                              controller: _notes,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'Комментарий',
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const ValueKey('payment-register-submit'),
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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _hasNetwork()) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'Для отправки подключитесь к интернету.';
          });
        }
        return;
      }
      if (!mounted) return;
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
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => _PaymentDecisionDialog(
            approve: approve,
            onSubmit: (comment) async {
              if (_busy) return 'Дождитесь завершения операции.';
              setState(() {
                _busy = true;
                _error = null;
              });
              try {
                if (!await _hasNetwork()) {
                  return 'Для решения подключитесь к интернету.';
                }
                if (!mounted) return 'Экран документа закрыт.';
                await ref
                    .read(paymentsRepositoryProvider)
                    .decide(widget.id, approve: approve, comment: comment);
                return null;
              } catch (exception) {
                return _message(exception);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
    );
    if (confirmed == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _registerPayment() async {
    if (_busy) return;
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Укажите сумму больше нуля');
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
      if (!await _hasNetwork()) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'Для фиксации оплаты подключитесь к интернету.';
          });
        }
        return;
      }
      if (!mounted) return;
      final storage = ref.read(secureStorageProvider);
      final paymentKey = await storage.getOrCreateOperationKey(
        namespace: 'payment-document-register-payment',
        fingerprint: fingerprint,
      );
      await ref
          .read(paymentsRepositoryProvider)
          .registerPayment(widget.id, payload, idempotencyKey: paymentKey);
      try {
        await storage.clearOperationKey(
          namespace: 'payment-document-register-payment',
          fingerprint: fingerprint,
        );
      } catch (_) {}
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
  late final _bankAccount = TextEditingController(
    text: '${_bankDetails['account'] ?? ''}',
  );
  late final _bankBik = TextEditingController(
    text: '${_bankDetails['bik'] ?? ''}',
  );
  final _partySearch = TextEditingController();
  List<PaymentPartyOption> _contractors = [];
  PaymentPartyOption? _currentOrganization;
  PaymentPartyOption? _payer;
  PaymentPartyOption? _payee;
  int _contractorPage = 1;
  int _contractorLastPage = 1;
  int _optionsRetryPage = 1;
  bool _optionsRetryAppend = false;
  int _searchRequest = 0;
  Timer? _searchDebounce;
  bool _optionsLoading = true;
  bool _optionsLoadingMore = false;
  String? _optionsError;
  bool _busy = false;
  String? _error;
  late DateTime _documentDate =
      DateTime.tryParse('${widget.document?.values['document_date'] ?? ''}') ??
      DateTime.now();

  Map<String, dynamic> get _bankDetails {
    final raw = widget.document?.values['bank_details'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _purpose.dispose();
    _amount.dispose();
    _description.dispose();
    _bankAccount.dispose();
    _bankBik.dispose();
    _partySearch.dispose();
    super.dispose();
  }

  Future<void> _loadOptions({int page = 1, bool append = false}) async {
    if (!mounted || (append && _optionsLoadingMore)) return;
    final request = ++_searchRequest;
    if (mounted) {
      setState(() {
        _optionsLoading = !append;
        _optionsLoadingMore = append;
        _optionsError = null;
        if (!append) {
          _contractors = [];
          _contractorPage = 1;
          _contractorLastPage = 1;
        }
      });
    }
    try {
      final options = await ref
          .read(paymentsRepositoryProvider)
          .formOptions(
            projectId: widget.projectId,
            search: _partySearch.text,
            page: page,
          );
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _currentOrganization = options.currentOrganization;
        _contractors =
            append
                ? [..._contractors, ...options.contractors.items]
                : options.contractors.items;
        _contractorPage = options.contractors.currentPage;
        _contractorLastPage = options.contractors.lastPage;
        _optionsLoading = false;
        _optionsLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _optionsLoading = false;
        _optionsLoadingMore = false;
        _optionsError = _message(error);
        _optionsRetryPage = page;
        _optionsRetryAppend = append;
      });
    }
  }

  void _searchParties(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _searchRequest++;
      _optionsLoading = true;
      _optionsLoadingMore = false;
      _optionsError = null;
      _contractors = [];
      _contractorPage = 1;
      _contractorLastPage = 1;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadOptions(),
    );
  }

  List<PaymentPartyOption> _partyChoices(PaymentPartyOption? selected) {
    final choices = <PaymentPartyOption>[
      if (_currentOrganization != null) _currentOrganization!,
      ..._contractors,
    ];
    if (selected != null) {
      choices.removeWhere((item) => item.key == selected.key);
      choices.add(selected);
    }
    return choices;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.document == null ? 'Новый документ' : 'Изменить документ',
      ),
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('payment-purpose'),
                controller: _purpose,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Назначение'),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Заполните назначение'
                            : null,
              ),
              TextFormField(
                key: const ValueKey('payment-amount'),
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Сумма'),
                validator:
                    (v) =>
                        (double.tryParse((v ?? '').replaceAll(',', '.')) ??
                                    0) <=
                                0
                            ? 'Укажите сумму больше нуля'
                            : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Стороны платежа',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.document != null) ...[
                Text(
                  'Сохранённый плательщик: ${widget.document!.values['payer_name'] ?? 'не указан'}',
                ),
                Text(
                  'Сохранённый получатель: ${widget.document!.values['payee_name'] ?? 'не указан'}',
                ),
                const Text(
                  'Если сторону не менять, она останется как в документе.',
                ),
              ],
              if (_optionsLoading || _optionsLoadingMore)
                const LinearProgressIndicator(),
              if (_optionsError != null) ...[
                Text(
                  _optionsError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton.icon(
                  onPressed:
                      _busy || _optionsLoading || _optionsLoadingMore
                          ? null
                          : () => _loadOptions(
                            page: _optionsRetryPage,
                            append: _optionsRetryAppend,
                          ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить загрузку сторон'),
                ),
              ] else if (!_optionsLoading &&
                  !_optionsLoadingMore &&
                  _contractors.isEmpty)
                const Text('Контрагенты не найдены.'),
              _partyDropdown(
                key: const ValueKey('payment-payer'),
                label: 'Плательщик',
                selected: _payer,
                choices: _partyChoices(_payer),
                existingName: '${widget.document?.values['payer_name'] ?? ''}',
                onChanged: (value) => setState(() => _payer = value),
              ),
              _partyDropdown(
                key: const ValueKey('payment-payee'),
                label: 'Получатель',
                selected: _payee,
                choices: _partyChoices(_payee),
                existingName: '${widget.document?.values['payee_name'] ?? ''}',
                onChanged: (value) => setState(() => _payee = value),
              ),
              TextField(
                key: const ValueKey('payment-party-search'),
                controller: _partySearch,
                enabled: !_busy,
                onChanged: _searchParties,
                decoration: const InputDecoration(
                  labelText: 'Найти контрагента',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              if (_contractorPage < _contractorLastPage)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        _optionsLoading || _optionsLoadingMore || _busy
                            ? null
                            : () => _loadOptions(
                              page: _contractorPage + 1,
                              append: true,
                            ),
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      _optionsLoadingMore ? 'Загрузка…' : 'Ещё контрагенты',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Банковские реквизиты',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextFormField(
                key: const ValueKey('payment-bank-account'),
                controller: _bankAccount,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Расчётный счёт (20 цифр)',
                ),
                validator:
                    (value) =>
                        RegExp(r'^\d{20}$').hasMatch(value ?? '')
                            ? null
                            : 'Введите 20 цифр расчётного счёта',
              ),
              TextFormField(
                key: const ValueKey('payment-bank-bik'),
                controller: _bankBik,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 9,
                decoration: const InputDecoration(labelText: 'БИК (9 цифр)'),
                validator:
                    (value) =>
                        RegExp(r'^\d{9}$').hasMatch(value ?? '')
                            ? null
                            : 'Введите 9 цифр БИК',
              ),
              TextFormField(
                controller: _description,
                enabled: !_busy,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('payment-document-save'),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Сохраняем…' : 'Сохранить'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _partyDropdown({
    required Key key,
    required String label,
    required PaymentPartyOption? selected,
    required List<PaymentPartyOption> choices,
    required String existingName,
    required ValueChanged<PaymentPartyOption?> onChanged,
  }) => DropdownButtonFormField<PaymentPartyOption>(
    key: key,
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      helperText:
          widget.document == null
              ? 'Выберите организацию или контрагента'
              : 'Без выбора сохранится: ${existingName.isEmpty ? 'текущее значение' : existingName}',
    ),
    items:
        choices
            .map(
              (party) => DropdownMenuItem(
                value: party,
                child: Text(
                  '${party.type == 'organization' ? 'Организация' : 'Контрагент'}: ${party.label}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
    validator:
        widget.document == null && selected == null
            ? (_) => 'Выберите $label в списке'
            : null,
    onChanged:
        _busy || _optionsLoading || _optionsLoadingMore ? null : onChanged,
  );
  Future<void> _save() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    if (widget.document == null &&
        (_optionsLoading ||
            _optionsError != null ||
            _currentOrganization == null)) {
      setState(
        () => _error = 'Загрузите список сторон и повторите сохранение.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _hasNetwork()) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'Для сохранения подключитесь к интернету.';
          });
        }
        return;
      }
      if (!mounted) return;
      final values = {
        'project_id': widget.projectId,
        'document_type':
            widget.document?.values['document_type'] ?? 'payment_order',
        'amount': double.parse(_amount.text.replaceAll(',', '.')),
        'payment_purpose': _purpose.text.trim(),
        'description': _description.text.trim(),
        'document_date': _dateKey(_documentDate),
        'bank_account': _bankAccount.text.trim(),
        'bank_bik': _bankBik.text.trim(),
      };
      if (_payer != null) {
        final organizationKey =
            _payer!.type == 'organization'
                ? 'payer_organization_id'
                : 'payer_contractor_id';
        final contractorKey =
            organizationKey == 'payer_organization_id'
                ? 'payer_contractor_id'
                : 'payer_organization_id';
        values[organizationKey] = _payer!.id;
        values[contractorKey] = null;
      }
      if (_payee != null) {
        final organizationKey =
            _payee!.type == 'organization'
                ? 'payee_organization_id'
                : 'payee_contractor_id';
        final contractorKey =
            organizationKey == 'payee_organization_id'
                ? 'payee_contractor_id'
                : 'payee_organization_id';
        values[organizationKey] = _payee!.id;
        values[contractorKey] = null;
      }
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
        try {
          await storage.clearOperationKey(
            namespace: 'payment-document-create',
            fingerprint: fingerprint,
          );
        } catch (_) {}
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

class _PaymentDecisionDialog extends StatefulWidget {
  const _PaymentDecisionDialog({required this.approve, required this.onSubmit});

  final bool approve;
  final Future<String?> Function(String comment) onSubmit;

  @override
  State<_PaymentDecisionDialog> createState() => _PaymentDecisionDialogState();
}

class _PaymentDecisionDialogState extends State<_PaymentDecisionDialog> {
  final _comment = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.approve ? 'Согласовать документ' : 'Отклонить документ',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('payment-decision-comment'),
            controller: _comment,
            maxLines: 3,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: widget.approve ? 'Комментарий' : 'Причина отклонения',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(widget.approve ? 'Согласовать' : 'Отклонить'),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (_saving) return;
    final comment = _comment.text.trim();
    if (!widget.approve && comment.length < 3) {
      setState(
        () => _error = 'Укажите причину отклонения не короче 3 символов.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final error = await widget.onSubmit(comment);
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _saving = false;
          _error = error;
        });
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(error);
        });
      }
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
