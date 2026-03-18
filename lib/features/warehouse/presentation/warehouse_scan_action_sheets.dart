import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_scan_model.dart';
import '../data/warehouse_summary_model.dart';
import 'warehouse_task_helpers.dart';

class WarehouseTaskStatusSheet extends StatefulWidget {
  const WarehouseTaskStatusSheet({
    super.key,
    required this.task,
    required this.targetStatus,
  });

  final WarehouseTaskModel task;
  final String targetStatus;

  @override
  State<WarehouseTaskStatusSheet> createState() =>
      _WarehouseTaskStatusSheetState();
}

class _WarehouseTaskStatusSheetState extends State<WarehouseTaskStatusSheet> {
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text:
          widget.task.plannedQuantity != null
              ? widget.task.plannedQuantity!.toString()
              : '',
    );
    _notesController = TextEditingController(text: widget.task.notes ?? '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsQuantity =
        widget.targetStatus == 'completed' &&
        widget.task.taskType == 'cycle_count';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            warehouseTaskActionLabel(widget.targetStatus),
            style: AppTypography.h2(context),
          ),
          const SizedBox(height: 12),
          if (needsQuantity) ...[
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Фактическое количество',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                WarehouseTaskStatusPayload(
                  status: widget.targetStatus,
                  completedQuantity:
                      needsQuantity
                          ? double.tryParse(
                            _quantityController.text.replaceAll(',', '.'),
                          )
                          : null,
                  notes: _notesController.text.trim(),
                ),
              );
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }
}

class WarehouseTransferSheet extends ConsumerStatefulWidget {
  const WarehouseTransferSheet({
    super.key,
    required this.summary,
    required this.fromWarehouseId,
    required this.entity,
  });

  final WarehouseSummaryModel summary;
  final int? fromWarehouseId;
  final WarehouseScannedEntityModel entity;

  @override
  ConsumerState<WarehouseTransferSheet> createState() =>
      _WarehouseTransferSheetState();
}

class _WarehouseTransferSheetState
    extends ConsumerState<WarehouseTransferSheet> {
  late final TextEditingController _quantityController;
  late final TextEditingController _documentController;
  late final TextEditingController _reasonController;
  int? _toWarehouseId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _documentController = TextEditingController();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _documentController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final destinations =
        widget.summary.warehouses
            .where((warehouse) => warehouse.id != widget.fromWarehouseId)
            .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Перемещение', style: AppTypography.h2(context)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _toWarehouseId,
            items:
                destinations.map((warehouse) {
                  return DropdownMenuItem<int>(
                    value: warehouse.id,
                    child: Text(warehouse.name),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() {
                _toWarehouseId = value;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Склад назначения',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Количество',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _documentController,
            decoration: const InputDecoration(
              labelText: 'Номер документа',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Основание',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'Выполняем...' : 'Переместить'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final fromWarehouseId = widget.fromWarehouseId;
    final toWarehouseId = _toWarehouseId;
    final quantity = double.tryParse(
      _quantityController.text.replaceAll(',', '.'),
    );

    if (fromWarehouseId == null) {
      _showMessage('Не определён склад-источник.');
      return;
    }
    if (toWarehouseId == null) {
      _showMessage('Выбери склад назначения.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showMessage('Укажи корректное количество.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(warehouseRepositoryProvider).createTransfer(
        WarehouseTransferPayload(
          fromWarehouseId: fromWarehouseId,
          toWarehouseId: toWarehouseId,
          materialId: widget.entity.id,
          quantity: quantity,
          documentNumber: _documentController.text.trim(),
          reason: _reasonController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('ApiException: ', ''))),
    );
  }
}

String taskStatusActionLabel(String status) {
  return switch (status) {
    'queued' => 'Вернуть в очередь',
    'in_progress' => 'Взять в работу',
    'blocked' => 'Заблокировать',
    'completed' => 'Завершить',
    'cancelled' => 'Отменить',
    _ => 'Обновить',
  };
}
