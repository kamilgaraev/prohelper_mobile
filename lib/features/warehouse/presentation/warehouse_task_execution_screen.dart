import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_scan_model.dart';
import '../data/warehouse_summary_model.dart';
import 'warehouse_camera_scanner_screen.dart';
import 'warehouse_task_helpers.dart';

class WarehouseTaskExecutionScreen extends ConsumerStatefulWidget {
  const WarehouseTaskExecutionScreen({
    super.key,
    required this.summary,
    required this.task,
    required this.targetStatus,
    this.initialWarehouseId,
  });

  final WarehouseSummaryModel summary;
  final WarehouseTaskModel task;
  final String targetStatus;
  final int? initialWarehouseId;

  @override
  ConsumerState<WarehouseTaskExecutionScreen> createState() =>
      _WarehouseTaskExecutionScreenState();
}

class _WarehouseTaskExecutionScreenState
    extends ConsumerState<WarehouseTaskExecutionScreen> {
  late final TextEditingController _notesController;
  late final TextEditingController _quantityController;
  late final TextEditingController _codeController;
  late final List<_TaskStep> _steps;
  final Map<String, WarehouseScanResultModel> _verified =
      <String, WarehouseScanResultModel>{};
  String? _selectedStepKey;
  bool _isResolving = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps(widget.task);
    _selectedStepKey = _steps.isNotEmpty ? _steps.first.key : null;
    _notesController = TextEditingController(text: widget.task.notes ?? '');
    _quantityController = TextEditingController(text: _initialQuantityValue());
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _quantityController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsScan = _requiredSteps.isNotEmpty && widget.targetStatus == 'completed';
    final selectedStep = _selectedStep;
    final selectedResult =
        selectedStep == null ? null : _verified[selectedStep.key];

    return Scaffold(
      appBar: AppBar(title: Text(warehouseTaskActionLabel(widget.targetStatus))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Hero(task: widget.task, targetStatus: widget.targetStatus),
          const SizedBox(height: 12),
          if (_steps.isNotEmpty) ...[
            _StepSummary(
              totalSteps: _steps.length,
              verifiedSteps: _verified.length,
              nextStepLabel: _nextPendingStep?.label,
            ),
            const SizedBox(height: 12),
          ],
          _Context(task: widget.task),
          if (_steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            IndustrialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подтверждение по шагам',
                    style: AppTypography.bodyLarge(
                      context,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ..._steps.map(_buildStepTile),
                  if (selectedStep != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Сейчас ожидается: ${selectedStep.label.toLowerCase()}',
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isResolving ? null : _openCameraScanner,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Сканировать камерой'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _codeController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _resolveManualCode(),
                      decoration: InputDecoration(
                        labelText: 'Код для ручной проверки',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _codeController.clear();
                              _verified.remove(selectedStep.key);
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isResolving ? null : _resolveManualCode,
                        icon:
                            _isResolving
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                : const Icon(Icons.qr_code_2_outlined),
                        label: Text(
                          _isResolving ? 'Проверяем...' : 'Подтвердить введенный код',
                        ),
                      ),
                    ),
                    if (selectedResult != null) ...[
                      const SizedBox(height: 12),
                      _ResultBanner(step: selectedStep, result: selectedResult),
                    ],
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          IndustrialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Параметры выполнения',
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (_showsQuantityField()) ...[
                  TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          widget.task.taskType == 'cycle_count'
                              ? 'Фактическое количество'
                              : 'Количество по операции',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий исполнителя',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (needsScan && _nextPendingStep != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Перед завершением операции подтвердите все обязательные шаги сканированием.',
                      style: AppTypography.bodyMedium(context),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon:
                        _isSubmitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.task_alt_rounded),
                    label: Text(
                      _isSubmitting ? 'Сохраняем...' : warehouseTaskActionLabel(widget.targetStatus),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(_TaskStep step) {
    final selected = step.key == _selectedStepKey;
    final verified = _verified.containsKey(step.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _selectedStepKey = step.key),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                verified
                    ? AppColors.success.withValues(alpha: 0.1)
                    : selected
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(
                verified ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded,
                color: verified ? AppColors.success : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(step.expectedName, style: AppTypography.bodyMedium(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCameraScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const WarehouseCameraScannerScreen()),
    );
    if (!mounted || scannedCode == null || scannedCode.trim().isEmpty) {
      return;
    }
    _codeController.text = scannedCode;
    await _resolveCode(scannedCode);
  }

  Future<void> _resolveManualCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('Введите код для проверки или используйте сканер камеры.');
      return;
    }
    await _resolveCode(code);
  }

  Future<void> _resolveCode(String code) async {
    final warehouseId = _effectiveWarehouseId;
    if (warehouseId == null) {
      _showMessage('Не удалось определить склад для проверки кода.');
      return;
    }
    setState(() => _isResolving = true);
    try {
      final result = await ref.read(warehouseRepositoryProvider).resolveScan(
        WarehouseScanPayload(
          code: code,
          warehouseId: warehouseId,
          scanContext: 'warehouse_task_execution',
        ),
      );
      if (!mounted) {
        return;
      }
      final matchedStep = _matchStep(result);
      setState(() {
        if (matchedStep != null) {
          _verified[matchedStep.key] = result;
          _selectedStepKey = _nextPendingStep?.key ?? matchedStep.key;
        }
      });
      if (!result.resolved || result.entity == null) {
        _showMessage('Код не распознан. Проверьте маркировку и повторите.');
      } else if (matchedStep != null) {
        _showMessage('Подтвержден шаг: ${matchedStep.label.toLowerCase()}.');
      } else {
        _showMessage('Скан распознан, но не относится к ожидаемым шагам операции.');
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  Future<void> _submit() async {
    final warehouseId = _effectiveWarehouseId;
    if (warehouseId == null) {
      _showMessage('Не удалось определить склад для выполнения задачи.');
      return;
    }
    if (_requiredSteps.isNotEmpty &&
        widget.targetStatus == 'completed' &&
        _nextPendingStep != null) {
      _showMessage('Сначала подтвердите все обязательные шаги сканированием.');
      return;
    }
    final quantity = _parseQuantity();
    if (widget.task.taskType == 'cycle_count' &&
        widget.targetStatus == 'completed' &&
        quantity == null) {
      _showMessage('Для инвентаризации укажите фактическое количество.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final updatedTask = await ref.read(warehouseRepositoryProvider).updateTaskStatus(
        warehouseId,
        widget.task.id,
        WarehouseTaskStatusPayload(
          status: widget.targetStatus,
          completedQuantity: quantity,
          notes: _composeNotes(),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updatedTask);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  int? get _effectiveWarehouseId {
    if (widget.initialWarehouseId != null) {
      return widget.initialWarehouseId;
    }
    if (widget.task.warehouseId > 0) {
      return widget.task.warehouseId;
    }
    return widget.summary.warehouses.isEmpty ? null : widget.summary.warehouses.first.id;
  }

  _TaskStep? get _selectedStep {
    if (_steps.isEmpty) {
      return null;
    }
    for (final step in _steps) {
      if (step.key == _selectedStepKey) {
        return step;
      }
    }
    return _steps.first;
  }

  List<_TaskStep> get _requiredSteps =>
      _steps.where((step) => step.required).toList();

  _TaskStep? get _nextPendingStep {
    for (final step in _requiredSteps) {
      if (!_verified.containsKey(step.key)) {
        return step;
      }
    }
    return null;
  }

  double? _parseQuantity() {
    final raw = _quantityController.text.trim();
    return raw.isEmpty ? null : double.tryParse(raw.replaceAll(',', '.'));
  }

  bool _showsQuantityField() {
    if (widget.targetStatus != 'completed') {
      return false;
    }
    if (widget.task.taskType == 'cycle_count') {
      return true;
    }
    return widget.task.plannedQuantity != null || widget.task.completedQuantity != null;
  }

  String _initialQuantityValue() {
    if (widget.task.completedQuantity != null) {
      return warehouseFormatNumber(widget.task.completedQuantity!);
    }
    if (widget.task.plannedQuantity != null) {
      return warehouseFormatNumber(widget.task.plannedQuantity!);
    }
    return '';
  }

  _TaskStep? _matchStep(WarehouseScanResultModel result) {
    for (final step in _steps) {
      if (result.entityType == step.entityType && result.entityId == step.entityId) {
        return step;
      }
    }
    return null;
  }

  List<_TaskStep> _buildSteps(WarehouseTaskModel task) {
    final steps = <_TaskStep>[];
    void addStep({
      required String key,
      required String entityType,
      required int entityId,
      required String label,
      required String name,
      bool required = true,
    }) {
      steps.add(
        _TaskStep(
          key: key,
          entityType: entityType,
          entityId: entityId,
          label: label,
          expectedName: name,
          required: required,
        ),
      );
    }
    if (task.taskType == 'placement') {
      if (task.material != null) {
        addStep(
          key: 'placement-material-${task.material!.id}',
          entityType: 'asset',
          entityId: task.material!.id,
          label: 'Что размещаем',
          name: task.material!.name,
        );
      }
      if (task.cell != null) {
        addStep(
          key: 'placement-cell-${task.cell!.id}',
          entityType: 'cell',
          entityId: task.cell!.id,
          label: 'Целевая ячейка',
          name: task.cell!.name,
        );
      }
      if (task.logisticUnit != null) {
        addStep(
          key: 'placement-lu-${task.logisticUnit!.id}',
          entityType: 'logistic_unit',
          entityId: task.logisticUnit!.id,
          label: 'Целевая логединица',
          name: task.logisticUnit!.name,
        );
      }
    }
    if (task.taskType == 'transfer') {
      if (task.material != null) {
        addStep(
          key: 'transfer-material-${task.material!.id}',
          entityType: 'asset',
          entityId: task.material!.id,
          label: 'Что перемещаем',
          name: task.material!.name,
        );
      }
      if (task.logisticUnit != null) {
        addStep(
          key: 'transfer-lu-${task.logisticUnit!.id}',
          entityType: 'logistic_unit',
          entityId: task.logisticUnit!.id,
          label: 'Логединица для перемещения',
          name: task.logisticUnit!.name,
        );
      }
      if (task.cell != null) {
        addStep(
          key: 'transfer-cell-${task.cell!.id}',
          entityType: 'cell',
          entityId: task.cell!.id,
          label: 'Целевая ячейка',
          name: task.cell!.name,
          required: false,
        );
      }
    }
    if (task.taskType == 'cycle_count') {
      if (task.cell != null) {
        addStep(
          key: 'count-cell-${task.cell!.id}',
          entityType: 'cell',
          entityId: task.cell!.id,
          label: 'Ячейка для пересчета',
          name: task.cell!.name,
        );
      }
      if (task.logisticUnit != null) {
        addStep(
          key: 'count-lu-${task.logisticUnit!.id}',
          entityType: 'logistic_unit',
          entityId: task.logisticUnit!.id,
          label: 'Логединица для пересчета',
          name: task.logisticUnit!.name,
        );
      }
      if (task.material != null) {
        addStep(
          key: 'count-material-${task.material!.id}',
          entityType: 'asset',
          entityId: task.material!.id,
          label: 'Материал или актив',
          name: task.material!.name,
        );
      }
    }
    if (task.taskType == 'inspection') {
      if (task.material != null) {
        addStep(
          key: 'inspection-material-${task.material!.id}',
          entityType: 'asset',
          entityId: task.material!.id,
          label: 'Актив для проверки',
          name: task.material!.name,
        );
      }
      if (task.logisticUnit != null) {
        addStep(
          key: 'inspection-lu-${task.logisticUnit!.id}',
          entityType: 'logistic_unit',
          entityId: task.logisticUnit!.id,
          label: 'Логединица для проверки',
          name: task.logisticUnit!.name,
        );
      }
      if (task.cell != null) {
        addStep(
          key: 'inspection-cell-${task.cell!.id}',
          entityType: 'cell',
          entityId: task.cell!.id,
          label: 'Ячейка для проверки',
          name: task.cell!.name,
        );
      }
    }
    if (task.taskType == 'receipt' && task.material != null) {
      addStep(
        key: 'receipt-material-${task.material!.id}',
        entityType: 'asset',
        entityId: task.material!.id,
        label: 'Принятый актив',
        name: task.material!.name,
        required: false,
      );
    }
    return steps;
  }

  String? _composeNotes() {
    final parts = <String>[];
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      parts.add(notes);
    }
    for (final step in _steps) {
      final result = _verified[step.key];
      if (result == null || !result.resolved) {
        continue;
      }
      final scannedName = result.entity?.name ?? result.entitySummary?.name ?? '';
      final scannedCode = result.scanEvent?.code ?? result.identifier?.code ?? '';
      parts.add(
        [
          'Подтверждено сканированием',
          step.label,
          if (scannedName.isNotEmpty) scannedName,
          if (scannedCode.isNotEmpty) scannedCode,
        ].join(': ').replaceFirst(': :', ': '),
      );
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('ApiException: ', ''))),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.task, required this.targetStatus});

  final WarehouseTaskModel task;
  final String targetStatus;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: AppTypography.h2(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: task.taskNumber, color: Theme.of(context).colorScheme.primary),
              _Badge(label: warehouseTaskTypeLabel(task.taskType), color: AppColors.secondary),
              _Badge(label: warehouseStatusLabel(task.status), color: Colors.blueGrey),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Следующее действие: ${warehouseTaskActionLabel(targetStatus)}',
            style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Context extends StatelessWidget {
  const _Context({required this.task});

  final WarehouseTaskModel task;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Контекст задачи', style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (task.warehouse != null) _Info(label: 'Склад', value: _ref(task.warehouse!)),
          if (task.zone != null) _Info(label: 'Зона', value: _ref(task.zone!)),
          if (task.cell != null) _Info(label: 'Ячейка', value: _ref(task.cell!)),
          if (task.logisticUnit != null) _Info(label: 'Логединица', value: _ref(task.logisticUnit!)),
          if (task.material != null) _Info(label: 'Материал', value: _ref(task.material!)),
          if (task.project != null) _Info(label: 'Проект', value: _ref(task.project!)),
          if (task.plannedQuantity != null) _Info(label: 'План', value: warehouseFormatNumber(task.plannedQuantity!)),
          if (task.completedQuantity != null) _Info(label: 'Факт', value: warehouseFormatNumber(task.completedQuantity!)),
          if (task.dueAt != null) _Info(label: 'Срок', value: warehouseFormatDateTime(task.dueAt!)),
        ],
      ),
    );
  }

  String _ref(WarehouseEntityRefModel ref) {
    final parts = <String>[ref.name];
    if ((ref.code ?? '').isNotEmpty) {
      parts.add(ref.code!);
    }
    if ((ref.subtitle ?? '').isNotEmpty) {
      parts.add(ref.subtitle!);
    }
    return parts.join(' / ');
  }
}

class _StepSummary extends StatelessWidget {
  const _StepSummary({
    required this.totalSteps,
    required this.verifiedSteps,
    required this.nextStepLabel,
  });

  final int totalSteps;
  final int verifiedSteps;
  final String? nextStepLabel;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Row(
        children: [
          Expanded(
            child: _Info(
              label: 'Подтверждено',
              value: '$verifiedSteps из $totalSteps',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Info(
              label: 'Следующий шаг',
              value: nextStepLabel ?? 'Все обязательные шаги закрыты',
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.step,
    required this.result,
  });

  final _TaskStep step;
  final WarehouseScanResultModel result;

  @override
  Widget build(BuildContext context) {
    final matched =
        result.resolved &&
        result.entityType == step.entityType &&
        result.entityId == step.entityId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            matched
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(_label(), style: AppTypography.bodyMedium(context)),
    );
  }

  String _label() {
    if (!result.resolved || result.entity == null) {
      return 'Код не распознан. Проверьте маркировку и попробуйте снова.';
    }
    final scannedName = result.entity?.name ?? result.entitySummary?.name ?? '';
    final scannedType = warehouseEntityTypeLabel(result.entityType ?? '');
    if (result.entityType == step.entityType && result.entityId == step.entityId) {
      return 'Подтверждено: $scannedType "$scannedName" совпадает с шагом "${step.label.toLowerCase()}".';
    }
    return 'Получен объект "$scannedName" ($scannedType), но для этого шага ожидался другой код.';
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTypography.caption(context))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium(context).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
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
        style: AppTypography.caption(context).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TaskStep {
  const _TaskStep({
    required this.key,
    required this.entityType,
    required this.entityId,
    required this.label,
    required this.expectedName,
    this.required = true,
  });

  final String key;
  final String entityType;
  final int entityId;
  final String label;
  final String expectedName;
  final bool required;
}
