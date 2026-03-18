import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_scan_model.dart';
import '../data/warehouse_summary_model.dart';
import 'warehouse_task_execution_screen.dart';
import 'warehouse_task_helpers.dart';

class WarehouseTasksScreen extends ConsumerStatefulWidget {
  const WarehouseTasksScreen({
    super.key,
    required this.summary,
    this.initialWarehouseId,
    this.initialStatus,
    this.initialTaskType,
    this.initialEntityType,
    this.initialEntityId,
  });

  final WarehouseSummaryModel summary;
  final int? initialWarehouseId;
  final String? initialStatus;
  final String? initialTaskType;
  final String? initialEntityType;
  final int? initialEntityId;

  @override
  ConsumerState<WarehouseTasksScreen> createState() =>
      _WarehouseTasksScreenState();
}

class _WarehouseTasksScreenState extends ConsumerState<WarehouseTasksScreen> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  List<WarehouseTaskModel> _tasks = const <WarehouseTaskModel>[];
  int? _selectedWarehouseId;
  String? _selectedStatus;
  String? _selectedTaskType;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedWarehouseId =
        widget.initialWarehouseId ??
        widget.summary.warehouses.firstOrNull?.id;
    _selectedStatus = widget.initialStatus;
    _selectedTaskType = widget.initialTaskType;
    _loadTasks();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.summary.warehouses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи склада'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : () => _loadTasks(refreshOnly: true),
            icon:
                _isRefreshing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          warehouses.isEmpty
              ? const AppStateView(
                icon: Icons.task_alt_outlined,
                title: 'Нет активных складов',
                description:
                    'Очередь задач станет доступна, когда в организации появится хотя бы один склад.',
              )
              : RefreshIndicator(
                onRefresh: () => _loadTasks(refreshOnly: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _FiltersCard(
                      warehouses: warehouses,
                      selectedWarehouseId: _selectedWarehouseId,
                      selectedStatus: _selectedStatus,
                      selectedTaskType: _selectedTaskType,
                      searchController: _searchController,
                      onWarehouseChanged: (value) {
                        setState(() {
                          _selectedWarehouseId = value;
                        });
                        _loadTasks();
                      },
                      onStatusChanged: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                        _loadTasks();
                      },
                      onTaskTypeChanged: (value) {
                        setState(() {
                          _selectedTaskType = value;
                        });
                        _loadTasks();
                      },
                      onSearchChanged: (_) {
                        setState(() {});
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 350),
                          () => _loadTasks(),
                        );
                      },
                      onSearchSubmitted: (_) => _loadTasks(),
                      onSearchCleared: () {
                        _searchController.clear();
                        _loadTasks();
                      },
                    ),
                    if (widget.initialEntityType != null &&
                        widget.initialEntityId != null) ...[
                      const SizedBox(height: 12),
                      _ScanContextBanner(
                        entityType: widget.initialEntityType!,
                        entityId: widget.initialEntityId!,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_isLoading && _tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null && _tasks.isEmpty)
                      AppStateView(
                        icon: Icons.error_outline_rounded,
                        title: 'Не удалось загрузить задачи',
                        description: _error,
                        action: OutlinedButton(
                          onPressed: () => _loadTasks(),
                          child: const Text('Повторить'),
                        ),
                      )
                    else if (_tasks.isEmpty)
                      AppStateView(
                        icon: Icons.inventory_2_outlined,
                        title: 'Задач не найдено',
                        description: _emptyDescription,
                      )
                    else ...[
                      _QueueSummary(
                        tasksCount: _tasks.length,
                        queuedCount:
                            _tasks.where((task) => task.status == 'queued').length,
                        inProgressCount:
                            _tasks
                                .where((task) => task.status == 'in_progress')
                                .length,
                        blockedCount:
                            _tasks.where((task) => task.status == 'blocked').length,
                      ),
                      const SizedBox(height: 12),
                      ..._tasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaskCard(
                            task: task,
                            onDetails: () => _openTaskDetails(task),
                            onAction: (status) => _changeTaskStatus(task, status),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  String get _emptyDescription {
    final hasEntityFilter =
        widget.initialEntityType != null && widget.initialEntityId != null;

    if (hasEntityFilter) {
      return 'По текущему объекту сканирования задачи не найдены. Попробуйте сменить склад или тип операции.';
    }

    if ((_searchController.text).trim().isNotEmpty) {
      return 'Сбросьте строку поиска или поменяйте фильтры, чтобы увидеть другие задания.';
    }

    return 'Когда на складе появятся задания на приемку, размещение, перемещение или инвентаризацию, они появятся здесь.';
  }

  Future<void> _loadTasks({bool refreshOnly = false}) async {
    final warehouseId = _selectedWarehouseId;
    if (warehouseId == null) {
      return;
    }

    setState(() {
      if (refreshOnly) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final tasks = await ref.read(warehouseRepositoryProvider).fetchTasks(
        warehouseId,
        status: _selectedStatus,
        taskType: _selectedTaskType,
        entityType: widget.initialEntityType,
        entityId: widget.initialEntityId,
        query: _searchController.text.trim(),
        limit: 60,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _tasks = tasks;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('ApiException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _changeTaskStatus(
    WarehouseTaskModel task,
    String targetStatus,
  ) async {
    final warehouseId = _selectedWarehouseId;
    if (warehouseId == null) {
      _showMessage('Склад для выполнения задачи не выбран.');
      return;
    }

    final updatedTask = await Navigator.of(context).push<WarehouseTaskModel>(
      MaterialPageRoute(
        builder:
            (_) => WarehouseTaskExecutionScreen(
              summary: widget.summary,
              task: task,
              targetStatus: targetStatus,
              initialWarehouseId: warehouseId,
            ),
      ),
    );

    if (updatedTask == null || !mounted) {
      return;
    }

    try {
      await _loadTasks(refreshOnly: true);
      if (!mounted) {
        return;
      }
      _showMessage(
        'Статус задачи "${task.title}" обновлен: ${warehouseStatusLabel(targetStatus)}.',
      );
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _openTaskDetails(WarehouseTaskModel task) async {
    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TaskDetailsSheet(task: task),
    );

    if (selectedAction == null) {
      return;
    }

    await _changeTaskStatus(task, selectedAction);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('ApiException: ', ''))),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.warehouses,
    required this.selectedWarehouseId,
    required this.selectedStatus,
    required this.selectedTaskType,
    required this.searchController,
    required this.onWarehouseChanged,
    required this.onStatusChanged,
    required this.onTaskTypeChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
  });

  final List<WarehouseCardModel> warehouses;
  final int? selectedWarehouseId;
  final String? selectedStatus;
  final String? selectedTaskType;
  final TextEditingController searchController;
  final ValueChanged<int?> onWarehouseChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTaskTypeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Очередь исполнения',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: selectedWarehouseId,
            items:
                warehouses.map((warehouse) {
                  return DropdownMenuItem<int>(
                    value: warehouse.id,
                    child: Text(warehouse.name),
                  );
                }).toList(),
            onChanged: onWarehouseChanged,
            decoration: const InputDecoration(
              labelText: 'Склад',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
            decoration: InputDecoration(
              labelText: 'Поиск по номеру и названию',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                        onPressed: onSearchCleared,
                        icon: const Icon(Icons.close_rounded),
                      ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Статус', style: AppTypography.bodyMedium(context)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _statusFilters.map((filter) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selectedStatus == filter.value,
                        label: Text(filter.label),
                        onSelected: (_) => onStatusChanged(filter.value),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Тип операции', style: AppTypography.bodyMedium(context)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _taskTypeFilters.map((filter) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selectedTaskType == filter.value,
                        label: Text(filter.label),
                        onSelected: (_) => onTaskTypeChanged(filter.value),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanContextBanner extends StatelessWidget {
  const _ScanContextBanner({
    required this.entityType,
    required this.entityId,
  });

  final String entityType;
  final int entityId;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      backgroundColor: AppColors.secondary.withValues(alpha: 0.08),
      borderColor: AppColors.secondary.withValues(alpha: 0.2),
      child: Row(
        children: [
          Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Показаны задачи по объекту: ${warehouseEntityTypeLabel(entityType)} #$entityId',
              style: AppTypography.bodyMedium(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({
    required this.tasksCount,
    required this.queuedCount,
    required this.inProgressCount,
    required this.blockedCount,
  });

  final int tasksCount;
  final int queuedCount;
  final int inProgressCount;
  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryPill(
            label: 'Всего',
            value: tasksCount.toString(),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryPill(
            label: 'Очередь',
            value: queuedCount.toString(),
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryPill(
            label: 'В работе',
            value: inProgressCount.toString(),
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryPill(
            label: 'Блок',
            value: blockedCount.toString(),
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onDetails,
    required this.onAction,
  });

  final WarehouseTaskModel task;
  final VoidCallback onDetails;
  final Future<void> Function(String targetStatus) onAction;

  @override
  Widget build(BuildContext context) {
    final primaryAction = warehousePrimaryTaskAction(task);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.taskNumber} / ${warehouseTaskTypeLabel(task.taskType)}',
                      style: AppTypography.bodyMedium(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TaskBadge(
                label: warehouseStatusLabel(task.status),
                color: _statusColor(task.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TaskBadge(
                label: warehousePriorityLabel(task.priority),
                color: _priorityColor(task.priority),
              ),
              if (task.dueAt != null)
                _TaskBadge(
                  label: 'До ${warehouseFormatDateTime(task.dueAt!)}',
                  color: Colors.blueGrey,
                ),
              if (task.progressPercent != null)
                _TaskBadge(
                  label: 'Готово ${warehouseFormatNumber(task.progressPercent!)}%',
                  color: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _TaskContextLine(
            icon: Icons.place_outlined,
            values: [
              if (task.zone != null) task.zone!.name,
              if (task.cell != null) task.cell!.name,
              if (task.logisticUnit != null) task.logisticUnit!.name,
            ],
          ),
          _TaskContextLine(
            icon: Icons.inventory_2_outlined,
            values: [
              if (task.material != null) task.material!.name,
              if (task.plannedQuantity != null)
                'План ${warehouseFormatNumber(task.plannedQuantity!)}',
              if (task.completedQuantity != null)
                'Факт ${warehouseFormatNumber(task.completedQuantity!)}',
            ],
          ),
          if ((task.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.notes!,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onDetails,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Подробнее'),
              ),
              if (primaryAction != null)
                FilledButton.tonal(
                  onPressed: () => onAction(primaryAction),
                  child: Text(warehouseTaskActionLabel(primaryAction)),
                ),
              ...warehouseAllowedTaskActions(task)
                  .where((status) => status != primaryAction)
                  .map(
                    (status) => OutlinedButton(
                      onPressed: () => onAction(status),
                      child: Text(warehouseTaskActionLabel(status)),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskContextLine extends StatelessWidget {
  const _TaskContextLine({
    required this.icon,
    required this.values,
  });

  final IconData icon;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              values.join(' / '),
              style: AppTypography.bodyMedium(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskBadge extends StatelessWidget {
  const _TaskBadge({
    required this.label,
    required this.color,
  });

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

class _TaskDetailsSheet extends StatelessWidget {
  const _TaskDetailsSheet({required this.task});

  final WarehouseTaskModel task;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(task.title, style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Text(
            '${task.taskNumber} / ${warehouseTaskTypeLabel(task.taskType)}',
            style: AppTypography.bodyMedium(context),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Статус', value: warehouseStatusLabel(task.status)),
          _DetailRow(
            label: 'Приоритет',
            value: warehousePriorityLabel(task.priority),
          ),
          if (task.dueAt != null)
            _DetailRow(
              label: 'Срок',
              value: warehouseFormatDateTime(task.dueAt!),
            ),
          if (task.zone != null)
            _DetailRow(label: 'Зона', value: task.zone!.name),
          if (task.cell != null)
            _DetailRow(label: 'Ячейка', value: task.cell!.name),
          if (task.logisticUnit != null)
            _DetailRow(
              label: 'Логединица',
              value: task.logisticUnit!.name,
            ),
          if (task.material != null)
            _DetailRow(label: 'Материал', value: task.material!.name),
          if (task.plannedQuantity != null)
            _DetailRow(
              label: 'План',
              value: warehouseFormatNumber(task.plannedQuantity!),
            ),
          if (task.completedQuantity != null)
            _DetailRow(
              label: 'Факт',
              value: warehouseFormatNumber(task.completedQuantity!),
            ),
          if ((task.notes ?? '').trim().isNotEmpty)
            _DetailRow(label: 'Комментарий', value: task.notes!),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                warehouseAllowedTaskActions(task)
                    .map(
                      (status) => FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(status),
                        child: Text(warehouseTaskActionLabel(status)),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(context)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.bodyMedium(context)),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'queued' => Colors.blueGrey,
    'in_progress' => AppColors.secondary,
    'blocked' => AppColors.warning,
    'completed' => AppColors.success,
    'cancelled' => Colors.grey,
    _ => Colors.blueGrey,
  };
}

Color _priorityColor(String priority) {
  return switch (priority) {
    'critical' => AppColors.error,
    'high' => AppColors.warning,
    'normal' => AppColors.secondary,
    'low' => Colors.blueGrey,
    _ => Colors.blueGrey,
  };
}

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String? value;
  final String label;
}

const List<_FilterOption> _statusFilters = <_FilterOption>[
  _FilterOption(null, 'Все'),
  _FilterOption('queued', 'В очереди'),
  _FilterOption('in_progress', 'В работе'),
  _FilterOption('blocked', 'Блок'),
  _FilterOption('completed', 'Завершено'),
];

const List<_FilterOption> _taskTypeFilters = <_FilterOption>[
  _FilterOption(null, 'Все'),
  _FilterOption('receipt', 'Приемка'),
  _FilterOption('placement', 'Размещение'),
  _FilterOption('transfer', 'Перемещение'),
  _FilterOption('cycle_count', 'Инвентаризация'),
  _FilterOption('inspection', 'Проверка'),
];

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
