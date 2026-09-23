import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/pro_card.dart';
import '../data/system_field_repository.dart';
import 'system_field_detail_screen.dart';

class OneCExchangeScreen extends ConsumerStatefulWidget {
  const OneCExchangeScreen({super.key});

  @override
  ConsumerState<OneCExchangeScreen> createState() => _OneCExchangeScreenState();
}

class _OneCExchangeScreenState extends ConsumerState<OneCExchangeScreen> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _status;
  final List<Map<String, dynamic>> _history = [];
  bool _loadingStatus = true;
  bool _loadingHistory = true;
  bool _retrying = false;
  String? _statusError;
  String? _historyError;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    final permissions = ref.read(permissionServiceProvider);
    if (permissions.hasPermission('one_c_exchange.view')) _loadStatus();
    if (permissions.hasPermission('one_c_exchange.history.view')) {
      _loadHistory(reset: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionServiceProvider);
    final canViewStatus = permissions.hasPermission('one_c_exchange.view');
    final canViewHistory = permissions.hasPermission(
      'one_c_exchange.history.view',
    );
    if (!canViewStatus && !canViewHistory) {
      return Scaffold(
        appBar: AppBar(title: const Text('Обмен с 1С')),
        body: const Center(child: Text('Нет прав для просмотра обмена с 1С')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Обмен с 1С'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () {
              if (canViewStatus) _loadStatus();
              if (canViewHistory) _loadHistory(reset: true);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (canViewStatus) ...[
            Text(
              'Состояние обмена',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _loadingStatus && _status == null
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
                : _statusError != null && _status == null
                ? _ErrorPanel(message: _statusError!, retry: _loadStatus)
                : ProCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Состояние: ${_value(_status?['last_run'] is Map ? (_status!['last_run'] as Map)['status'] : null) ?? 'Нет запусков'}',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Автоматический обмен: ${_status?['worker_enabled'] == true ? 'включён' : 'выключен'}',
                      ),
                      Text(
                        'Доступно ключей: ${_status?['active_tokens_count'] ?? 0} из ${_status?['tokens_count'] ?? 0}',
                      ),
                      if (_status?['manual_only'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Запуск доступен только вручную.'),
                        ),
                      if (_statusError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _statusError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
          ],
          if (canViewHistory) ...[
            const SizedBox(height: 24),
            Text(
              'История запусков',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadHistory(reset: true),
              decoration: InputDecoration(
                hintText: 'Поиск по истории',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Искать',
                  onPressed: () => _loadHistory(reset: true),
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_historyError != null && _history.isEmpty)
              _ErrorPanel(
                message: _historyError!,
                retry: () => _loadHistory(reset: true),
              )
            else ...[
              if (_historyError != null)
                _ErrorPanel(
                  message: _historyError!,
                  retry: () => _loadHistory(reset: true),
                ),
              if (_loadingHistory && _history.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Запуски не найдены')),
                )
              else
                for (final item in _history)
                  _historyCard(
                    item,
                    permissions.hasPermission('one_c_exchange.retry'),
                  ),
              if (_page <= _lastPage)
                Center(
                  child: TextButton(
                    onPressed: _loadingHistory ? null : _loadMore,
                    child: Text(
                      _loadingHistory ? 'Загрузка…' : 'Загрузить ещё',
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item, bool canRetry) {
    final errors = int.tryParse('${item['error_count'] ?? 0}') ?? 0;
    final status = '${item['status'] ?? '—'}';
    final id = item['id']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProCard(
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => SystemFieldDetailScreen(
                      title: 'Запуск обмена',
                      record: item,
                    ),
              ),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_direction(item['direction'])} · $status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 6),
            Text('${item['scope'] ?? 'Без области'} · ошибок: $errors'),
            if (item['started_at'] != null) Text('${item['started_at']}'),
            if (canRetry && errors > 0 && id != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _retrying ? null : () => _retry(id),
                  icon: const Icon(Icons.replay),
                  label: Text(_retrying ? 'Повторяем…' : 'Повторить обмен'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loadingStatus = true;
      _statusError = null;
    });
    try {
      final result = await ref.read(systemFieldRepositoryProvider).oneCStatus();
      if (mounted) {
        setState(() {
          _status = result;
          _loadingStatus = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusError = _message(error);
          _loadingStatus = false;
        });
      }
    }
  }

  Future<void> _loadHistory({bool reset = false}) async {
    if (_loadingHistory && !reset) {
      return;
    }
    setState(() {
      _loadingHistory = true;
      _historyError = null;
      if (reset) {
        _history.clear();
        _page = 1;
        _lastPage = 1;
      }
    });
    try {
      final result = await ref
          .read(systemFieldRepositoryProvider)
          .oneCHistory(page: _page, search: _searchController.text);
      if (mounted) {
        setState(() {
          _history.addAll(result.items);
          _page = result.currentPage + 1;
          _lastPage = result.lastPage;
          _loadingHistory = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _historyError = _message(error);
          _loadingHistory = false;
        });
      }
    }
  }

  Future<void> _loadMore() => _loadHistory();

  Future<void> _retry(String operationId) async {
    setState(() => _retrying = true);
    try {
      await ref.read(systemFieldRepositoryProvider).retryOneC(operationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Повторный обмен запущен')),
        );
        await _loadHistory(reset: true);
        if (mounted) await _loadStatus();
      }
    } catch (error) {
      if (!mounted) return;
      final message =
          error is ApiException && error.statusCode == 409
              ? 'Этот запуск больше нельзя повторить. Обновите историю.'
              : _message(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _loadHistory(reset: true);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.retry});
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

String? _value(dynamic value) => value == null ? null : '$value';
String _direction(dynamic value) => switch ('$value') {
  'import' => 'Импорт',
  'export' => 'Экспорт',
  _ => 'Обмен',
};
String _message(Object error) =>
    error is ApiException
        ? error.message
        : 'Не удалось загрузить данные. Проверьте соединение и повторите попытку.';
