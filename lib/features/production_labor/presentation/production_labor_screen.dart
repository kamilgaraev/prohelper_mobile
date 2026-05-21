import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_form_section.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/production_labor_model.dart';
import '../domain/production_labor_provider.dart';

typedef _OutputSubmit =
    Future<void> Function({
      required DateTime workDate,
      required double quantity,
      required double hours,
      String? comment,
    });

typedef _TimesheetSubmit =
    Future<void> Function({
      required DateTime shiftDate,
      required double hours,
      required bool includeInPayroll,
      String? workerName,
      String? safetyPermitReference,
    });

class ProductionLaborScreen extends ConsumerStatefulWidget {
  const ProductionLaborScreen({super.key});

  @override
  ConsumerState<ProductionLaborScreen> createState() =>
      _ProductionLaborScreenState();
}

class _ProductionLaborScreenState extends ConsumerState<ProductionLaborScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(productionLaborProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productionLaborProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(productionLaborProvider.notifier);
        notifier.syncProject(selectedProject?.serverId);
        notifier.load();
      });
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Наряды'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  () => ref.read(productionLaborProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body:
            state.isLoading && state.workOrders.isEmpty
                ? const AppLoadingState(message: 'Загружаем наряды')
                : state.error != null && state.workOrders.isEmpty
                ? AppErrorState(
                  title: 'Не удалось загрузить наряды',
                  description: state.error,
                  onRetry:
                      () => ref.read(productionLaborProvider.notifier).load(),
                )
                : RefreshIndicator(
                  onRefresh:
                      () => ref.read(productionLaborProvider.notifier).load(),
                  child:
                      state.workOrders.isEmpty
                          ? const AppEmptyState(
                            icon: Icons.engineering_outlined,
                            title: 'Нарядов пока нет',
                            description:
                                'Для выбранного объекта нет выданных нарядов.',
                          )
                          : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: state.workOrders.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder:
                                (context, index) => _WorkOrderCard(
                                  workOrder: state.workOrders[index],
                                  onRecordOutput: _showOutputSheet,
                                  onCreateTimesheet: _showTimesheetSheet,
                                ),
                          ),
                ),
      ),
    );
  }

  Future<void> _showOutputSheet(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _OutputSheet(
            line: line,
            onSubmit:
                ({
                  required workDate,
                  required quantity,
                  required hours,
                  comment,
                }) => ref
                    .read(productionLaborProvider.notifier)
                    .recordOutput(
                      workOrder,
                      line,
                      workDate: workDate,
                      quantity: quantity,
                      hours: hours,
                      comment: comment,
                    ),
          ),
    );
  }

  Future<void> _showTimesheetSheet(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _TimesheetSheet(
            workOrder: workOrder,
            line: line,
            onSubmit:
                ({
                  required shiftDate,
                  required hours,
                  required includeInPayroll,
                  workerName,
                  safetyPermitReference,
                }) => ref
                    .read(productionLaborProvider.notifier)
                    .createTimesheet(
                      workOrder,
                      line,
                      shiftDate: shiftDate,
                      hours: hours,
                      includeInPayroll: includeInPayroll,
                      workerName: workerName,
                      safetyPermitReference: safetyPermitReference,
                    ),
          ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({
    required this.workOrder,
    required this.onRecordOutput,
    required this.onCreateTimesheet,
  });

  final LaborWorkOrderModel workOrder;
  final void Function(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line,
  )
  onRecordOutput;
  final void Function(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line,
  )
  onCreateTimesheet;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.engineering_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workOrder.title,
                      style: AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      workOrder.orderNumber,
                      style: AppTypography.caption(context),
                    ),
                    if (workOrder.assigneeName != null)
                      Text(
                        workOrder.assigneeName!,
                        style: AppTypography.caption(context),
                      ),
                  ],
                ),
              ),
              Chip(
                label: Text(workOrder.statusLabel),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (workOrder.lines.isEmpty)
            Text(
              'В наряде нет строк работ.',
              style: AppTypography.caption(context),
            )
          else
            ...workOrder.lines.map(
              (line) => _WorkOrderLineTile(
                workOrder: workOrder,
                line: line,
                onRecordOutput: onRecordOutput,
                onCreateTimesheet: onCreateTimesheet,
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkOrderLineTile extends StatelessWidget {
  const _WorkOrderLineTile({
    required this.workOrder,
    required this.line,
    required this.onRecordOutput,
    required this.onCreateTimesheet,
  });

  final LaborWorkOrderModel workOrder;
  final LaborWorkOrderLineModel line;
  final void Function(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line,
  )
  onRecordOutput;
  final void Function(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line,
  )
  onCreateTimesheet;

  @override
  Widget build(BuildContext context) {
    final canRecord = workOrder.canRecordFact && line.remainingQuantity > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.name, style: AppTypography.bodyMedium(context)),
          const SizedBox(height: 4),
          Text(
            'Принято ${_formatNumber(line.acceptedQuantity)} из ${_formatNumber(line.plannedQuantity)} ${line.unit}',
            style: AppTypography.caption(context),
          ),
          Text(
            'Осталось ${_formatNumber(line.remainingQuantity)} ${line.unit}',
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 150,
                child: OutlinedButton.icon(
                  onPressed:
                      canRecord ? () => onRecordOutput(workOrder, line) : null,
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Выработка'),
                ),
              ),
              SizedBox(
                width: 150,
                child: FilledButton.icon(
                  onPressed:
                      canRecord
                          ? () => onCreateTimesheet(workOrder, line)
                          : null,
                  icon: const Icon(Icons.access_time_rounded),
                  label: const Text('Табель'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutputSheet extends StatefulWidget {
  const _OutputSheet({required this.line, required this.onSubmit});

  final LaborWorkOrderLineModel line;
  final _OutputSubmit onSubmit;

  @override
  State<_OutputSheet> createState() => _OutputSheetState();
}

class _OutputSheetState extends State<_OutputSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _hoursController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _hoursController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workDate = DateTime.now();

    return _LaborSheetFrame(
      title: 'Факт выработки',
      subtitle: widget.line.name,
      isSaving: _isSaving,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          title: 'Данные факта',
          children: [
            Text(
              'Осталось ${_formatNumber(widget.line.remainingQuantity)} ${widget.line.unit}',
              style: AppTypography.caption(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Дата ${_formatDate(workDate)}',
              style: AppTypography.caption(context),
            ),
            const SizedBox(height: 12),
            _LaborTextField(
              controller: _quantityController,
              label: 'Выполненный объем',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validateQuantity,
            ),
            _LaborTextField(
              controller: _hoursController,
              label: 'Трудозатраты, часов',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator:
                  (value) => _validateNumberRange(
                    value,
                    requiredMessage: 'Укажите трудозатраты.',
                    min: 0.01,
                    max: 24,
                    rangeMessage:
                        'Трудозатраты должны быть больше 0 и не больше 24 часов.',
                  ),
            ),
            _LaborTextField(
              controller: _commentController,
              label: 'Комментарий',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  String? _validateQuantity(String? value) {
    final parsed = _parseOptionalDouble(value);

    if (parsed == null) {
      return 'Укажите выполненный объем.';
    }

    if (parsed <= 0) {
      return 'Выполненный объем должен быть больше нуля.';
    }

    if (widget.line.remainingQuantity <= 0) {
      return 'По строке нет доступного объема для фиксации.';
    }

    if (parsed > widget.line.remainingQuantity) {
      return 'Объем не должен превышать остаток по строке.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSubmit(
        workDate: DateTime.now(),
        quantity: _parseDouble(_quantityController.text),
        hours: _parseDouble(_hoursController.text),
        comment: _commentController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showLaborError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _TimesheetSheet extends StatefulWidget {
  const _TimesheetSheet({
    required this.workOrder,
    required this.line,
    required this.onSubmit,
  });

  final LaborWorkOrderModel workOrder;
  final LaborWorkOrderLineModel line;
  final _TimesheetSubmit onSubmit;

  @override
  State<_TimesheetSheet> createState() => _TimesheetSheetState();
}

class _TimesheetSheetState extends State<_TimesheetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _workerController = TextEditingController();
  final _hoursController = TextEditingController();
  final _permitController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _workerController.dispose();
    _hoursController.dispose();
    _permitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LaborSheetFrame(
      title: 'Табель смены',
      subtitle: widget.line.name,
      isSaving: _isSaving,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          title: 'Исполнитель и часы',
          children: [
            if (widget.workOrder.assigneeName != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  label: Text(widget.workOrder.assigneeName!),
                  avatar: const Icon(Icons.group_outlined, size: 18),
                  onPressed: () {
                    _workerController.text = widget.workOrder.assigneeName!;
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            _LaborTextField(
              controller: _workerController,
              label: 'Исполнитель или бригада',
              validator:
                  (value) => _validateRequiredText(
                    value,
                    'Укажите исполнителя или бригаду.',
                  ),
            ),
            _LaborTextField(
              controller: _hoursController,
              label: 'Трудозатраты, часов',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator:
                  (value) => _validateNumberRange(
                    value,
                    requiredMessage: 'Укажите трудозатраты.',
                    min: 0.01,
                    max: 24,
                    rangeMessage:
                        'Трудозатраты должны быть больше 0 и не больше 24 часов.',
                  ),
            ),
            if (widget.line.requiresSafetyPermit)
              _LaborTextField(
                controller: _permitController,
                label: 'Допуск',
                validator:
                    (value) => _validateRequiredText(value, 'Укажите допуск.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSubmit(
        shiftDate: DateTime.now(),
        hours: _parseDouble(_hoursController.text),
        includeInPayroll: false,
        workerName: _workerController.text,
        safetyPermitReference: _permitController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showLaborError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _LaborSheetFrame extends StatelessWidget {
  const _LaborSheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isSaving,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool isSaving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            child: ProCard(
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTypography.h2(context)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: AppTypography.caption(context)),
                  const SizedBox(height: 16),
                  child,
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppSecondaryActionButton(
                          label: 'Отмена',
                          onPressed:
                              isSaving ? null : () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppPrimaryActionButton(
                          label: 'Сохранить',
                          onPressed: onSubmit,
                          isBusy: isSaving,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaborTextField extends StatelessWidget {
  const _LaborTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

String? _validateRequiredText(String? value, String message) {
  return (value ?? '').trim().isEmpty ? message : null;
}

String? _validateNumberRange(
  String? value, {
  required String requiredMessage,
  required double min,
  required double max,
  required String rangeMessage,
}) {
  final parsed = _parseOptionalDouble(value);

  if (parsed == null) {
    return requiredMessage;
  }

  if (parsed < min || parsed > max) {
    return rangeMessage;
  }

  return null;
}

double _parseDouble(String value) {
  return double.parse(value.trim().replaceAll(',', '.'));
}

double? _parseOptionalDouble(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }

  return double.tryParse(text.replaceAll(',', '.'));
}

void _showLaborError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_cleanError(error))));
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('FormatException: ', '');
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}

String _formatDate(DateTime value) {
  return value.toIso8601String().split('T').first;
}
