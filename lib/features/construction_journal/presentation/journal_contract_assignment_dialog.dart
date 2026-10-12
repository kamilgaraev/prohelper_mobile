import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';
import 'journal_row_contract_picker.dart';

class JournalContractAssignmentDialog extends StatefulWidget {
  const JournalContractAssignmentDialog({
    super.key,
    required this.entry,
    required this.repository,
    required this.isContextCurrent,
  });

  final ConstructionJournalEntryModel entry;
  final ConstructionJournalRepository repository;
  final bool Function() isContextCurrent;

  @override
  State<JournalContractAssignmentDialog> createState() =>
      _JournalContractAssignmentDialogState();
}

class _ContractRow {
  const _ContractRow(
    this.type,
    this.id,
    this.label,
    this.contractId,
    this.contractNumber,
  );
  final String type;
  final int id;
  final String label;
  final int? contractId;
  final String? contractNumber;
  String get key => '$type:$id';
}

class _JournalContractAssignmentDialogState
    extends State<JournalContractAssignmentDialog> {
  final _reason = TextEditingController();
  late final Future<ConstructionJournalEntryFormOptions> _options;
  late final List<_ContractRow> _rows;
  String? _selectedKey;
  int? _contractId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _options = widget.repository.fetchEntryFormOptions(widget.entry.journalId);
    _rows = [
      for (final row in widget.entry.workVolumes)
        if (row.id != null)
          _ContractRow(
            'work-volumes',
            row.id!,
            'Работа: ${row.title ?? row.workName ?? 'Работа'}',
            row.contractId,
            row.contractNumber,
          ),
      for (final row in widget.entry.materials)
        if (row.id != null)
          _ContractRow(
            'materials',
            row.id!,
            'Материал: ${row.materialName}',
            row.contractId,
            row.contractNumber,
          ),
      for (final row in widget.entry.equipment)
        if (row.id != null)
          _ContractRow(
            'equipment',
            row.id!,
            'Техника: ${row.name}',
            row.contractId,
            row.contractNumber,
          ),
      for (final row in widget.entry.workers)
        if (row.id != null)
          _ContractRow(
            'workers',
            row.id!,
            'Труд: ${row.specialty}',
            row.contractId,
            row.contractNumber,
          ),
    ];
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save(_ContractRow row) async {
    if (!widget.isContextCurrent()) {
      setState(
        () =>
            _error =
                'Выбран другой объект или изменился пользователь. Откройте запись заново.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.assignRowContract(
        journalId: widget.entry.journalId,
        entryId: widget.entry.id,
        rowType: row.type,
        rowId: row.id,
        contractId: _contractId,
        reason: _reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  error is ApiException
                      ? error.message
                      : 'Не удалось изменить договор строки.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _rows.where((row) => row.key == _selectedKey).firstOrNull;
    return AlertDialog(
      title: const Text('Договор подтверждённой строки'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: FutureBuilder<ConstructionJournalEntryFormOptions>(
            future: _options,
            builder:
                (context, snapshot) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Объём и подтверждение записи сохраняются. Меняется договор, по которому учитывается выполнение.',
                    ),
                    const SizedBox(height: 16),
                    if (!snapshot.hasData && !snapshot.hasError)
                      const LinearProgressIndicator(),
                    if (snapshot.hasError)
                      const Text(
                        'Не удалось загрузить договоры проекта. Проверьте подключение.',
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedKey,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Строка записи',
                      ),
                      items:
                          _rows
                              .map(
                                (row) => DropdownMenuItem(
                                  value: row.key,
                                  child: Text(
                                    row.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          _saving || !snapshot.hasData
                              ? null
                              : (value) => setState(() {
                                _selectedKey = value;
                                _contractId =
                                    _rows
                                        .where((row) => row.key == value)
                                        .firstOrNull
                                        ?.contractId;
                              }),
                    ),
                    if (selected != null && snapshot.hasData) ...[
                      const SizedBox(height: 16),
                      JournalRowContractPicker(
                        contractId: _contractId,
                        contractNumber: selected.contractNumber,
                        contracts: snapshot.data!.contracts,
                        enabled: !_saving,
                        onChanged:
                            (value) => setState(() => _contractId = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reason,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Причина изменения',
                      ),
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 2000,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed:
              _saving ||
                      selected == null ||
                      _reason.text.trim().isEmpty ||
                      selected.contractId == _contractId
                  ? null
                  : () => _save(selected),
          child: Text(_saving ? 'Сохранение...' : 'Сохранить'),
        ),
      ],
    );
  }
}
