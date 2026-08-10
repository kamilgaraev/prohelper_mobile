import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../data/project_material_delivery_model.dart';
import '../domain/warehouse_provider.dart';

class WarehouseIssueSheet extends ConsumerStatefulWidget {
  const WarehouseIssueSheet({
    super.key,
    required this.stock,
    required this.projectWarehouseId,
    required this.responsibleUserId,
  });

  final ProjectMaterialStockItemModel stock;
  final int? projectWarehouseId;
  final int? responsibleUserId;

  @override
  ConsumerState<WarehouseIssueSheet> createState() =>
      _WarehouseIssueSheetState();
}

class _WarehouseIssueSheetState extends ConsumerState<WarehouseIssueSheet> {
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
    final canSubmit =
        widget.stock.projectId != null &&
        widget.stock.materialId != null &&
        widget.stock.onProjectQuantity > 0 &&
        widget.projectWarehouseId != null &&
        widget.responsibleUserId != null &&
        !_isSubmitting;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Взять под ответственность', style: AppTypography.h2(context)),
            const SizedBox(height: 8),
            Text(widget.stock.materialName ?? 'Материал не указан'),
            const SizedBox(height: 12),
            Text(
              'Доступно на объекте: ${_formatQuantity(widget.stock.onProjectQuantity)} ${widget.stock.materialUnit ?? ''}',
              style: AppTypography.bodyMedium(context),
            ),
            if (widget.projectWarehouseId == null) ...[
              const SizedBox(height: 12),
              const Text(
                'Выдача будет доступна после синхронизации объектового склада.',
              ),
            ],
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
              onPressed: canSubmit ? _submit : null,
              icon: const Icon(Icons.assignment_ind_outlined),
              label: Text(
                _isSubmitting ? 'Выдаем...' : 'Взять под ответственность',
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

    final projectId = widget.stock.projectId;
    final materialId = widget.stock.materialId;
    final projectWarehouseId = widget.projectWarehouseId;
    final responsibleUserId = widget.responsibleUserId;

    if (projectId == null ||
        materialId == null ||
        projectWarehouseId == null ||
        responsibleUserId == null) {
      _showMessage('Недостаточно данных для выдачи материала.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(warehouseProvider.notifier)
          .issueToResponsible(
            projectId: projectId,
            projectWarehouseId: projectWarehouseId,
            materialId: materialId,
            responsibleUserId: responsibleUserId,
            quantity: quantity,
            reason: _reasonController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        AppErrorNotice.show(context, error);
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

    if (quantity > widget.stock.onProjectQuantity) {
      return 'Количество не должно превышать остаток на объекте';
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}
