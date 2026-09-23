import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/field_catalog_repository.dart';

class WorkforceCalendarScreen extends ConsumerStatefulWidget {
  const WorkforceCalendarScreen({super.key});

  @override
  ConsumerState<WorkforceCalendarScreen> createState() =>
      _WorkforceCalendarScreenState();
}

class _WorkforceCalendarScreenState
    extends ConsumerState<WorkforceCalendarScreen> {
  late DateTime _weekStart;
  late int? _loadedProjectId;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _weekStart = _monday(DateTime.now());
    _loadedProjectId = ref.read(projectsProvider).selectedProject?.serverId;
    _future = _load(_loadedProjectId);
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(
      projectsProvider.select((state) => state.selectedProject?.serverId),
    );
    if (projectId != _loadedProjectId) {
      _loadedProjectId = projectId;
      _future = _load(projectId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь состава'),
        actions: [
          IconButton(
            tooltip: 'Предыдущая неделя',
            onPressed: () => _changeWeek(-7, projectId),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Следующая неделя',
            onPressed: () => _changeWeek(7, projectId),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: 'Обновить календарь',
            onPressed: () => setState(() => _future = _load(projectId)),
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
                    'Календарь состава открывается для выбранного объекта.',
              )
              : FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const AppLoadingState(
                      message: 'Загружаем календарь',
                    );
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error!;
                    if (error is ApiException && error.statusCode == 403) {
                      return const AppPermissionState(
                        title: 'Календарь недоступен',
                        description:
                            'У вас нет прав на просмотр этого объекта.',
                      );
                    }
                    return AppErrorState(
                      title: 'Не удалось загрузить календарь',
                      description: UserMessage.fromError(error),
                      onRetry: () => setState(() => _future = _load(projectId)),
                    );
                  }
                  return _calendar(snapshot.requireData);
                },
              ),
    );
  }

  Widget _calendar(Map<String, dynamic> data) {
    final days = _list(data['days']);
    final employees = _list(data['employees']);
    final theme = Theme.of(context);

    if (employees.isEmpty) {
      return const AppEmptyState(
        icon: Icons.groups_outlined,
        title: 'Сотрудники не назначены',
        description:
            'Для выбранного объекта на эту неделю нет назначенного состава.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _future = _load(_loadedProjectId));
        await _future;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            '${_dateLabel(_weekStart)} — ${_dateLabel(_weekStart.add(const Duration(days: 6)))} · ${employees.length} сотрудников',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final employee in employees) ...[
            ProCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _string(employee['full_name'], 'Сотрудник'),
                    style: theme.textTheme.titleMedium,
                  ),
                  if (_string(employee['assignment_label'], '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _string(employee['assignment_label'], ''),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final day in days) ...[
                          _DayStatusCard(
                            day: day,
                            status: _map(
                              _map(employee['days'])[_string(day['date'], '')],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _load(int? projectId) {
    if (projectId == null) return Future.value(const {});
    final from = _weekStart;
    final to = from.add(const Duration(days: 6));
    return ref
        .read(fieldCatalogRepositoryProvider)
        .fetchPayload(
          path: '/field-admin/personnel/calendar',
          queryParameters: {
            'project_id': projectId,
            'date_from': _isoDate(from),
            'date_to': _isoDate(to),
          },
        );
  }

  void _changeWeek(int days, int? projectId) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: days));
      _future = _load(projectId);
    });
  }
}

class _DayStatusCard extends StatelessWidget {
  const _DayStatusCard({required this.day, required this.status});

  final Map<String, dynamic> day;
  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _string(status['status'], '');
    final color = switch (value) {
      'absence' => theme.colorScheme.error,
      'business_trip' => theme.colorScheme.tertiary,
      'work' => theme.colorScheme.primary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final hours = status['hours'];

    return Container(
      width: 78,
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_string(day['weekday'], ''), style: theme.textTheme.labelSmall),
          Text(_string(day['label'], ''), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            _string(status['status_label'], 'Нет данных'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hours is num && hours > 0)
            Text('${hours.toString()} ч', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

DateTime _monday(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}';

String _string(dynamic value, String fallback) =>
    value == null || value.toString().trim().isEmpty
        ? fallback
        : value.toString();

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) =>
    value is List
        ? value.whereType<Map>().map(_map).toList(growable: false)
        : const <Map<String, dynamic>>[];
