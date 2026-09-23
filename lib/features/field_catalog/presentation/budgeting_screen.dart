import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/user_message.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/budgeting_repository.dart';

class BudgetingScreen extends ConsumerStatefulWidget {
  const BudgetingScreen({super.key});

  @override
  ConsumerState<BudgetingScreen> createState() => _BudgetingScreenState();
}

class _BudgetingScreenState extends ConsumerState<BudgetingScreen> {
  int? _projectId;
  Future<Map<String, dynamic>>? _summaryFuture;
  BudgetExecutionPage? _cards;
  bool _loadingCards = true;
  bool _loadingMore = false;
  String? _cardsError;

  @override
  void initState() {
    super.initState();
    _projectId = ref.read(projectsProvider).selectedProject?.serverId;
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(
      projectsProvider.select((state) => state.selectedProject),
    );
    final projectId = project?.serverId;
    if (projectId != _projectId) {
      _projectId = projectId;
      Future.microtask(_load);
    }
    final allowed = ref
        .watch(permissionServiceProvider)
        .hasPermission('reports.project_control.view');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бюджетирование'),
        actions: [
          IconButton(
            tooltip: 'Обновить данные',
            onPressed: projectId == null || !allowed ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (project != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment_rounded),
                  title: Text(project.name),
                  subtitle: const Text('Исполнение по выбранному объекту'),
                ),
              ),
            if (projectId == null)
              const AppEmptyState(
                icon: Icons.apartment_outlined,
                title: 'Выберите объект',
                description: 'Сводка исполнения привязана к объекту.',
              )
            else if (!allowed)
              const AppPermissionState(
                title: 'Раздел недоступен',
                description:
                    'У вас нет права просматривать исполнение бюджета.',
              )
            else ...[
              if (_summaryFuture != null)
                FutureBuilder<Map<String, dynamic>>(
                  future: _summaryFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const AppLoadingState(message: 'Загружаем сводку');
                    }
                    if (snapshot.hasError) {
                      return AppErrorState(
                        title: 'Не удалось загрузить сводку',
                        description: UserMessage.fromError(snapshot.error!),
                        onRetry: _load,
                      );
                    }
                    return _summary(snapshot.requireData);
                  },
                ),
              const SizedBox(height: 16),
              Text(
                'Исполнение по разделам',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_loadingCards && _cards == null)
                const AppLoadingState(message: 'Загружаем разделы исполнения')
              else if (_cardsError != null && _cards == null)
                AppErrorState(
                  title: 'Не удалось загрузить исполнение',
                  description: _cardsError,
                  onRetry: _loadCards,
                )
              else if (_cards?.items.isEmpty ?? true)
                const AppEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'Данных исполнения пока нет',
                  description:
                      'Для объекта ещё не сформирован снимок исполнения.',
                )
              else ...[
                Text(
                  'Показано ${_cards!.items.length} из ${_cards!.total}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final card in _cards!.items) _executionCard(card),
                if (_cards!.currentPage < _cards!.lastPage)
                  OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon:
                        _loadingMore
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.expand_more_rounded),
                    label: Text(_loadingMore ? 'Загружаем' : 'Загрузить ещё'),
                  ),
                if (_cardsError != null)
                  Text(
                    'Не удалось загрузить следующую страницу: $_cardsError',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(Map<String, dynamic> summary) {
    final snapshot = _map(summary['snapshot']);
    final totals =
        summary['totals_by_currency'] is List
            ? (summary['totals_by_currency'] as List).whereType<Map>().map(_map)
            : const <Map<String, dynamic>>[];
    if (snapshot.isEmpty) {
      return const AppEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'Снимок исполнения не сформирован',
        description: 'Сводка появится после публикации снимка проекта.',
      );
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Сводка исполнения',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (snapshot['is_stale'] == true)
                  const Chip(label: Text('Устарела')),
              ],
            ),
            if (snapshot['status_date'] != null)
              Text('На дату ${snapshot['status_date']}'),
            for (final total in totals) ...[
              const Divider(height: 24),
              Text(
                (total['currency'] ?? '').toString(),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _metric('Бюджет (BAC)', total['bac_minor'], total['currency']),
              _metric('План (PV)', total['pv_minor'], total['currency']),
              _metric('Выполнено (EV)', total['ev_minor'], total['currency']),
              _metric('Отклонение (SV)', total['sv_minor'], total['currency']),
              _metric('Индекс графика (SPI)', total['spi']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _executionCard(Map<String, dynamic> item) {
    final currency = item['currency'];
    final theme = Theme.of(context);
    final wbs = (item['wbs_code'] ?? '').toString();
    final task = item['task_id']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (wbs.isNotEmpty) wbs,
                if (task != null) 'Задача $task',
              ].join(' · '),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _metric('Бюджет (BAC)', item['bac_minor'], currency),
            _metric('План (PV)', item['pv_minor'], currency),
            _metric('Выполнено (EV)', item['ev_minor'], currency),
            _metric('Отклонение (SV)', item['sv_minor'], currency),
            _metric('Индекс графика (SPI)', item['spi']),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, dynamic value, [dynamic currency]) {
    if (value == null) return const SizedBox.shrink();
    final text =
        value is num && currency is String
            ? NumberFormat.currency(
              locale: 'ru_RU',
              name: currency,
            ).format(value / 100)
            : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    final allowed = ref
        .read(permissionServiceProvider)
        .hasPermission('reports.project_control.view');
    if (projectId == null || !allowed) {
      setState(() {
        _cards = null;
        _summaryFuture = null;
        _loadingCards = false;
      });
      return;
    }
    setState(() {
      _projectId = projectId;
      _summaryFuture = ref
          .read(mobileBudgetingRepositoryProvider)
          .fetchSummary(projectId: projectId);
      _cards = null;
      _loadingCards = true;
      _cardsError = null;
    });
    await _loadCards();
  }

  Future<void> _loadCards() async {
    final projectId = _projectId;
    if (projectId == null ||
        !ref
            .read(permissionServiceProvider)
            .hasPermission('reports.project_control.view')) {
      return;
    }
    setState(() {
      _loadingCards = true;
      _cardsError = null;
    });
    try {
      final result = await ref
          .read(mobileBudgetingRepositoryProvider)
          .fetchExecutionCards(projectId: projectId);
      if (!mounted || projectId != _projectId) return;
      setState(() {
        _cards = result;
        _loadingCards = false;
      });
    } catch (error) {
      if (!mounted || projectId != _projectId) return;
      setState(() {
        _cardsError = UserMessage.fromError(error);
        _loadingCards = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final current = _cards;
    final projectId = _projectId;
    if (current == null || projectId == null || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _cardsError = null;
    });
    try {
      final next = await ref
          .read(mobileBudgetingRepositoryProvider)
          .fetchExecutionCards(
            projectId: projectId,
            page: current.currentPage + 1,
          );
      if (!mounted || current != _cards || projectId != _projectId) return;
      setState(() {
        _cards = BudgetExecutionPage(
          items: [...current.items, ...next.items],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        );
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _cardsError = UserMessage.fromError(error);
      });
    }
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}
