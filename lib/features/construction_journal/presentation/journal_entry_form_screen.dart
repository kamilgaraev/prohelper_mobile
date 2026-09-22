import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';
import '../data/journal_entry_operation_recovery.dart';

class JournalEntryFormScreen extends ConsumerStatefulWidget {
  const JournalEntryFormScreen({
    super.key,
    required this.journalId,
    this.initialEntry,
  });

  final int journalId;
  final ConstructionJournalEntryModel? initialEntry;

  @override
  ConsumerState<JournalEntryFormScreen> createState() =>
      _JournalEntryFormScreenState();
}

enum _JournalSyncStatus { saved, queued, unsent, rejected }

class _JournalEntryFormScreenState
    extends ConsumerState<JournalEntryFormScreen> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _problemsController;
  late final TextEditingController _safetyController;
  late final TextEditingController _visitorsController;
  late final TextEditingController _qualityController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _precipitationController;
  late final TextEditingController _windSpeedController;
  final List<_WorkVolumeInput> _workVolumes = [];
  final List<_MaterialUsageInput> _materials = [];
  final List<_WorkerInput> _workers = [];
  final List<_EquipmentInput> _equipment = [];
  DateTime? _entryDate;
  ConstructionJournalEntryFormOptions? _options;
  int? _selectedEstimateId;
  int? _selectedEstimateItemId;
  bool _isLoadingOptions = false;
  bool _isSaving = false;
  bool _isRestoring = true;
  bool _recoveryFailed = false;
  String? _operationKey;
  String? _submitOperationKey;
  PendingJournalEntryOperation? _pendingOperation;
  ConstructionJournalEntryModel? _recoveredEntry;
  String? _recoveryNotice;
  _JournalSyncStatus? _syncStatus;
  String? _serverRejectionReason;
  final ScrollController _formScrollController = ScrollController();

  bool get _isEdit => widget.initialEntry != null;

  bool get _hasRecoveredEntry =>
      _recoveredEntry != null || _pendingOperation?.entryId != null;

  List<ConstructionJournalEstimateOption> get _estimates =>
      _options?.estimates ?? const [];

  List<ConstructionJournalWorkTypeOption> get _workTypes =>
      _options?.workTypes ?? const [];

  List<ConstructionJournalProjectMaterialOption> get _projectMaterials =>
      _options?.projectMaterials ?? const [];

  List<ConstructionJournalProjectMaterialOption> get _custodyMaterials =>
      _projectMaterials
          .where((material) => material.custodyWarehouseId != null)
          .toList();

  List<ConstructionJournalProjectMaterialOption> get _objectMaterials =>
      _projectMaterials
          .where((material) => material.custodyWarehouseId == null)
          .toList();

  List<ConstructionJournalEstimateItemOption> get _selectedEstimateItems {
    final estimate = _estimates.where((item) => item.id == _selectedEstimateId);
    return estimate.isEmpty ? const [] : estimate.first.items;
  }

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialEntry?.workDescription ?? '',
    );
    _problemsController = TextEditingController(
      text: widget.initialEntry?.problemsDescription ?? '',
    );
    _safetyController = TextEditingController(
      text: widget.initialEntry?.safetyNotes ?? '',
    );
    _visitorsController = TextEditingController(
      text: widget.initialEntry?.visitorsNotes ?? '',
    );
    _qualityController = TextEditingController(
      text: widget.initialEntry?.qualityNotes ?? '',
    );
    _temperatureController = TextEditingController(
      text:
          widget.initialEntry?.weatherConditions?.temperature?.toString() ?? '',
    );
    _precipitationController = TextEditingController(
      text: widget.initialEntry?.weatherConditions?.precipitation ?? '',
    );
    _windSpeedController = TextEditingController(
      text: widget.initialEntry?.weatherConditions?.windSpeed?.toString() ?? '',
    );
    _entryDate =
        widget.initialEntry == null
            ? null
            : DateTime.tryParse(widget.initialEntry!.entryDate);
    _selectedEstimateId = widget.initialEntry?.estimateId;
    _workVolumes.addAll(
      (widget.initialEntry?.workVolumes ?? const []).map(
        _WorkVolumeInput.fromModel,
      ),
    );
    _materials.addAll(
      (widget.initialEntry?.materials ?? const []).map(
        _MaterialUsageInput.fromModel,
      ),
    );
    _workers.addAll(
      (widget.initialEntry?.workers ?? const []).map(_WorkerInput.fromModel),
    );
    _equipment.addAll(
      (widget.initialEntry?.equipment ?? const []).map(
        _EquipmentInput.fromModel,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFormOptions();
      _restorePendingOperation();
    });
  }

  Future<void> _restorePendingOperation() async {
    try {
      if (_isEdit) return;
      _recoveryFailed = false;
      final repository = ref.read(constructionJournalRepositoryProvider);
      final pending = await repository.findPendingEntryOperation(
        widget.journalId,
      );
      if (!mounted || pending == null) {
        return;
      }

      _pendingOperation = pending;
      if (pending.entryId != null) {
        _submitOperationKey =
            pending.payload['stage'] == 'submit'
                ? pending.idempotencyKey
                : '${pending.idempotencyKey}:submit';
      } else {
        _operationKey = pending.idempotencyKey;
      }
      if (pending.entryId != null) {
        try {
          final entry = await repository.fetchEntryDetail(pending.entryId!);
          if (!mounted) {
            return;
          }
          _recoveredEntry = entry;
          _restoreEntry(entry);
          _syncStatus = _JournalSyncStatus.unsent;
          _recoveryNotice =
              'Запись создана, отправка ещё не завершена. Можно продолжить.';
        } on ApiException {
          if (!mounted) {
            return;
          }
          _restorePayload(pending.payload);
          _syncStatus = _JournalSyncStatus.unsent;
          _recoveryNotice =
              'Сохранённая запись ожидает подтверждения сервера. Повторите отправку позже.';
        }
      } else {
        _restorePayload(pending.payload);
        _syncStatus = _JournalSyncStatus.queued;
        _recoveryNotice =
            'Операция поставлена в очередь. Повторите отправку после восстановления связи.';
      }
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _recoveryFailed = true;
          _syncStatus = _JournalSyncStatus.unsent;
          _recoveryNotice =
              'Не удалось проверить сохранённую операцию. Повторите позже.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  void _restoreEntry(ConstructionJournalEntryModel entry) {
    _entryDate = DateTime.tryParse(entry.entryDate);
    _selectedEstimateId = entry.estimateId;
    _descriptionController.text = entry.workDescription;
    _problemsController.text = entry.problemsDescription ?? '';
    _safetyController.text = entry.safetyNotes ?? '';
    _visitorsController.text = entry.visitorsNotes ?? '';
    _qualityController.text = entry.qualityNotes ?? '';
    _temperatureController.text =
        entry.weatherConditions?.temperature?.toString() ?? '';
    _precipitationController.text =
        entry.weatherConditions?.precipitation ?? '';
    _windSpeedController.text =
        entry.weatherConditions?.windSpeed?.toString() ?? '';
    for (final item in _workVolumes) {
      item.dispose();
    }
    for (final item in _materials) {
      item.dispose();
    }
    for (final item in _workers) {
      item.dispose();
    }
    for (final item in _equipment) {
      item.dispose();
    }
    _workVolumes
      ..clear()
      ..addAll(entry.workVolumes.map(_WorkVolumeInput.fromModel));
    _materials
      ..clear()
      ..addAll(entry.materials.map(_MaterialUsageInput.fromModel));
    _workers
      ..clear()
      ..addAll(entry.workers.map(_WorkerInput.fromModel));
    _equipment
      ..clear()
      ..addAll(entry.equipment.map(_EquipmentInput.fromModel));
  }

  void _restorePayload(Map<String, dynamic> payload) {
    _entryDate = DateTime.tryParse(payload['entry_date']?.toString() ?? '');
    _descriptionController.text = payload['work_description']?.toString() ?? '';
    _problemsController.text =
        payload['problems_description']?.toString() ?? '';
    _safetyController.text = payload['safety_notes']?.toString() ?? '';
    _visitorsController.text = payload['visitors_notes']?.toString() ?? '';
    _qualityController.text = payload['quality_notes']?.toString() ?? '';
    final weather = payload['weather_conditions'];
    if (weather is Map) {
      final values = weather.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      _temperatureController.text = values['temperature']?.toString() ?? '';
      _precipitationController.text = values['precipitation']?.toString() ?? '';
      _windSpeedController.text = values['wind_speed']?.toString() ?? '';
    }
    try {
      final workVolumes = _payloadModels(
        payload['work_volumes'],
        ConstructionJournalWorkVolumeModel.fromJson,
      );
      final materials = _payloadModels(
        payload['materials'],
        ConstructionJournalMaterialUsageModel.fromJson,
      );
      final workers = _payloadModels(
        payload['workers'],
        ConstructionJournalWorkerModel.fromJson,
      );
      final equipment = _payloadModels(
        payload['equipment'],
        ConstructionJournalEquipmentModel.fromJson,
      );
      _workVolumes.addAll(workVolumes.map(_WorkVolumeInput.fromModel));
      _materials.addAll(materials.map(_MaterialUsageInput.fromModel));
      _workers.addAll(workers.map(_WorkerInput.fromModel));
      _equipment.addAll(equipment.map(_EquipmentInput.fromModel));
    } catch (_) {}
  }

  List<T> _payloadModels<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _problemsController.dispose();
    _safetyController.dispose();
    _visitorsController.dispose();
    _qualityController.dispose();
    _temperatureController.dispose();
    _precipitationController.dispose();
    _windSpeedController.dispose();
    for (final volume in _workVolumes) {
      volume.dispose();
    }
    for (final material in _materials) {
      material.dispose();
    }
    for (final worker in _workers) {
      worker.dispose();
    }
    for (final item in _equipment) {
      item.dispose();
    }
    _formScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recoveryFailed || (_pendingOperation != null && !_hasRecoveredEntry)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Восстановление записи')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_syncStatusText ?? ''),
              if ((_syncStatusText ?? '').isNotEmpty) const SizedBox(height: 12),
              Text(
                _recoveryNotice ??
                    'Создание записи на сервере ещё не подтверждено.',
              ),
              const SizedBox(height: 16),
              Text(
                _pendingOperation?.payload['work_description']?.toString() ??
                    '',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    _isSaving || _isRestoring
                        ? null
                        : () {
                          if (_recoveryFailed) {
                            setState(() => _isRestoring = true);
                            _restorePendingOperation();
                          } else {
                            _save(
                              isDraft:
                                  _pendingOperation?.payload['submit_intent'] !=
                                  true,
                            );
                          }
                        },
                child: const Text('Продолжить отправку'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование записи' : 'Новая запись'),
      ),
      body: ListView(
        controller: _formScrollController,
        padding: const EdgeInsets.all(16),
        children: [
          if (_syncStatusText != null)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_syncStatusText!),
              ),
            ),
          if (_recoveryNotice != null && _recoveryNotice != _syncStatusText)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_recoveryNotice!),
              ),
            ),
          if (_visibleRelatedWorks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Связанные работы',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._visibleRelatedWorks.map(
              (work) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(work.displayLabel),
              ),
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Дата записи'),
            subtitle: Text(
              _entryDate == null ? 'Выберите дату' : _formatDate(_entryDate!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          _buildEstimateSelector(),
          const SizedBox(height: 12),
          _buildField(
            controller: _descriptionController,
            label: 'Описание работ',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          _buildWeather(),
          const SizedBox(height: 16),
          _buildWorkVolumes(),
          const SizedBox(height: 16),
          _buildWorkers(),
          const SizedBox(height: 16),
          _buildEquipment(),
          const SizedBox(height: 16),
          _buildMaterials(),
          const SizedBox(height: 16),
          _buildField(
            controller: _problemsController,
            label: 'Проблемы',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _safetyController,
            label: 'Замечания по безопасности',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _visitorsController,
            label: 'Замечания посетителей',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _qualityController,
            label: 'Замечания по качеству',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSaving || _isRestoring
                          ? null
                          : () => _save(isDraft: true),
                  child: const Text('Сохранить черновик'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isSaving || _isRestoring
                          ? null
                          : () => _save(isDraft: false),
                  child: const Text('Отправить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateSelector() {
    return DropdownButtonFormField<int>(
      value:
          _estimates.any((estimate) => estimate.id == _selectedEstimateId)
              ? _selectedEstimateId
              : null,
      decoration: InputDecoration(
        labelText: 'Смета',
        helperText: _isLoadingOptions ? 'Загрузка смет и видов работ...' : null,
        border: const OutlineInputBorder(),
      ),
      items:
          _estimates
              .map(
                (estimate) => DropdownMenuItem<int>(
                  value: estimate.id,
                  child: Text(estimate.displayName),
                ),
              )
              .toList(),
      onChanged: (value) {
        setState(() {
          _selectedEstimateId = value;
          _selectedEstimateItemId = null;
        });
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildWorkVolumes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Объемы выполненных работ',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_selectedEstimateId != null) _buildEstimateItemPicker(),
        if (_workVolumes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Список работ пуст. Выберите позицию из утвержденной сметы.',
            ),
          ),
        ..._workVolumes.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _WorkVolumeCard(
              input: entry.value,
              workTypes: _workTypes,
              onChanged: () => setState(() {}),
              onRemove: () {
                setState(() {
                  _workVolumes.removeAt(entry.key).dispose();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeather() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Погодные условия',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _numberField(_temperatureController, 'Температура, °C'),
            ),
            const SizedBox(width: 8),
            Expanded(child: _numberField(_windSpeedController, 'Ветер, м/с')),
          ],
        ),
        const SizedBox(height: 8),
        _buildField(
          controller: _precipitationController,
          label: 'Осадки и состояние погоды',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9,.]'))],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildWorkers() {
    return _buildResourceSection(
      title: 'Работники',
      emptyText: 'Работники не указаны.',
      addLabel: 'Добавить работников',
      onAdd: () => setState(() => _workers.add(_WorkerInput())),
      children:
          _workers
              .asMap()
              .entries
              .map(
                (entry) => _WorkerCard(
                  input: entry.value,
                  onRemove:
                      () => setState(
                        () => _workers.removeAt(entry.key).dispose(),
                      ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildEquipment() {
    return _buildResourceSection(
      title: 'Техника',
      emptyText: 'Техника не указана.',
      addLabel: 'Добавить технику',
      onAdd: () => setState(() => _equipment.add(_EquipmentInput())),
      children:
          _equipment
              .asMap()
              .entries
              .map(
                (entry) => _EquipmentCard(
                  input: entry.value,
                  onRemove:
                      () => setState(
                        () => _equipment.removeAt(entry.key).dispose(),
                      ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildResourceSection({
    required String title,
    required String emptyText,
    required String addLabel,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(emptyText),
          ),
        ...children,
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: Text(addLabel),
        ),
      ],
    );
  }

  Widget _buildMaterials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Материалы объекта',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_projectMaterials.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Принятых материалов по объекту пока нет. После приемки доставки они появятся в этом списке.',
            ),
          )
        else ...[
          if (_custodyMaterials.isNotEmpty) ...[
            const Text('У меня на ответственности'),
            const SizedBox(height: 8),
            _buildMaterialPicker(
              label: 'Добавить материал со своей ответственности',
              materials: _custodyMaterials,
            ),
          ],
          if (_objectMaterials.isNotEmpty) ...[
            if (_custodyMaterials.isNotEmpty) const SizedBox(height: 12),
            const Text('На объекте'),
            const SizedBox(height: 8),
            _buildMaterialPicker(
              label: 'Добавить принятый материал',
              materials: _objectMaterials,
            ),
          ],
        ],
        ..._materials.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _MaterialUsageCard(
              input: entry.value,
              onRemove: () {
                setState(() {
                  _materials.removeAt(entry.key).dispose();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialPicker({
    required String label,
    required List<ConstructionJournalProjectMaterialOption> materials,
  }) {
    return DropdownButtonFormField<int>(
      value: null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items:
          materials
              .map(
                (material) => DropdownMenuItem<int>(
                  value: material.deliveryId,
                  child: Text(
                    '${material.materialName} · ${_formatMaterialQuantity(material.availableQuantity)} ${material.measurementUnit}',
                  ),
                ),
              )
              .toList(),
      onChanged: _addProjectMaterial,
    );
  }

  Widget _buildEstimateItemPicker() {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          value:
              _selectedEstimateItems.any(
                    (item) => item.id == _selectedEstimateItemId,
                  )
                  ? _selectedEstimateItemId
                  : null,
          decoration: const InputDecoration(
            labelText: 'Позиция сметы',
            border: OutlineInputBorder(),
          ),
          items:
              _selectedEstimateItems
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(item.displayName),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            setState(() {
              _selectedEstimateItemId = value;
            });
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed:
                _selectedEstimateItemId == null
                    ? null
                    : _addSelectedEstimateItem,
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Добавить из сметы'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _entryDate = picked;
      });
    }
  }

  Future<void> _loadFormOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final repository = ref.read(constructionJournalRepositoryProvider);
      final options = await repository.fetchEntryFormOptions(widget.journalId);

      if (mounted) {
        setState(() {
          _options = options;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    }
  }

  void _addSelectedEstimateItem() {
    final selected = _selectedEstimateItems.where(
      (item) => item.id == _selectedEstimateItemId,
    );

    if (selected.isEmpty) {
      return;
    }

    final item = selected.first;
    setState(() {
      _workVolumes.add(
        _WorkVolumeInput.fromEstimateItem(
          item,
          _resolveWorkType(item.workTypeId),
        ),
      );
      _selectedEstimateItemId = null;
    });
  }

  ConstructionJournalWorkTypeOption? _resolveWorkType(int? id) {
    if (id == null) {
      return null;
    }

    final found = _workTypes.where((workType) => workType.id == id);
    return found.isEmpty ? null : found.first;
  }

  void _addProjectMaterial(int? deliveryId) {
    if (deliveryId == null) {
      return;
    }

    final selected = _projectMaterials.where(
      (material) => material.deliveryId == deliveryId,
    );

    if (selected.isEmpty) {
      return;
    }

    final material = selected.first;
    setState(() {
      _materials.add(_MaterialUsageInput.fromProjectMaterial(material));
    });
  }

  Future<void> _save({required bool isDraft}) async {
    if (_isSaving || _isRestoring) return;
    final repository = ref.read(constructionJournalRepositoryProvider);
    if (_hasRecoveredEntry) {
      setState(() => _isSaving = true);
      try {
        final current = await repository.fetchEntryDetail(
          _recoveredEntry?.id ?? _pendingOperation!.entryId!,
        );
        if (!mounted) return;
        if (current.status != 'draft') {
          if (_pendingOperation != null) {
            await repository.clearPendingEntryOperation(_pendingOperation!);
            _pendingOperation = null;
          }
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        _recoveredEntry = current;
      } catch (error) {
        if (mounted) AppErrorNotice.show(context, error);
        return;
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showMessage('Добавьте описание работ.');
      return;
    }

    if (_entryDate == null) {
      _showMessage('Выберите дату записи.');
      return;
    }

    final workVolumes = _normalizedWorkVolumes();
    final materials = _normalizedMaterials();
    final workers = _normalizedWorkers();
    final equipment = _normalizedEquipment();
    if (workVolumes.length != _workVolumes.length) {
      _showMessage(
        'Заполните вид работ, количество и единицу измерения для каждой строки.',
      );
      return;
    }

    if (materials.length != _materials.length) {
      _showMessage('Укажите количество для каждого выбранного материала.');
      return;
    }
    if (workers.length != _workers.length) {
      _showMessage('Заполните специальность, количество и часы работников.');
      return;
    }
    if (equipment.length != _equipment.length) {
      _showMessage('Заполните название, количество и часы работы техники.');
      return;
    }

    final weather = _normalizedWeather();

    if (!isDraft && workVolumes.isEmpty) {
      _showMessage('Добавьте хотя бы один объем выполненных работ.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEdit) {
        final updatedEntry = await repository.updateEntry(
          entryId: widget.initialEntry!.id,
          entryDate: _entryDate!.toIso8601String().split('T').first,
          workDescription: _descriptionController.text.trim(),
          estimateId: _selectedEstimateId,
          problemsDescription: _problemsController.text.trim(),
          safetyNotes: _safetyController.text.trim(),
          visitorsNotes: _visitorsController.text.trim(),
          qualityNotes: _qualityController.text.trim(),
          weatherConditions: weather,
          workVolumes: workVolumes,
          workers: workers,
          equipment: equipment,
          materials: materials,
        );
        if (!isDraft) {
          await repository.submitEntry(
            updatedEntry.id,
            journalId: widget.journalId,
          );
        }
      } else if (_hasRecoveredEntry) {
        final recoveredId = _recoveredEntry?.id ?? _pendingOperation!.entryId!;
        final updatedEntry = await repository.updateEntry(
          entryId: recoveredId,
          entryDate: _entryDate!.toIso8601String().split('T').first,
          workDescription: _descriptionController.text.trim(),
          estimateId: _selectedEstimateId,
          problemsDescription: _problemsController.text.trim(),
          safetyNotes: _safetyController.text.trim(),
          visitorsNotes: _visitorsController.text.trim(),
          qualityNotes: _qualityController.text.trim(),
          weatherConditions: weather,
          workVolumes: workVolumes,
          workers: workers,
          equipment: equipment,
          materials: materials,
        );
        if (!isDraft) {
          await repository.submitEntry(
            updatedEntry.id,
            journalId: widget.journalId,
            idempotencyKey:
                _submitOperationKey ??=
                    '${_operationKey ?? _newLocalKey()}:submit',
          );
        }
        if (_pendingOperation != null) {
          await repository.clearPendingEntryOperation(_pendingOperation!);
          _pendingOperation = null;
        }
      } else if (_pendingOperation != null &&
          _pendingOperation!.entryId == null) {
        final createdEntry = await repository.retryPendingCreate(
          _pendingOperation!,
        );
        final pendingSubmit =
            _pendingOperation?.payload['submit_intent'] == true;
        if (pendingSubmit) {
          _recoveredEntry = createdEntry;
          _submitOperationKey ??= '$_operationKey:submit';
          await repository.submitEntry(
            createdEntry.id,
            journalId: widget.journalId,
            idempotencyKey: _submitOperationKey,
          );
        }
        if (_pendingOperation != null) {
          await repository.clearPendingEntryOperation(_pendingOperation!);
          _pendingOperation = null;
        }
      } else {
        _operationKey ??= _newLocalKey();
        final createdEntry = await repository.createEntry(
          journalId: widget.journalId,
          entryDate: _entryDate!.toIso8601String().split('T').first,
          workDescription: _descriptionController.text.trim(),
          estimateId: _selectedEstimateId,
          problemsDescription: _problemsController.text.trim(),
          safetyNotes: _safetyController.text.trim(),
          visitorsNotes: _visitorsController.text.trim(),
          qualityNotes: _qualityController.text.trim(),
          weatherConditions: weather,
          workVolumes: workVolumes,
          workers: workers,
          equipment: equipment,
          materials: materials,
          submitAfterCreate: false,
          submitIntent: !isDraft,
          idempotencyKey: _operationKey,
        );
        if (!isDraft) {
          _recoveredEntry = createdEntry;
          _submitOperationKey ??= '$_operationKey:submit';
          _pendingOperation = await repository.findPendingEntryOperation(
            widget.journalId,
          );
          await repository.submitEntry(
            createdEntry.id,
            journalId: widget.journalId,
            idempotencyKey: _submitOperationKey,
          );
        }
        if (_pendingOperation != null) {
          await repository.clearPendingEntryOperation(_pendingOperation!);
          _pendingOperation = null;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!_isEdit) {
        _pendingOperation = await repository.findPendingEntryOperation(
          widget.journalId,
        );
      }
      if (mounted) {
        if (error is ApiException &&
            error.statusCode == 422 &&
            !_hasRecoveredEntry &&
            _pendingOperation?.payload['submit_after_create'] != true) {
          if (_pendingOperation != null) {
            await repository.clearPendingEntryOperation(_pendingOperation!);
            _pendingOperation = null;
          }
          _operationKey = null;
          _submitOperationKey = null;
        }
        if (!mounted) return;
        final rejection =
            error is ApiException && error.statusCode == 422
                ? error.message.trim()
                : '';
        setState(() {
          if (error is SyncQueuedException) {
            _syncStatus = _JournalSyncStatus.queued;
            _recoveryNotice =
                'Операция поставлена в очередь. Повторите отправку после восстановления связи.';
          } else if (rejection.isNotEmpty) {
            _syncStatus = _JournalSyncStatus.rejected;
            _serverRejectionReason = rejection;
            _recoveryNotice = 'Отклонено сервером: $rejection';
          } else if (_hasRecoveredEntry) {
            _syncStatus = _JournalSyncStatus.unsent;
            _recoveryNotice =
                'Запись сохранена локально. Исправьте данные и повторите отправку.';
          } else if (_pendingOperation == null) {
            _syncStatus = _JournalSyncStatus.unsent;
            _recoveryNotice =
                'Операция не подтверждена сервером и будет повторена с тем же ключом.';
          } else {
            _syncStatus = _JournalSyncStatus.unsent;
          }
        });
        if (_formScrollController.hasClients) {
          _formScrollController.jumpTo(0);
        }
        if (mounted) AppErrorNotice.show(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? get _syncStatusText {
    return switch (_syncStatus) {
      _JournalSyncStatus.saved => 'Сохранено',
      _JournalSyncStatus.queued => 'В очереди',
      _JournalSyncStatus.unsent => 'Не отправлено',
      _JournalSyncStatus.rejected =>
        _serverRejectionReason == null || _serverRejectionReason!.isEmpty
            ? 'Отклонено сервером'
            : 'Отклонено сервером: $_serverRejectionReason',
      null => null,
    };
  }

  List<ConstructionJournalRelatedWorkModel> get _visibleRelatedWorks {
    return _recoveredEntry?.completedWorks ??
        widget.initialEntry?.completedWorks ??
        const [];
  }

  String _newLocalKey() {
    final entropy = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'journal-${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  List<ConstructionJournalWorkVolumeModel> _normalizedWorkVolumes() {
    return _workVolumes
        .map((volume) {
          final quantity = double.tryParse(
            volume.quantityController.text.trim().replaceAll(',', '.'),
          );

          if (quantity == null || quantity <= 0) {
            return null;
          }

          if (volume.estimateItemId == null && volume.workTypeId == null) {
            return null;
          }

          if (volume.measurementUnitId == null ||
              (volume.measurementUnitName ?? '').trim().isEmpty) {
            return null;
          }

          return ConstructionJournalWorkVolumeModel(
            id: volume.id,
            estimateItemId: volume.estimateItemId,
            workTypeId: volume.workTypeId,
            quantity: quantity,
            measurementUnitId: volume.measurementUnitId,
            notes: volume.notesController.text,
          );
        })
        .whereType<ConstructionJournalWorkVolumeModel>()
        .toList();
  }

  List<ConstructionJournalMaterialUsageModel> _normalizedMaterials() {
    return _materials
        .map((material) {
          final quantity = double.tryParse(
            material.quantityController.text.trim().replaceAll(',', '.'),
          );

          if (quantity == null || quantity <= 0) {
            return null;
          }

          return ConstructionJournalMaterialUsageModel(
            materialId: material.materialId,
            estimateItemId: material.estimateItemId,
            projectMaterialDeliveryId: material.projectMaterialDeliveryId,
            custodyWarehouseId: material.custodyWarehouseId,
            materialName: material.materialName,
            quantity: quantity,
            measurementUnit: material.measurementUnit,
            notes: material.notesController.text,
          );
        })
        .whereType<ConstructionJournalMaterialUsageModel>()
        .toList();
  }

  ConstructionJournalWeatherModel? _normalizedWeather() {
    final temperature = _parseDecimal(_temperatureController.text);
    final windSpeed = _parseDecimal(_windSpeedController.text);
    final precipitation = _precipitationController.text.trim();
    if (temperature == null && windSpeed == null && precipitation.isEmpty) {
      return null;
    }
    return ConstructionJournalWeatherModel(
      temperature: temperature,
      windSpeed: windSpeed,
      precipitation: precipitation,
    );
  }

  List<ConstructionJournalWorkerModel> _normalizedWorkers() =>
      _workers
          .map((worker) {
            final count = int.tryParse(worker.countController.text.trim());
            final hours = _parseDecimal(worker.hoursController.text);
            if (worker.specialtyController.text.trim().isEmpty ||
                count == null ||
                count < 1 ||
                hours == null ||
                hours < 0) {
              return null;
            }
            return ConstructionJournalWorkerModel(
              id: worker.id,
              estimateItemId: worker.estimateItemId,
              specialty: worker.specialtyController.text.trim(),
              workersCount: count,
              hoursWorked: hours,
            );
          })
          .whereType<ConstructionJournalWorkerModel>()
          .toList();

  List<ConstructionJournalEquipmentModel> _normalizedEquipment() =>
      _equipment
          .map((item) {
            final quantity = int.tryParse(item.quantityController.text.trim());
            final hours = _parseDecimal(item.hoursController.text);
            if (item.nameController.text.trim().isEmpty ||
                quantity == null ||
                quantity < 1 ||
                hours == null ||
                hours < 0) {
              return null;
            }
            return ConstructionJournalEquipmentModel(
              id: item.id,
              estimateItemId: item.estimateItemId,
              name: item.nameController.text.trim(),
              type: item.typeController.text.trim(),
              quantity: quantity,
              hoursUsed: hours,
            );
          })
          .whereType<ConstructionJournalEquipmentModel>()
          .toList();

  double? _parseDecimal(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WorkVolumeCard extends StatelessWidget {
  const _WorkVolumeCard({
    required this.input,
    required this.workTypes,
    required this.onChanged,
    required this.onRemove,
  });

  final _WorkVolumeInput input;
  final List<ConstructionJournalWorkTypeOption> workTypes;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value:
                        workTypes.any(
                              (workType) => workType.id == input.workTypeId,
                            )
                            ? input.workTypeId
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Вид работ',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        workTypes
                            .map(
                              (workType) => DropdownMenuItem<int>(
                                value: workType.id,
                                child: Text(workType.name),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      final selected = workTypes.where(
                        (workType) => workType.id == value,
                      );
                      input.applyWorkType(
                        selected.isEmpty ? null : selected.first,
                      );
                      onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Удалить строку',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if ((input.sourceLabel ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                input.sourceLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: input.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Количество',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ед. изм.',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(input.measurementUnitName ?? '-'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: input.notesController,
              decoration: const InputDecoration(
                labelText: 'Примечание',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkVolumeInput {
  _WorkVolumeInput({
    this.id,
    this.estimateItemId,
    this.workTypeId,
    this.measurementUnitId,
    this.measurementUnitName,
    this.sourceLabel,
    String quantity = '',
    String notes = '',
  }) : quantityController = TextEditingController(text: quantity),
       notesController = TextEditingController(text: notes);

  final int? id;
  int? estimateItemId;
  int? workTypeId;
  int? measurementUnitId;
  String? measurementUnitName;
  String? sourceLabel;
  final TextEditingController quantityController;
  final TextEditingController notesController;

  factory _WorkVolumeInput.fromModel(ConstructionJournalWorkVolumeModel model) {
    return _WorkVolumeInput(
      id: model.id,
      estimateItemId: model.estimateItemId,
      workTypeId: model.workTypeId,
      measurementUnitId: model.measurementUnitId,
      measurementUnitName: model.measurementUnitName,
      sourceLabel: model.title,
      quantity: model.quantity == 0 ? '' : model.quantity.toString(),
      notes: model.notes ?? '',
    );
  }

  factory _WorkVolumeInput.fromEstimateItem(
    ConstructionJournalEstimateItemOption item,
    ConstructionJournalWorkTypeOption? workType,
  ) {
    final measurementUnit = item.measurementUnit ?? workType?.measurementUnit;

    return _WorkVolumeInput(
      estimateItemId: item.id,
      workTypeId: item.workTypeId,
      measurementUnitId: item.measurementUnitId ?? workType?.measurementUnitId,
      measurementUnitName: measurementUnit?.displayName,
      sourceLabel: item.displayName,
      quantity: '',
      notes: 'Позиция сметы: ${item.positionNumber ?? item.name}',
    );
  }

  void applyWorkType(ConstructionJournalWorkTypeOption? workType) {
    workTypeId = workType?.id;
    measurementUnitId = workType?.measurementUnitId;
    measurementUnitName = workType?.measurementUnit?.displayName;
  }

  void dispose() {
    quantityController.dispose();
    notesController.dispose();
  }
}

class _MaterialUsageCard extends StatelessWidget {
  const _MaterialUsageCard({required this.input, required this.onRemove});

  final _MaterialUsageInput input;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    input.materialName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Удалить материал',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: input.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Списано в работу',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ед. изм.',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(input.measurementUnit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: input.notesController,
              decoration: const InputDecoration(
                labelText: 'Примечание',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.input, required this.onRemove});

  final _WorkerInput input;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input.specialtyController,
                    decoration: const InputDecoration(
                      labelText: 'Специальность',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _compactNumberField(
                    input.countController,
                    'Количество',
                    decimal: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _compactNumberField(input.hoursController, 'Часы'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.input, required this.onRemove});

  final _EquipmentInput input;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Наименование',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              controller: input.typeController,
              decoration: const InputDecoration(labelText: 'Тип техники'),
            ),
            Row(
              children: [
                Expanded(
                  child: _compactNumberField(
                    input.quantityController,
                    'Количество',
                    decimal: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _compactNumberField(input.hoursController, 'Моточасы'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _compactNumberField(
  TextEditingController controller,
  String label, {
  bool decimal = true,
}) {
  return TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        decimal ? RegExp(r'[0-9,.]') : RegExp(r'[0-9]'),
      ),
    ],
    decoration: InputDecoration(labelText: label),
  );
}

class _WorkerInput {
  _WorkerInput({
    this.id,
    this.estimateItemId,
    String specialty = '',
    String count = '1',
    String hours = '',
  }) : specialtyController = TextEditingController(text: specialty),
       countController = TextEditingController(text: count),
       hoursController = TextEditingController(text: hours);

  final int? id;
  final int? estimateItemId;
  final TextEditingController specialtyController;
  final TextEditingController countController;
  final TextEditingController hoursController;

  factory _WorkerInput.fromModel(ConstructionJournalWorkerModel model) =>
      _WorkerInput(
        id: model.id,
        estimateItemId: model.estimateItemId,
        specialty: model.specialty,
        count: model.workersCount.toString(),
        hours: model.hoursWorked?.toString() ?? '',
      );

  void dispose() {
    specialtyController.dispose();
    countController.dispose();
    hoursController.dispose();
  }
}

class _EquipmentInput {
  _EquipmentInput({
    this.id,
    this.estimateItemId,
    String name = '',
    String type = '',
    String quantity = '1',
    String hours = '',
  }) : nameController = TextEditingController(text: name),
       typeController = TextEditingController(text: type),
       quantityController = TextEditingController(text: quantity),
       hoursController = TextEditingController(text: hours);

  final int? id;
  final int? estimateItemId;
  final TextEditingController nameController;
  final TextEditingController typeController;
  final TextEditingController quantityController;
  final TextEditingController hoursController;

  factory _EquipmentInput.fromModel(ConstructionJournalEquipmentModel model) =>
      _EquipmentInput(
        id: model.id,
        estimateItemId: model.estimateItemId,
        name: model.name,
        type: model.type ?? '',
        quantity: model.quantity.toString(),
        hours: model.hoursUsed?.toString() ?? '',
      );

  void dispose() {
    nameController.dispose();
    typeController.dispose();
    quantityController.dispose();
    hoursController.dispose();
  }
}

class _MaterialUsageInput {
  _MaterialUsageInput({
    required this.materialId,
    this.estimateItemId,
    required this.projectMaterialDeliveryId,
    required this.custodyWarehouseId,
    required this.materialName,
    required this.measurementUnit,
    String quantity = '',
    String notes = '',
  }) : quantityController = TextEditingController(text: quantity),
       notesController = TextEditingController(text: notes);

  final int? materialId;
  final int? estimateItemId;
  final int? projectMaterialDeliveryId;
  final int? custodyWarehouseId;
  final String materialName;
  final String measurementUnit;
  final TextEditingController quantityController;
  final TextEditingController notesController;

  factory _MaterialUsageInput.fromProjectMaterial(
    ConstructionJournalProjectMaterialOption material,
  ) {
    return _MaterialUsageInput(
      materialId: material.materialId,
      projectMaterialDeliveryId: material.projectMaterialDeliveryId,
      custodyWarehouseId: material.custodyWarehouseId,
      materialName: material.materialName,
      measurementUnit: material.measurementUnit,
      quantity: '',
      notes:
          material.sourceLabel ??
          (material.custodyWarehouseId == null
              ? 'Материал принят на объект по поставке #${material.deliveryId}'
              : 'Материал списан со склада ответственного'),
    );
  }

  factory _MaterialUsageInput.fromModel(
    ConstructionJournalMaterialUsageModel material,
  ) {
    return _MaterialUsageInput(
      materialId: material.materialId,
      estimateItemId: material.estimateItemId,
      projectMaterialDeliveryId: material.projectMaterialDeliveryId,
      custodyWarehouseId: material.custodyWarehouseId,
      materialName: material.materialName,
      measurementUnit: material.measurementUnit,
      quantity: material.quantity.toString(),
      notes: material.notes ?? '',
    );
  }

  void dispose() {
    quantityController.dispose();
    notesController.dispose();
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatMaterialQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}
