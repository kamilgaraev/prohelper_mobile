import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';

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

class _JournalEntryFormScreenState
    extends ConsumerState<JournalEntryFormScreen> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _problemsController;
  late final TextEditingController _safetyController;
  late final TextEditingController _visitorsController;
  late final TextEditingController _qualityController;
  final List<_WorkVolumeInput> _workVolumes = [];
  late DateTime _entryDate;
  ConstructionJournalEntryFormOptions? _options;
  int? _selectedEstimateId;
  int? _selectedEstimateItemId;
  bool _isLoadingOptions = false;
  bool _isSaving = false;

  bool get _isEdit => widget.initialEntry != null;

  List<ConstructionJournalEstimateOption> get _estimates =>
      _options?.estimates ?? const [];

  List<ConstructionJournalWorkTypeOption> get _workTypes =>
      _options?.workTypes ?? const [];

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
    _entryDate =
        DateTime.tryParse(widget.initialEntry?.entryDate ?? '') ??
        DateTime.now();
    _selectedEstimateId = widget.initialEntry?.estimateId;
    _workVolumes.addAll(
      (widget.initialEntry?.workVolumes ?? const []).map(
        _WorkVolumeInput.fromModel,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFormOptions();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _problemsController.dispose();
    _safetyController.dispose();
    _visitorsController.dispose();
    _qualityController.dispose();
    for (final volume in _workVolumes) {
      volume.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование записи' : 'Новая запись'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Дата записи'),
            subtitle: Text(_formatDate(_entryDate)),
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
          _buildWorkVolumes(),
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
                  onPressed: _isSaving ? null : () => _save(isDraft: true),
                  child: const Text('Сохранить черновик'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(isDraft: false),
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
              'Список работ пуст. Добавьте строку вручную или выберите позицию из сметы.',
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _workVolumes.add(_WorkVolumeInput());
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Добавить вручную'),
        ),
      ],
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
      initialDate: _entryDate,
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

  Future<void> _save({required bool isDraft}) async {
    if (_descriptionController.text.trim().isEmpty) {
      _showMessage('Добавьте описание работ.');
      return;
    }

    final workVolumes = _normalizedWorkVolumes();
    if (!isDraft && workVolumes.isEmpty) {
      _showMessage('Добавьте хотя бы один объем выполненных работ.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(constructionJournalRepositoryProvider);
      final entry =
          _isEdit
              ? await repository.updateEntry(
                entryId: widget.initialEntry!.id,
                entryDate: _entryDate.toIso8601String().split('T').first,
                workDescription: _descriptionController.text.trim(),
                estimateId: _selectedEstimateId,
                problemsDescription: _problemsController.text.trim(),
                safetyNotes: _safetyController.text.trim(),
                visitorsNotes: _visitorsController.text.trim(),
                qualityNotes: _qualityController.text.trim(),
                workVolumes: workVolumes,
              )
              : await repository.createEntry(
                journalId: widget.journalId,
                entryDate: _entryDate.toIso8601String().split('T').first,
                workDescription: _descriptionController.text.trim(),
                estimateId: _selectedEstimateId,
                problemsDescription: _problemsController.text.trim(),
                safetyNotes: _safetyController.text.trim(),
                visitorsNotes: _visitorsController.text.trim(),
                qualityNotes: _qualityController.text.trim(),
                workVolumes: workVolumes,
              );

      if (!isDraft) {
        await repository.submitEntry(entry.id);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
      quantity: item.quantity == 0 ? '' : item.quantity.toString(),
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

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
