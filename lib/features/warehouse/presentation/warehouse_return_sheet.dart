import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  late final FocusNode _quantityFocusNode;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _reasonController = TextEditingController();
    _quantityFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
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
            TextFormField(
              controller: _quantityController,
              focusNode: _quantityFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Количество',
                border: OutlineInputBorder(),
              ),
              validator: _validateQuantity,
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
              label: Text(
                _isSubmitting ? 'Возвращаем...' : 'Вернуть на объект',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      _quantityFocusNode.requestFocus();
      return;
    }

    final quantity = _parseQuantity(_quantityController.text)!;

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
      if (mounted) {
        _showMessage(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateQuantity(String? value) {
    final quantity = _parseQuantity(value ?? '');
    if (quantity == null) {
      return 'Укажите количество';
    }

    if (quantity <= 0) {
      return 'Количество должно быть больше нуля';
    }

    if (quantity > widget.balance.availableQuantity) {
      return 'Количество не должно превышать остаток у ответственного';
    }

    return null;
  }

  double? _parseQuantity(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text.replaceAll(',', '.'));
  }

  void _showMessage(Object message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(message))));
  }
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}
