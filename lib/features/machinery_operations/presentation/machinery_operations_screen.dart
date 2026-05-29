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
import '../data/machinery_operations_model.dart';
import '../domain/machinery_operations_provider.dart';

typedef _ShiftReportSubmit =
    Future<void> Function({
      required DateTime reportDate,
      double? plannedHours,
      required double actualHours,
      required double fuelConsumed,
      String? workDescription,
    });

typedef _DowntimeSubmit =
    Future<void> Function({
      required String reason,
      required DateTime startedAt,
      required int durationMinutes,
      String? comment,
    });

typedef _FuelIssueSubmit =
    Future<void> Function({
      required DateTime issuedAt,
      required String fuelType,
      required double quantity,
      required String unit,
      String? comment,
    });

typedef _ProductionRecordSubmit =
    Future<void> Function({
      required DateTime recordedAt,
      required double quantity,
      required String unit,
      String? comment,
    });

class MachineryOperationsScreen extends ConsumerStatefulWidget {
  const MachineryOperationsScreen({super.key});

  @override
  ConsumerState<MachineryOperationsScreen> createState() =>
      _MachineryOperationsScreenState();
}

class _MachineryOperationsScreenState
    extends ConsumerState<MachineryOperationsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedProject = ref.read(projectsProvider).selectedProject;
      final notifier = ref.read(machineryOperationsProvider.notifier);
      notifier.syncProject(selectedProject?.serverId);
      notifier.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineryOperationsProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (selectedProject?.serverId != state.projectFilter && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(machineryOperationsProvider.notifier);
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
          title: const Text('Техника'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed:
                  () => ref.read(machineryOperationsProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body:
            state.isLoading &&
                    state.assets.isEmpty &&
                    state.shiftReports.isEmpty
                ? const AppLoadingState(message: 'Загружаем технику')
                : state.error != null &&
                    state.assets.isEmpty &&
                    state.shiftReports.isEmpty
                ? AppErrorState(
                  title: 'Не удалось загрузить технику',
                  description: state.error,
                  onRetry:
                      () =>
                          ref.read(machineryOperationsProvider.notifier).load(),
                )
                : RefreshIndicator(
                  onRefresh:
                      () =>
                          ref.read(machineryOperationsProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _SummaryStrip(state: state),
                      const SizedBox(height: 12),
                      if (state.assets.isEmpty)
                        const AppEmptyState(
                          icon: Icons.precision_manufacturing_outlined,
                          title: 'Техника пока не назначена',
                          description:
                              'Для выбранного объекта нет доступных единиц техники.',
                        )
                      else
                        ...state.assets.map(
                          (asset) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AssetCard(
                              asset: asset,
                              onShift: _showShiftReportSheet,
                              onDowntime: _showDowntimeSheet,
                              onFuel: _showFuelSheet,
                              onProduction: _showProductionSheet,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }

  Future<void> _showShiftReportSheet(MachineryAssetModel asset) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _ShiftReportSheet(
            asset: asset,
            onSubmit:
                ({
                  required reportDate,
                  plannedHours,
                  required actualHours,
                  required fuelConsumed,
                  workDescription,
                }) => ref
                    .read(machineryOperationsProvider.notifier)
                    .createShiftReport(
                      asset,
                      reportDate: reportDate,
                      plannedHours: plannedHours,
                      actualHours: actualHours,
                      fuelConsumed: fuelConsumed,
                      workDescription: workDescription,
                    ),
          ),
    );
  }

  Future<void> _showDowntimeSheet(MachineryAssetModel asset) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _DowntimeSheet(
            asset: asset,
            onSubmit:
                ({
                  required reason,
                  required startedAt,
                  required durationMinutes,
                  comment,
                }) => ref
                    .read(machineryOperationsProvider.notifier)
                    .createDowntime(
                      asset,
                      reason: reason,
                      startedAt: startedAt,
                      durationMinutes: durationMinutes,
                      comment: comment,
                    ),
          ),
    );
  }

  Future<void> _showFuelSheet(MachineryAssetModel asset) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _FuelIssueSheet(
            asset: asset,
            onSubmit:
                ({
                  required issuedAt,
                  required fuelType,
                  required quantity,
                  required unit,
                  comment,
                }) => ref
                    .read(machineryOperationsProvider.notifier)
                    .createFuelIssue(
                      asset,
                      issuedAt: issuedAt,
                      fuelType: fuelType,
                      quantity: quantity,
                      unit: unit,
                      comment: comment,
                    ),
          ),
    );
  }

  Future<void> _showProductionSheet(MachineryAssetModel asset) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _ProductionRecordSheet(
            asset: asset,
            onSubmit:
                ({
                  required recordedAt,
                  required quantity,
                  required unit,
                  comment,
                }) => ref
                    .read(machineryOperationsProvider.notifier)
                    .createProductionRecord(
                      asset,
                      recordedAt: recordedAt,
                      quantity: quantity,
                      unit: unit,
                      comment: comment,
                    ),
          ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.state});

  final MachineryOperationsState state;

  @override
  Widget build(BuildContext context) {
    final fuel = state.shiftReports.fold<double>(
      0,
      (total, report) => total + report.fuelConsumed,
    );

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Техника',
            value: state.assets.length.toString(),
            icon: Icons.precision_manufacturing_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Рапорты',
            value: state.shiftReports.length.toString(),
            icon: Icons.assignment_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'ГСМ',
            value: _formatNumber(fuel),
            icon: Icons.local_gas_station_outlined,
          ),
        ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onShift,
    required this.onDowntime,
    required this.onFuel,
    required this.onProduction,
  });

  final MachineryAssetModel asset;
  final ValueChanged<MachineryAssetModel> onShift;
  final ValueChanged<MachineryAssetModel> onDowntime;
  final ValueChanged<MachineryAssetModel> onFuel;
  final ValueChanged<MachineryAssetModel> onProduction;

  @override
  Widget build(BuildContext context) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.precision_manufacturing_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: AppTypography.bodyLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      asset.assetCode,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(asset.statusLabel),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AssetActionButton(
                label: 'Простой',
                icon: Icons.pause_circle_outline_rounded,
                onPressed: () => onDowntime(asset),
              ),
              _AssetActionButton(
                label: 'ГСМ',
                icon: Icons.local_gas_station_outlined,
                onPressed: () => onFuel(asset),
              ),
              _AssetActionButton(
                label: 'Выработка',
                icon: Icons.speed_rounded,
                onPressed: () => onProduction(asset),
              ),
              _AssetActionButton(
                label: 'Рапорт',
                icon: Icons.assignment_turned_in_outlined,
                onPressed: () => onShift(asset),
                primary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetActionButton extends StatelessWidget {
  const _AssetActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final button =
        primary
            ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            )
            : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            );

    return SizedBox(width: 150, child: button);
  }
}

