import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../data/warehouse_custody_model.dart';
import '../domain/warehouse_provider.dart';

class WarehouseReturnSheet extends ConsumerStatefulWidget {
  const WarehouseReturnSheet({super.key, required this.balance});

  final WarehouseCustodyBalanceModel balance;

  @override
  ConsumerState<WarehouseReturnSheet> createState() =>
      _WarehouseReturnSheetState();
}

class _WarehouseReturnSheetState extends ConsumerState<WarehouseReturnSheet> {
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Вернуть на объект', style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Text(widget.balance.materialName),
          const SizedBox(height: 12),
          Text(
            'У ответственного: ${_formatQuantity(widget.balance.availableQuantity)} ${widget.balance.unit ?? ''}',
            style: AppTypography.bodyMedium(context),
          ),
          const SizedBox(height: 16),
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
            controller: _reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Основание',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: const Icon(Icons.keyboard_return_outlined),
            label: Text(_isSubmitting ? 'Возвращаем...' : 'Вернуть на объект'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );

    if (quantity == null || quantity <= 0) {
      _showMessage('Укажите корректное количество.');
      return;
    }

    if (quantity > widget.balance.availableQuantity) {
      _showMessage('Количество не должно превышать остаток у ответственного.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(warehouseProvider.notifier)
          .returnFromResponsible(
            projectId: widget.balance.projectId,
            custodyWarehouseId: widget.balance.custodyWarehouseId,
            materialId: widget.balance.materialId,
            quantity: quantity,
            reason: _reasonController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
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

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}
