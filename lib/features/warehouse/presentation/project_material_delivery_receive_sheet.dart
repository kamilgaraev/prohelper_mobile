import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/sync/sync_queue_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/quantity_format.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../data/project_material_delivery_model.dart';
import '../data/warehouse_repository.dart';

class ProjectMaterialDeliveryReceiveSheet extends ConsumerStatefulWidget {
  const ProjectMaterialDeliveryReceiveSheet({
    super.key,
    required this.delivery,
    this.initialQuantity,
  });

  final ProjectMaterialDeliveryModel delivery;
  final String? initialQuantity;

  @override
  ConsumerState<ProjectMaterialDeliveryReceiveSheet> createState() =>
      _ProjectMaterialDeliveryReceiveSheetState();
}

class _ProjectMaterialDeliveryReceiveSheetState
    extends ConsumerState<ProjectMaterialDeliveryReceiveSheet> {
  late final TextEditingController _quantityController = TextEditingController(
    text: widget.initialQuantity,
  );
  final _notesController = TextEditingController();
  late int? _selectedProjectWarehouseId;
  late final bool _projectWarehouseLocked;

  ProjectMaterialDeliveryModel get _delivery => widget.delivery;

  @override
  void initState() {
    super.initState();
    _selectedProjectWarehouseId =
        _delivery.projectWarehouseOptions.any(
              (warehouse) => warehouse.id == _delivery.projectWarehouseId,
            )
            ? _delivery.projectWarehouseId
            : null;
    _projectWarehouseLocked =
        _delivery.acceptedQuantity > 0 && _selectedProjectWarehouseId != null;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final delivery = _delivery;
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    if (quantity == null ||
        quantity <= 0 ||
        quantity > delivery.remainingToAccept) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Количество должно быть больше нуля и не больше остатка к приемке.',
          ),
        ),
      );
      return;
    }
    if (delivery.requiresProjectWarehouseChoice &&
        _selectedProjectWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Выберите склад объекта, на который принимается материал.',
          ),
        ),
      );
      return;
    }

    try {
      await ref
          .read(warehouseRepositoryProvider)
          .receiveProjectMaterialDelivery(
            deliveryId: delivery.id,
            quantity: quantity,
            notes: _notesController.text,
            projectWarehouseId:
                delivery.requiresProjectWarehouseChoice
                    ? _selectedProjectWarehouseId
                    : null,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on SyncQueuedException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        Navigator.of(context).pop(false);
      }
    } catch (error) {
      if (mounted) {
        AppErrorNotice.show(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;
    final unit = delivery.materialUnit ?? '';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Принять на объект', style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Text(delivery.materialName!, style: AppTypography.bodyLarge(context)),
          const SizedBox(height: 12),
          Text('Отгружено: ${_formatQuantity(delivery.shippedQuantity)} $unit'),
          Text(
            'Уже принято: ${_formatQuantity(delivery.acceptedQuantity)} $unit',
          ),
          Text(
            'Осталось принять: ${_formatQuantity(delivery.remainingToAccept)} $unit',
          ),
          if (delivery.requiresProjectWarehouseChoice) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const ValueKey('project-warehouse-select'),
              initialValue: _selectedProjectWarehouseId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Склад объекта',
                helperText:
                    _projectWarehouseLocked
                        ? 'Часть поставки уже принята на этот склад. Остаток принимается туда же.'
                        : 'Склад подставлен из отгрузки. Измените, если материал приняли на другой склад.',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final warehouse in delivery.projectWarehouseOptions)
                  DropdownMenuItem<int>(
                    value: warehouse.id,
                    child: Text(
                      warehouse.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged:
                  _projectWarehouseLocked
                      ? null
                      : (value) =>
                          setState(() => _selectedProjectWarehouseId = value),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Количество',
              helperText:
                  'К приемке: ${_formatQuantity(delivery.remainingToAccept)} $unit',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Принять на объект'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  return formatQuantity(value, maxFractionDigits: 3);
}