class _ShiftReportSheet extends StatefulWidget {
  const _ShiftReportSheet({required this.asset, required this.onSubmit});

  final MachineryAssetModel asset;
  final _ShiftReportSubmit onSubmit;

  @override
  State<_ShiftReportSheet> createState() => _ShiftReportSheetState();
}

class _ShiftReportSheetState extends State<_ShiftReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _actualHoursController = TextEditingController();
  final _fuelConsumedController = TextEditingController();
  final _plannedHoursController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _actualHoursController.dispose();
    _fuelConsumedController.dispose();
    _plannedHoursController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OperationSheetFrame(
      asset: widget.asset,
      title: 'Сменный рапорт',
      description: 'Укажите фактические показатели смены.',
      isSaving: _isSaving,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          title: 'Показатели смены',
          children: [
            _OperationTextField(
              controller: _actualHoursController,
              label: 'Фактические часы',
              keyboardType: TextInputType.number,
              validator:
                  (value) => _validateNumberRange(
                    value,
                    requiredMessage: 'Укажите фактические часы.',
                    min: 0,
                    max: 24,
                    rangeMessage: 'Часы должны быть от 0 до 24.',
                  ),
            ),
            _OperationTextField(
              controller: _fuelConsumedController,
              label: 'Расход ГСМ',
              keyboardType: TextInputType.number,
              validator:
                  (value) => _validateNumberRange(
                    value,
                    requiredMessage: 'Укажите расход ГСМ.',
                    min: 0,
                    rangeMessage: 'Расход не может быть отрицательным.',
                  ),
            ),
            _OperationTextField(
              controller: _plannedHoursController,
              label: 'Плановые часы',
              keyboardType: TextInputType.number,
              validator:
                  (value) => _validateOptionalNumberRange(
                    value,
                    min: 0,
                    max: 24,
                    rangeMessage: 'Плановые часы должны быть от 0 до 24.',
                  ),
            ),
            _OperationTextField(
              controller: _commentController,
              label: 'Комментарий',
              maxLines: 3,
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
        reportDate: DateTime.now(),
        plannedHours: _parseOptionalDouble(_plannedHoursController.text),
        actualHours: _parseDouble(_actualHoursController.text),
        fuelConsumed: _parseDouble(_fuelConsumedController.text),
        workDescription: _commentController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showOperationError(context, error);
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

class _DowntimeSheet extends StatefulWidget {
  const _DowntimeSheet({required this.asset, required this.onSubmit});

  final MachineryAssetModel asset;
  final _DowntimeSubmit onSubmit;

  @override
  State<_DowntimeSheet> createState() => _DowntimeSheetState();
}

class _DowntimeSheetState extends State<_DowntimeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _durationController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _durationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OperationSheetFrame(
      asset: widget.asset,
      title: 'Простой техники',
      description: 'Зафиксируйте причину и длительность простоя.',
      isSaving: _isSaving,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          title: 'Данные простоя',
          children: [
            _OperationTextField(
              controller: _reasonController,
              label: 'Причина простоя',
              validator:
                  (value) =>
                      _validateRequiredText(value, 'Укажите причину простоя.'),
            ),
            _OperationTextField(
              controller: _durationController,
              label: 'Длительность, минут',
              keyboardType: TextInputType.number,
              validator:
                  (value) => _validateInteger(
                    value,
                    requiredMessage: 'Укажите длительность простоя.',
                    min: 1,
                    rangeMessage: 'Длительность должна быть больше нуля.',
                  ),
            ),
            _OperationTextField(
              controller: _commentController,
              label: 'Комментарий',
              maxLines: 3,
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
        reason: _reasonController.text,
        startedAt: DateTime.now(),
        durationMinutes: _parseInt(_durationController.text),
        comment: _commentController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showOperationError(context, error);
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

class _FuelIssueSheet extends StatefulWidget {
  const _FuelIssueSheet({required this.asset, required this.onSubmit});

  final MachineryAssetModel asset;
  final _FuelIssueSubmit onSubmit;

  @override
  State<_FuelIssueSheet> createState() => _FuelIssueSheetState();
}

class _FuelIssueSheetState extends State<_FuelIssueSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fuelTypeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _fuelTypeController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OperationSheetFrame(
      asset: widget.asset,
      title: 'Выдача ГСМ',
      description: 'Внесите фактическое количество и единицу измерения.',
      isSaving: _isSaving,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          title: 'Параметры выдачи',
          children: [
            _OperationTextField(
              controller: _fuelTypeController,
              label: 'Тип ГСМ',
              validator:
                  (value) => _validateRequiredText(value, 'Укажите тип ГСМ.'),
            ),
            _OperationTextField(
              controller: _quantityController,
              label: 'Количество',
              keyboardType: TextInputType.number,
              validator:
                  (value) => _validateNumberRange(
                    value,
                    requiredMessage: 'Укажите количество.',
                    min: 0.001,
                    rangeMessage: 'Количество должно быть больше нуля.',
                  ),
            ),
            _OperationTextField(
              controller: _unitController,
              label: 'Единица измерения',
              validator:
                  (value) => _validateRequiredText(
                    value,
                    'Укажите единицу измерения.',
                  ),
            ),
            _OperationTextField(
              controller: _commentController,
              label: 'Комментарий',
              maxLines: 3,
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
        issuedAt: DateTime.now(),
        fuelType: _fuelTypeController.text,
        quantity: _parseDouble(_quantityController.text),
        unit: _unitController.text,
        comment: _commentController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showOperationError(context, error);
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

class _ProductionRecordSheet extends StatefulWidget {
  const _ProductionRecordSheet({required this.asset, required this.onSubmit});

  final MachineryAssetModel asset;
  final _ProductionRecordSubmit onSubmit;

  @override
  State<_ProductionRecordSheet> createState() => _ProductionRecordSheetState();
}

class _ProductionRecordSheetState extends State<_ProductionRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OperationSheetFrame(
      asset: widget.asset,
      title: 'Выработка техники',
      description: 'Зафиксируйте фактический объем выполненной работы.',
      isSaving: _isSaving,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: AppFormSection(
          title: 'Фактическая выработка',
          children: [
            _OperationTextField(
              controller: _quantityController,
              label: 'Количество',
              keyboardType: TextInputType.number,
              validator:
                  (value) => _validateNumberRange(
                    value,
                    requiredMessage: 'Укажите количество.',
                    min: 0.001,
                    rangeMessage: 'Количество должно быть больше нуля.',
                  ),
            ),
            _OperationTextField(
              controller: _unitController,
              label: 'Единица измерения',
              validator:
                  (value) => _validateRequiredText(
                    value,
                    'Укажите единицу измерения.',
                  ),
            ),
            _OperationTextField(
              controller: _commentController,
              label: 'Комментарий',
              maxLines: 3,
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
        recordedAt: DateTime.now(),
        quantity: _parseDouble(_quantityController.text),
        unit: _unitController.text,
        comment: _commentController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showOperationError(context, error);
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

class _OperationSheetFrame extends StatelessWidget {
  const _OperationSheetFrame({
    required this.asset,
    required this.title,
    required this.description,
    required this.child,
    required this.isSaving,
    required this.onSubmit,
  });

  final MachineryAssetModel asset;
  final String title;
  final String description;
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
                  Text(
                    '${asset.name} · ${asset.assetCode}',
                    style: AppTypography.caption(context),
                  ),
                  const SizedBox(height: 10),
                  Text(description, style: AppTypography.bodyMedium(context)),
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

class _OperationTextField extends StatelessWidget {
  const _OperationTextField({
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.h2(context)),
          Text(label, style: AppTypography.caption(context)),
        ],
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
  double? max,
  required String rangeMessage,
}) {
  final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));

  if (parsed == null) {
    return requiredMessage;
  }

  if (parsed < min || (max != null && parsed > max)) {
    return rangeMessage;
  }

  return null;
}

String? _validateOptionalNumberRange(
  String? value, {
  required double min,
  double? max,
  required String rangeMessage,
}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return null;
  }

  final parsed = double.tryParse(text.replaceAll(',', '.'));
  if (parsed == null || parsed < min || (max != null && parsed > max)) {
    return rangeMessage;
  }

  return null;
}

String? _validateInteger(
  String? value, {
  required String requiredMessage,
  required int min,
  required String rangeMessage,
}) {
  final parsed = int.tryParse((value ?? '').trim());

  if (parsed == null) {
    return requiredMessage;
  }

  if (parsed < min) {
    return rangeMessage;
  }

  return null;
}

double _parseDouble(String value) {
  return double.parse(value.trim().replaceAll(',', '.'));
}

double? _parseOptionalDouble(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return null;
  }

  return _parseDouble(text);
}

int _parseInt(String value) {
  return int.parse(value.trim());
}

void _showOperationError(BuildContext context, Object error) {
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
