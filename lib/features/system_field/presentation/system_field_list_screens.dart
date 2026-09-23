import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/pro_card.dart';
import '../data/system_field_repository.dart';
import 'system_field_detail_screen.dart';

typedef _PageLoader = Future<SystemFieldPage> Function(int page, String search);

class AccessRecertificationScreen extends ConsumerWidget {
  const AccessRecertificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    final canCampaigns = permissions.hasPermission(
      'access_recertification.campaigns.view',
    );
    final canReviews = permissions.hasPermission(
      'access_recertification.reviews.view',
    );
    if (!canCampaigns && !canReviews) {
      return const _NoAccessScreen(title: 'Пересмотр доступов');
    }
    final tabs = <Widget>[];
    final pages = <Widget>[];
    if (canCampaigns) {
      tabs.add(const Tab(text: 'Кампании'));
      pages.add(
        _PagedRecordsPane(
          title: 'Кампании пересмотра',
          loader:
              (page, search) => ref
                  .read(systemFieldRepositoryProvider)
                  .campaigns(page: page, search: search),
        ),
      );
    }
    if (canReviews) {
      tabs.add(const Tab(text: 'Мои проверки'));
      pages.add(
        _PagedRecordsPane(
          title: 'Назначенные мне доступы',
          isReview: true,
          canDecide: permissions.hasPermission(
            'access_recertification.reviews.decide',
          ),
          loader:
              (page, search) => ref
                  .read(systemFieldRepositoryProvider)
                  .myReviews(page: page, search: search),
          onDecision:
              (item, decision, fields) => ref
                  .read(systemFieldRepositoryProvider)
                  .decide(
                    uuid: Uri.encodeComponent('${item['uuid'] ?? item['id']}'),
                    decision: decision,
                    reason: fields['reason']!,
                    confirmation: decision != 'approve',
                    validUntil: fields['valid_until'],
                    revokeExecutorUserId: int.tryParse(
                      fields['revoke_executor_user_id'] ?? '',
                    ),
                    compensatingControls:
                        fields['compensating_controls']
                            ?.split('\n')
                            .where((value) => value.isNotEmpty)
                            .toList() ??
                        const [],
                  ),
        ),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Пересмотр доступов'),
          bottom: tabs.length > 1 ? TabBar(tabs: tabs) : null,
        ),
        body: tabs.length > 1 ? TabBarView(children: pages) : pages.single,
      ),
    );
  }
}

class RateCoefficientsScreen extends ConsumerStatefulWidget {
  const RateCoefficientsScreen({super.key});
  @override
  ConsumerState<RateCoefficientsScreen> createState() =>
      _RateCoefficientsScreenState();
}

class _RateCoefficientsScreenState
    extends ConsumerState<RateCoefficientsScreen> {
  String _appliesTo = 'general';

  @override
  Widget build(BuildContext context) {
    if (!ref
        .watch(permissionServiceProvider)
        .hasPermission('rate_coefficients.view')) {
      return const _NoAccessScreen(title: 'Коэффициенты');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Коэффициенты')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<String>(
              initialValue: _appliesTo,
              decoration: const InputDecoration(
                labelText: 'Применяется к',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('Общие')),
                DropdownMenuItem(
                  value: 'material_norms',
                  child: Text('Нормы материалов'),
                ),
                DropdownMenuItem(
                  value: 'work_costs',
                  child: Text('Стоимость работ'),
                ),
                DropdownMenuItem(
                  value: 'labor_hours',
                  child: Text('Трудозатраты'),
                ),
              ],
              onChanged:
                  (value) => setState(() => _appliesTo = value ?? 'general'),
            ),
          ),
          Expanded(
            child: _PagedRecordsPane(
              key: ValueKey(_appliesTo),
              title: 'Действующие коэффициенты',
              searchEnabled: false,
              loader:
                  (page, search) => ref
                      .read(systemFieldRepositoryProvider)
                      .currentCoefficients(page: page, appliesTo: _appliesTo),
            ),
          ),
        ],
      ),
    );
  }
}

class SystemEventsScreen extends ConsumerWidget {
  const SystemEventsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref
        .watch(permissionServiceProvider)
        .hasPermission('system-logs.system.view')) {
      return const _NoAccessScreen(title: 'Журнал системы');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Журнал системы')),
      body: _PagedRecordsPane(
        title: 'События',
        loader:
            (page, search) => ref
                .read(systemFieldRepositoryProvider)
                .events(page: page, search: search),
      ),
    );
  }
}

class _PagedRecordsPane extends StatefulWidget {
  const _PagedRecordsPane({
    super.key,
    required this.title,
    required this.loader,
    this.isReview = false,
    this.canDecide = false,
    this.searchEnabled = true,
    this.onDecision,
  });

  final String title;
  final _PageLoader loader;
  final bool isReview;
  final bool canDecide;
  final bool searchEnabled;
  final Future<Map<String, dynamic>> Function(
    Map<String, dynamic> item,
    String decision,
    Map<String, String> fields,
  )?
  onDecision;

  @override
  State<_PagedRecordsPane> createState() => _PagedRecordsPaneState();
}

