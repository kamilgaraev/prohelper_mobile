import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_scan_model.dart';
import '../data/warehouse_summary_model.dart';
import 'warehouse_scan_action_sheets.dart';
import 'warehouse_screen.dart';
import 'warehouse_task_execution_screen.dart';
import 'warehouse_task_helpers.dart';
import 'warehouse_tasks_screen.dart';

class WarehouseScanResultScreen extends ConsumerStatefulWidget {
  const WarehouseScanResultScreen({
    super.key,
    required this.initialResult,
    required this.summary,
    this.initialWarehouseId,
  });

  final WarehouseScanResultModel initialResult;
  final WarehouseSummaryModel summary;
  final int? initialWarehouseId;

  @override
  ConsumerState<WarehouseScanResultScreen> createState() =>
      _WarehouseScanResultScreenState();
}

class _WarehouseScanResultScreenState
    extends ConsumerState<WarehouseScanResultScreen> {
  late WarehouseScanResultModel _result;
  late int? _selectedWarehouseId;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    _selectedWarehouseId =
        widget.initialWarehouseId ?? widget.initialResult.warehouse?.id;
  }

  @override
  Widget build(BuildContext context) {
    final entity = _result.entity;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _result.resolved ? 'Результат сканирования' : 'Код не распознан',
        ),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refresh,
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
          !_result.resolved || entity == null
              ? AppStateView(
                icon: Icons.qr_code_2_outlined,
                title: 'Код не распознан',
                description:
                    'Проверь маркировку или убедись, что для складской сущности создан идентификатор.',
                action: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Сканировать снова'),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _OverviewCard(
                    result: _result,
                    warehouse: _selectedWarehouse,
                  ),
                  const SizedBox(height: 12),
                  _NextStepCard(
                    recommendedAction: _result.recommendedAction,
                    recommendedTask: _recommendedTask,
                    onRun: _openRecommendedFlow,
                    onOpenQueue: () => _openTaskQueue(),
                  ),
                  const SizedBox(height: 12),
                  _EntityDetailsCard(entity: entity),
                  if (_result.availableActions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ActionsCard(
                      actions: _result.availableActions,
                      recommendedAction: _result.recommendedAction,
                      onTap: (action) => _handleAction(action, entity),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _TasksCard(
                    tasks: _result.relatedTasks,
                    onTap: _handleTaskAction,
                    onOpenQueue: () => _openTaskQueue(),
                  ),
                ],
              ),
    );
  }

  Future<void> _handleAction(
    String action,
    WarehouseScannedEntityModel entity,
  ) async {
    if (action == 'receipt' &&
        (entity.type == 'asset' || entity.type == 'warehouse')) {
      final created = await showWarehouseReceiptSheet(
        context,
        summary: widget.summary,
        initialWarehouseId:
            entity.type == 'warehouse' ? entity.id : _selectedWarehouseId,
        initialMaterial:
            entity.type == 'asset'
                ? WarehouseMaterialOption(
                  id: entity.id,
                  name: entity.name,
                  defaultPrice: entity.defaultPrice ?? 0,
                  code: entity.code,
                  measurementUnitName: entity.measurementLabel,
                  measurementUnitShortName: entity.measurementLabel,
                )
                : null,
      );

      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Приход успешно проведен.')),
        );
        await _refresh();
      }
      return;
    }

    if (action == 'transfer' && entity.type == 'asset') {
      final transferred = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder:
            (_) => WarehouseTransferSheet(
              summary: widget.summary,
              fromWarehouseId: _selectedWarehouseId,
              entity: entity,
            ),
      );

      if (transferred == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Перемещение выполнено.')),
        );
        await _refresh();
      }
      return;
    }

    final matchedTasks =
        _result.relatedTasks
            .where((task) => task.taskType == _taskTypeForAction(action))
            .toList();

    if (matchedTasks.isNotEmpty) {
      final primaryTask = matchedTasks.first;
      final primaryAction = warehousePrimaryTaskAction(primaryTask);

      if (matchedTasks.length == 1 && primaryAction != null) {
        await _handleTaskAction(primaryTask, primaryAction);
      } else {
        await _openTaskQueue(initialTaskType: _taskTypeForAction(action));
      }
      return;
    }

    if (_isTaskDrivenAction(action)) {
      await _openTaskQueue(initialTaskType: _taskTypeForAction(action));
      return;
    }

    _showMessage(
      'Для действия "${warehouseActionLabel(action)}" следующий шаг пока не настроен.',
    );
  }

  Future<void> _handleTaskAction(
    WarehouseTaskModel task,
    String targetStatus,
  ) async {
    final warehouseId = _selectedWarehouseId;
    if (warehouseId == null) {
      _showMessage('Не выбран склад для выполнения задачи.');
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
      await _refresh();
      if (!mounted) {
        return;
      }
      _showMessage(
        'Статус задачи обновлен: ${warehouseStatusLabel(targetStatus)}.',
      );
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _refresh() async {
    final code = _result.scanEvent?.code ?? _result.identifier?.code;
    if (code == null || code.trim().isEmpty) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final refreshed = await ref.read(warehouseRepositoryProvider).resolveScan(
        WarehouseScanPayload(
          code: code,
          warehouseId: _selectedWarehouseId,
          scanContext: 'warehouse_scan_result_refresh',
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = refreshed;
      });
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openTaskQueue({String? initialTaskType}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => WarehouseTasksScreen(
              summary: widget.summary,
              initialWarehouseId: _selectedWarehouseId,
              initialTaskType: initialTaskType,
              initialEntityType: _result.entityType,
              initialEntityId: _result.entityId,
            ),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  WarehouseTaskModel? get _recommendedTask {
    final recommendedAction = _result.recommendedAction;
    if ((recommendedAction ?? '').isEmpty) {
      return _result.relatedTasks.isEmpty ? null : _result.relatedTasks.first;
    }

    for (final task in _result.relatedTasks) {
      if (task.taskType == _taskTypeForAction(recommendedAction!)) {
        return task;
      }
    }

    return _result.relatedTasks.isEmpty ? null : _result.relatedTasks.first;
  }

  Future<void> _openRecommendedFlow() async {
    final task = _recommendedTask;
    final primaryAction =
        task == null ? null : warehousePrimaryTaskAction(task);

    if (task != null && primaryAction != null) {
      await _handleTaskAction(task, primaryAction);
      return;
    }

    final action = _result.recommendedAction;
    final entity = _result.entity;
    if (action != null && entity != null) {
      await _handleAction(action, entity);
      return;
    }

    await _openTaskQueue();
  }

  WarehouseCardModel? get _selectedWarehouse {
    for (final warehouse in widget.summary.warehouses) {
      if (warehouse.id == _selectedWarehouseId) {
        return warehouse;
      }
    }

    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('ApiException: ', ''))),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.result, required this.warehouse});

  final WarehouseScanResultModel result;
  final WarehouseCardModel? warehouse;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if ((result.identifier?.code ?? '').isNotEmpty) result.identifier!.code,
      if ((result.entity?.code ?? '').isNotEmpty) result.entity!.code!,
      if ((warehouse?.name ?? '').isNotEmpty) warehouse!.name,
    ].join(' / ');

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.entity?.name ?? result.entitySummary?.name ?? 'Объект склада',
            style: AppTypography.h2(context),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: AppTypography.bodyMedium(context)),
          ],
          if ((result.resolvedBy ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Источник распознавания: ${result.resolvedBy}',
              style: AppTypography.caption(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntityDetailsCard extends StatelessWidget {
  const _EntityDetailsCard({required this.entity});

  final WarehouseScannedEntityModel entity;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'Тип сущности: ${warehouseEntityTypeLabel(entity.type)}',
      if ((entity.assetTypeLabel ?? '').isNotEmpty)
        'Тип актива: ${entity.assetTypeLabel}',
      if ((entity.category ?? '').isNotEmpty) 'Категория: ${entity.category}',
      if (entity.measurementLabel.isNotEmpty)
        'Ед. изм.: ${entity.measurementLabel}',
      if (entity.availableQuantity != null)
        'Доступно: ${warehouseFormatNumber(entity.availableQuantity!)}',
      if (entity.reservedQuantity != null)
        'В резерве: ${warehouseFormatNumber(entity.reservedQuantity!)}',
      if (entity.totalQuantity != null)
        'Всего: ${warehouseFormatNumber(entity.totalQuantity!)}',
      if (entity.defaultPrice != null)
        'Цена: ${warehouseFormatNumber(entity.defaultPrice!)} ₽',
      if ((entity.fullAddress ?? '').isNotEmpty)
        'Адрес: ${entity.fullAddress}',
      if (entity.storedQuantity != null)
        'Заполнено: ${warehouseFormatNumber(entity.storedQuantity!)}',
      if (entity.capacity != null)
        'Вместимость: ${warehouseFormatNumber(entity.capacity!)}',
      if (entity.currentLoad != null)
        'Текущая загрузка: ${warehouseFormatNumber(entity.currentLoad!)}',
      if (entity.currentUtilization != null)
        'Утилизация: ${warehouseFormatNumber(entity.currentUtilization!)}%',
      if (entity.zone != null) 'Зона: ${entity.zone!.name}',
      if (entity.cell != null) 'Ячейка: ${entity.cell!.name}',
      if (entity.warehouse != null) 'Склад: ${entity.warehouse!.name}',
      if ((entity.description ?? '').isNotEmpty)
        'Описание: ${entity.description}',
    ];

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Контекст',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: AppTypography.bodyMedium(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.recommendedAction,
    required this.recommendedTask,
    required this.onRun,
    required this.onOpenQueue,
  });

  final String? recommendedAction;
  final WarehouseTaskModel? recommendedTask;
  final Future<void> Function() onRun;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final title =
        recommendedTask != null
            ? recommendedTask!.title
            : (recommendedAction == null
                ? 'Следующий шаг пока не определен'
                : 'Рекомендуемое действие: ${warehouseActionLabel(recommendedAction!)}');
    final subtitle =
        recommendedTask != null
            ? '${warehouseTaskTypeLabel(recommendedTask!.taskType)} / ${warehouseStatusLabel(recommendedTask!.status)}'
            : 'Можно открыть очередь задач или перейти к рекомендованному действию.';

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Что делать дальше',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(title, style: AppTypography.h2(context)),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTypography.bodyMedium(context)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => onRun(),
                child: Text(
                  recommendedTask != null
                      ? 'Выполнить следующий шаг'
                      : 'Открыть рекомендованный сценарий',
                ),
              ),
              OutlinedButton(
                onPressed: onOpenQueue,
                child: const Text('Открыть очередь задач'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.actions,
    required this.onTap,
    this.recommendedAction,
  });

  final List<String> actions;
  final String? recommendedAction;
  final void Function(String action) onTap;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            actions.map((action) {
              final label = action == recommendedAction
                  ? '${warehouseActionLabel(action)} / рекомендовано'
                  : warehouseActionLabel(action);
              return FilledButton.tonal(
                onPressed: () => onTap(action),
                child: Text(label),
              );
            }).toList(),
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.tasks,
    required this.onTap,
    required this.onOpenQueue,
  });

  final List<WarehouseTaskModel> tasks;
  final Future<void> Function(WarehouseTaskModel task, String targetStatus) onTap;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return AppStateView(
        icon: Icons.task_alt_outlined,
        title: 'Связанных задач пока нет',
        description:
            'После сканирования здесь будут показываться релевантные складские задания.',
        action: OutlinedButton(
          onPressed: onOpenQueue,
          child: const Text('Открыть очередь'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Связанные задачи', style: AppTypography.h2(context)),
            ),
            TextButton(
              onPressed: onOpenQueue,
              child: const Text('Вся очередь'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tasks.map((task) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IndustrialCard(
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
                    '${task.taskNumber} / ${warehouseTaskTypeLabel(task.taskType)} / ${warehouseStatusLabel(task.status)}',
                    style: AppTypography.bodyMedium(context),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        warehouseAllowedTaskActions(task).map((status) {
                          return OutlinedButton(
                            onPressed: () => onTap(task, status),
                            child: Text(warehouseTaskActionLabel(status)),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

String _taskTypeForAction(String action) {
  return switch (action) {
    'receipt' => 'receipt',
    'transfer' => 'transfer',
    'placement' => 'placement',
    'cycle_count' => 'cycle_count',
    'inspection' => 'inspection',
    _ => action,
  };
}

bool _isTaskDrivenAction(String action) {
  return switch (action) {
    'placement' || 'cycle_count' || 'inspection' || 'transfer' => true,
    _ => false,
  };
}
