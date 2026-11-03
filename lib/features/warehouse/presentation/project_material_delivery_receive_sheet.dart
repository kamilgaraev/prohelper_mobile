import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/sync/sync_queue_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/quantity_format.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../data/project_material_delivery_model.dart';
import '../data/warehouse_repository.dart';
import '../../quality_control/data/incoming_control_model.dart';
import '../../quality_control/domain/incoming_control_provider.dart';
import '../../quality_control/presentation/incoming_control_fields.dart';

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
  final _controlKey = GlobalKey<IncomingControlFieldsState>();
  String _operationKey = newIncomingControlOperationKey();
  String _controlOperationKey = newIncomingControlOperationKey();
  bool _submitting = false;
  late final String? _ownerScope;
  late int? _selectedProjectWarehouseId;
  late final bool _projectWarehouseLocked;

  ProjectMaterialDeliveryModel get _delivery => widget.delivery;

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(incomingControlOwnerScopeProvider);
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
    if (_submitting ||
        ref.read(incomingControlOwnerScopeProvider) != _ownerScope) {
      return;
    }
    final delivery = _delivery;
    final references =
        delivery.projectId == null
            ? null
            : ref.read(
              incomingControlReceivingReferencesProvider(delivery.projectId!),
            );
    if (references != null && !references.hasValue) {
      AppErrorNotice.show(
        context,
        references.error ?? 'Дождитесь загрузки правил входного контроля.',
      );
      return;
    }
    Map<String, dynamic>? incomingControl;
    if (references?.valueOrNull?.enabled == true) {
      try {
        incomingControl = {
          ..._controlKey.currentState!.payload(),
          'idempotency_key': _controlOperationKey,
        };
      } on FormatException catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
    }
    final quantity =
        incomingControl != null
            ? incomingQuantity(incomingControl['presented_quantity'])
            : double.tryParse(
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

    setState(() => _submitting = true);
    try {
      await ref
          .read(warehouseRepositoryProvider)
          .receiveProjectMaterialDelivery(
            deliveryId: delivery.id,
            quantity: quantity,
            notes: _notesController.text,
            projectId: delivery.projectId,
            operationKey: _operationKey,
            incomingControl: incomingControl,
            incomingControlFiles:
                incomingControl == null
                    ? const []
                    : _controlKey.currentState!.files,
            projectWarehouseId:
                delivery.requiresProjectWarehouseChoice
                    ? _selectedProjectWarehouseId
                    : null,
          );

      await _controlKey.currentState?.clearDraft();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on SyncQueuedException catch (error) {
      await _controlKey.currentState?.clearDraft();
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;
    final unit = delivery.materialUnit ?? '';
    if (ref.watch(incomingControlOwnerScopeProvider) != _ownerScope) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Сеанс изменился. Закройте форму и откройте приёмку заново.',
        ),
      );
    }
    final references =
        delivery.projectId == null
            ? null
            : ref.watch(
              incomingControlReceivingReferencesProvider(delivery.projectId!),
            );
    final control = references?.valueOrNull;

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
          if (references?.isLoading == true) const LinearProgressIndicator(),
          if (references?.hasError == true) ...[
            const Text(
              'Не удалось проверить правила входного контроля. Обновите данные перед приёмкой.',
            ),
            TextButton(
              onPressed:
                  () => ref.invalidate(
                    incomingControlReceivingReferencesProvider(
                      delivery.projectId!,
                    ),
                  ),
              child: const Text('Повторить'),
            ),
          ],
          if (control?.enabled == true)
            IncomingControlFields(
              key: _controlKey,
              references: control!,
              materialId: delivery.materialId,
              materialResolvedBySource: true,
              projectId: delivery.projectId,
              draftId: 'project_delivery:${delivery.id}',
              draftContextBuilder:
                  () => {
                    'operation_key': _operationKey,
                    'control_operation_key': _controlOperationKey,
                    'notes': _notesController.text,
                    'warehouse_id': _selectedProjectWarehouseId,
                  },
              onRestoreContext:
                  (data) => setState(() {
                    _operationKey =
                        data['operation_key']?.toString() ?? _operationKey;
                    _controlOperationKey =
                        data['control_operation_key']?.toString() ??
                        _controlOperationKey;
                    _notesController.text = data['notes']?.toString() ?? '';
                    final id = int.tryParse(
                      data['warehouse_id']?.toString() ?? '',
                    );
                    if (!_projectWarehouseLocked &&
                        delivery.projectWarehouseOptions.any(
                          (warehouse) => warehouse.id == id,
                        )) {
                      _selectedProjectWarehouseId = id;
                    }
                  }),
              quantity:
                  double.tryParse(
                    _quantityController.text.replaceAll(',', '.'),
                  ) ??
                  delivery.remainingToAccept,
              canComplete: control.can('inspect'),
              canAccept: control.can('approve'),
              canReject: control.can('reject'),
            ),
          if (control?.enabled != true)
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              onPressed:
                  _submitting || (references != null && !references.hasValue)
                      ? null
                      : _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_submitting ? 'Сохраняем…' : 'Принять на объект'),
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