class _PagedRecordsPaneState extends State<_PagedRecordsPane> {
  final _searchController = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  int _nextPage = 1;
  int _lastPage = 1;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => _load(reset: true),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (widget.searchEnabled)
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(reset: true),
            decoration: InputDecoration(
              hintText: 'Поиск',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Искать',
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.arrow_forward),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        if (widget.searchEnabled) const SizedBox(height: 12),
        if (_error != null && _items.isEmpty)
          _LoadError(message: _error!, retry: () => _load(reset: true))
        else ...[
          if (_error != null)
            _LoadError(message: _error!, retry: () => _load(reset: true)),
          if (_loading && _items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Записи не найдены')),
            )
          else
            for (final item in _items) _recordCard(item),
          if (_nextPage <= _lastPage)
            Center(
              child: TextButton(
                onPressed: _loading ? null : _loadMore,
                child: Text(_loading ? 'Загрузка…' : 'Загрузить ещё'),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _recordCard(Map<String, dynamic> item) {
    final title = _recordTitle(item);
    final subtitle = _recordSubtitle(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProCard(
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => SystemFieldDetailScreen(title: title, record: item),
              ),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(subtitle),
              ),
            if (widget.isReview && widget.canDecide && _pending(item))
              Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () => _decide(item, 'approve'),
                    child: const Text('Оставить доступ'),
                  ),
                  TextButton(
                    onPressed: () => _decide(item, 'revoke'),
                    child: const Text('Отозвать'),
                  ),
                  TextButton(
                    onPressed: () => _decide(item, 'exception'),
                    child: const Text('Исключение'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _nextPage = 1;
        _lastPage = 1;
      }
    });
    try {
      final result = await widget.loader(_nextPage, _searchController.text);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items.addAll(result.items);
        _nextPage = result.currentPage + 1;
        _lastPage = result.lastPage;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = _errorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() => _load();

  Future<void> _decide(Map<String, dynamic> item, String decision) async {
    final fields = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DecisionSheet(decision: decision),
    );
    if (fields == null || !mounted) return;
    try {
      await widget.onDecision!(item, decision, fields);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Решение сохранено')));
        await _load(reset: true);
      }
    } catch (error) {
      if (!mounted) return;
      final message =
          error is ApiException && error.statusCode == 409
              ? 'Запись уже изменилась. Обновите список и проверьте её статус.'
              : _errorMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _load(reset: true);
    }
  }
}

class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({required this.decision});
  final String decision;
  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _reason = TextEditingController();
  final _executor = TextEditingController();
  final _validUntil = TextEditingController();
  final _controls = TextEditingController();
  bool _confirmed = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _executor.dispose();
    _validUntil.dispose();
    _controls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revoke = widget.decision == 'revoke';
    final exception = widget.decision == 'exception';
    final confirmRequired = revoke || exception;
    final decisionTitle = switch (widget.decision) {
      'approve' => 'Оставить доступ',
      'revoke' => 'Отозвать доступ',
      _ => 'Оформить исключение',
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                decisionTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Причина *',
                  border: OutlineInputBorder(),
                ),
              ),
              if (revoke) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _executor,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID исполнителя отзыва *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (exception) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _validUntil,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Действует до (ГГГГ-ММ-ДД) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controls,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Меры контроля, по одной на строку *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (confirmRequired)
                CheckboxListTile(
                  value: _confirmed,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Подтверждаю это решение'),
                  onChanged:
                      (value) => setState(() => _confirmed = value ?? false),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _submit,
                child: const Text('Сохранить решение'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final executor = int.tryParse(_executor.text.trim());
    final controls =
        _controls.text
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
    final date = DateTime.tryParse(_validUntil.text.trim());
    if (_reason.text.trim().isEmpty ||
        ((widget.decision == 'revoke' || widget.decision == 'exception') &&
            !_confirmed) ||
        (widget.decision == 'revoke' && (executor == null || executor <= 0)) ||
        (widget.decision == 'exception' &&
            (date == null || controls.isEmpty))) {
      setState(
        () => _error = 'Заполните обязательные поля и подтвердите решение.',
      );
      return;
    }
    final fields = <String, String>{'reason': _reason.text.trim()};
    if (widget.decision == 'revoke') {
      fields['revoke_executor_user_id'] = '$executor';
    }
    if (widget.decision == 'exception') {
      fields['valid_until'] = _validUntil.text.trim();
      fields['compensating_controls'] = controls.join('\n');
    }
    Navigator.pop(context, fields);
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      TextButton(onPressed: retry, child: const Text('Повторить')),
    ],
  );
}

class _NoAccessScreen extends StatelessWidget {
  const _NoAccessScreen({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const Center(child: Text('Нет прав для просмотра этого раздела')),
  );
}

String _recordTitle(Map<String, dynamic> item) =>
    '${item['name'] ?? item['title'] ?? item['subject'] ?? item['event'] ?? item['action'] ?? item['code'] ?? 'Запись'}';
String _recordSubtitle(Map<String, dynamic> item) => [
  item['status'],
  item['risk_level'] ?? item['risk'],
  item['created_at'] ?? item['due_at'],
  item['value'],
].where((value) => value != null && '$value'.isNotEmpty).join(' · ');
bool _pending(Map<String, dynamic> item) =>
    !const {
      'decided',
      'closed',
      'approved',
      'revoked',
      'exception',
    }.contains('${item['status'] ?? ''}'.toLowerCase());
String _errorMessage(Object error) =>
    error is ApiException
        ? error.message
        : 'Не удалось загрузить данные. Проверьте соединение и повторите попытку.';
