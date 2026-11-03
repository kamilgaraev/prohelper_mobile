import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/incoming_control_model.dart';
import '../data/incoming_control_upload.dart';
import '../data/quality_photo_picker.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../domain/incoming_control_provider.dart';
import '../data/incoming_control_draft_store.dart';

class IncomingControlFields extends ConsumerStatefulWidget {
  const IncomingControlFields({
    super.key,
    required this.references,
    this.initial = const {},
    this.quantity,
    this.canComplete = true,
    this.identityEditable = true,
    this.canAccept = true,
    this.canReject = true,
    this.draftId,
    this.projectId,
    this.draftContext = const {},
    this.onRestoreContext,
    this.draftContextBuilder,
    this.materialId,
    this.materialResolvedBySource = false,
  });
  final IncomingControlReferences references;
  final Map<String, dynamic> initial;
  final double? quantity;
  final bool canComplete;
  final bool identityEditable;
  final bool canAccept;
  final bool canReject;
  final String? draftId;
  final int? projectId;
  final Map<String, dynamic> draftContext;
  final ValueChanged<Map<String, dynamic>>? onRestoreContext;
  final Map<String, dynamic> Function()? draftContextBuilder;
  final int? materialId;
  final bool materialResolvedBySource;

  @override
  ConsumerState<IncomingControlFields> createState() =>
      IncomingControlFieldsState();
}

Future<IncomingControlUpload?> pickIncomingControlDocument(
  BuildContext context, {
  String? batchNumber,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    withData: false,
  );
  final path = result?.files.single.path;
  if (path == null || !context.mounted) return null;
  final metadata = await showDialog<Map<String, String>>(
    context: context,
    builder:
        (_) => _IncomingControlDocumentMetadataDialog(batchNumber: batchNumber),
  );
  return metadata == null
      ? null
      : IncomingControlUpload(
        path: path,
        kind: 'quality_document',
        metadata: metadata,
      );
}

class _IncomingControlDocumentMetadataDialog extends StatefulWidget {
  const _IncomingControlDocumentMetadataDialog({this.batchNumber});
  final String? batchNumber;
  @override
  State<_IncomingControlDocumentMetadataDialog> createState() =>
      _IncomingControlDocumentMetadataDialogState();
}

class _IncomingControlDocumentMetadataDialogState
    extends State<_IncomingControlDocumentMetadataDialog> {
  final _form = GlobalKey<FormState>();
  late final _controllers = <String, TextEditingController>{
    'document_number': TextEditingController(),
    'document_date': TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    ),
    'issuer': TextEditingController(),
    'coverage_batch_number': TextEditingController(text: widget.batchNumber),
  };
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Документ качества'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Документ подтверждает конкретную партию. Фотография осмотра не заменяет паспорт.',
            ),
            for (final entry
                in {
                  'document_number': 'Номер документа',
                  'document_date': 'Дата документа, ГГГГ-ММ-ДД',
                  'issuer': 'Кем выдан',
                  'coverage_batch_number': 'Партия или серийный номер',
                }.entries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextFormField(
                  controller: _controllers[entry.key],
                  decoration: InputDecoration(labelText: entry.value),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Заполните поле';
                    }
                    if (entry.key == 'document_date' &&
                        (!RegExp(
                              r'^\d{4}-\d{2}-\d{2}$',
                            ).hasMatch(value.trim()) ||
                            DateTime.tryParse(
                                  value.trim(),
                                )?.toIso8601String().substring(0, 10) !=
                                value.trim())) {
                      return 'Укажите корректную дату';
                    }
                    return null;
                  },
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState?.validate() == true) {
            Navigator.pop(context, {
              for (final entry in _controllers.entries)
                entry.key: entry.value.text.trim(),
            });
          }
        },
        child: const Text('Добавить'),
      ),
    ],
  );
}

class IncomingControlFieldsState extends ConsumerState<IncomingControlFields> {
  final _controllers = <String, TextEditingController>{};
  final _documents = <String, Map<String, dynamic>>{};
  final _workTypeIds = <int>{};
  final _files = <IncomingControlUpload>[];
  List<IncomingControlUpload> get files => List.unmodifiable(_files);
  bool _complete = true;
  bool _testingRequired = false;
  String _inspection = 'not_checked';
  String _documentsResult = 'not_checked';
  DateTime _receivedAt = DateTime.now();
  bool _restoring = false;
  bool _savingDraft = false;
  String? _draftNotice;
  final _restoredFiles = <IncomingControlUpload>[];
  IncomingControlDraftStore? _draftStore;
  String? _coverageConfirmedFor;
  String get _batchIdentity =>
      _controllers['batch_number']!.text.trim().isNotEmpty
          ? _controllers['batch_number']!.text.trim()
          : _controllers['serial_number']!.text.trim();
  String get _coverageScope => '${widget.materialId}:$_batchIdentity';

  @override
  void initState() {
    super.initState();
    _complete = widget.canComplete;
    _inspection =
        widget.initial['inspection_result']?.toString() ?? 'not_checked';
    _documentsResult =
        widget.initial['documents_result']?.toString() ?? 'not_checked';
    _testingRequired = widget.initial['testing_required'] == true;
    for (final id
        in (widget.initial['permitted_work_type_ids'] as List? ?? [])) {
      if (int.tryParse(id.toString()) case final int value) {
        _workTypeIds.add(value);
      }
    }
    _receivedAt =
        DateTime.tryParse(widget.initial['received_at']?.toString() ?? '') ??
        DateTime.now();
    for (final field in [
      'document_quantity',
      'presented_quantity',
      'accepted_quantity',
      'pending_quantity',
      'rejected_quantity',
      'location_name',
      'supplier_name',
      'manufacturer_name',
      'batch_number',
      'serial_number',
      'reason',
      'restrictions',
      'custodian_name',
      'authority_basis',
      'testing_basis',
      'testing_result',
    ]) {
      final defaultQuantity =
          ['document_quantity', 'presented_quantity'].contains(field) ||
          (field == 'accepted_quantity' &&
              widget.canComplete &&
              widget.canAccept) ||
          (field == 'pending_quantity' &&
              (!widget.canComplete || !widget.canAccept));
      final value =
          widget.initial[field] ??
          (field.endsWith('_quantity')
              ? (defaultQuantity ? widget.quantity ?? 0 : 0)
              : '');
      _controllers[field] = TextEditingController(text: value.toString());
    }
    if (!_complete) _holdPresentedQuantity();
    for (final document in incomingMaps(
      widget.initial['quality_document_versions'],
    )) {
      final coverage = incomingMap(document['coverage']);
      final batch = coverage['batch_number']?.toString().trim() ?? '';
      final serial = coverage['serial_number']?.toString().trim() ?? '';
      final confirmedSnapshot =
          coverage['confirmed_by'] != null &&
          (coverage['confirmed_at']?.toString().isNotEmpty ?? false) &&
          (widget.projectId == null ||
              coverage['project_id'].toString() == widget.projectId.toString());
      _documents['${document['document_id']}:${document['version_id']}'] = {
        ...document,
        if (confirmedSnapshot) ...{
          'coverage_confirmed': true,
          'coverage_material_id': coverage['material_id'],
          'coverage_batch_number': batch.isNotEmpty ? batch : serial,
        },
      };
    }
    if (_documents.isNotEmpty &&
        _documents.values.every(
          (document) =>
              document['coverage_confirmed'] == true &&
              document['coverage_material_id'].toString() ==
                  widget.materialId.toString() &&
              document['coverage_batch_number'] == _batchIdentity,
        )) {
      _coverageConfirmedFor = _coverageScope;
    }
    if (widget.draftId != null &&
        widget.projectId != null &&
        ref.read(incomingControlOwnerScopeProvider) != null) {
      _draftStore = ref.read(incomingControlDraftStoreProvider);
      _restoring = true;
      unawaited(_restoreDraft());
    }
  }

  Future<void> _restoreDraft() async {
    final store = _draftStore!;
    try {
      final draft = await store.read(widget.draftId!, widget.projectId!);
      if (!mounted) {
        if (draft != null) await store.releaseFiles(draft.files);
        return;
      }
      if (draft != null) {
        final state = draft.state;
        for (final entry in incomingMap(state['values']).entries) {
          _controllers[entry.key]?.text = entry.value.toString();
        }
        _inspection = state['inspection_result']?.toString() ?? 'not_checked';
        _documentsResult =
            state['documents_result']?.toString() ?? 'not_checked';
        _complete = state['complete'] == true && widget.canComplete;
        if (!_complete) _holdPresentedQuantity();
        _testingRequired = state['testing_required'] == true;
        _receivedAt =
            DateTime.tryParse(state['received_at']?.toString() ?? '') ??
            _receivedAt;
        _documents.clear();
        _coverageConfirmedFor = state['coverage_confirmed_for']?.toString();
        for (final document in incomingMaps(
          state['quality_document_versions'],
        )) {
          _documents['${document['document_id']}:${document['version_id']}'] =
              document;
        }
        _workTypeIds.clear();
        for (final id in (state['permitted_work_type_ids'] as List? ?? [])) {
          if (int.tryParse(id.toString()) case final int value) {
            _workTypeIds.add(value);
          }
        }
        _files.addAll(draft.files);
        _restoredFiles.addAll(draft.files);
        widget.onRestoreContext?.call(incomingMap(state['context']));
        _draftNotice =
            'Восстановлен черновик с устройства. Приход и допуск не подтверждены сервером.';
      }
    } catch (_) {
      if (mounted) {
        _draftNotice =
            'Не удалось восстановить черновик. Проверьте сохранённые файлы перед отправкой.';
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _saveDraft() async {
    if (_savingDraft || _restoring) return;
    setState(() => _savingDraft = true);
    try {
      await ref.read(incomingControlDraftStoreProvider).save(
        widget.draftId!,
        widget.projectId!,
        {
          'values': {
            for (final entry in _controllers.entries)
              entry.key: entry.value.text,
          },
          'inspection_result': _inspection,
          'documents_result': _documentsResult,
          'complete': _complete,
          'testing_required': _testingRequired,
          'received_at': _receivedAt.toIso8601String(),
          'quality_document_versions': _documents.values.toList(),
          'coverage_confirmed_for': _coverageConfirmedFor,
          'permitted_work_type_ids': _workTypeIds.toList(),
          'context': widget.draftContextBuilder?.call() ?? widget.draftContext,
        },
        files,
      );
      if (mounted) {
        setState(
          () =>
              _draftNotice =
                  'Черновик и файлы сохранены на устройстве. Приход и допуск не подтверждены сервером.',
        );
      }
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> clearDraft() async {
    if (widget.draftId == null ||
        widget.projectId == null ||
        ref.read(incomingControlOwnerScopeProvider) == null) {
      return;
    }
    await ref
        .read(incomingControlDraftStoreProvider)
        .clear(widget.draftId!, widget.projectId!);
  }

  IncomingControlRestoredFileLease? transferRestoredFiles() {
    if (_restoredFiles.isEmpty || _draftStore == null) return null;
    final lease = IncomingControlRestoredFileLease(
      List.unmodifiable(_restoredFiles),
      _draftStore!.releaseFiles,
    );
    _restoredFiles.clear();
    return lease;
  }

  void _holdPresentedQuantity() {
    _controllers['accepted_quantity']!.text = '0';
    _controllers['rejected_quantity']!.text = '0';
    _controllers['pending_quantity']!.text =
        _controllers['presented_quantity']!.text;
    if (_controllers['reason']!.text.trim().isEmpty) {
      _controllers['reason']!.text = 'Проверка не завершена';
    }
  }

  @override
  void dispose() {
    if (_restoredFiles.isNotEmpty && _draftStore != null) {
      unawaited(_draftStore!.releaseFiles(_restoredFiles));
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> payload() {
    if (_restoring) {
      throw const FormatException('Дождитесь восстановления черновика.');
    }
    if (_documents.isNotEmpty &&
        ((widget.materialId == null && !widget.materialResolvedBySource) ||
            _batchIdentity.isEmpty ||
            _coverageConfirmedFor != _coverageScope)) {
      throw const FormatException(
        'Подтвердите, что выбранный документ относится к этому материалу и партии.',
      );
    }
    double parse(String name) =>
        double.tryParse(_controllers[name]!.text.trim().replaceAll(',', '.')) ??
        double.nan;
    final quantities = IncomingControlQuantities(
      document: parse('document_quantity'),
      presented: parse('presented_quantity'),
      accepted: parse('accepted_quantity'),
      pending: parse('pending_quantity'),
      rejected: parse('rejected_quantity'),
    );
    if (quantities.validationError case final String error) {
      throw FormatException(error);
    }
    if (_complete &&
        quantities.accepted > 0 &&
        (_inspection != 'compliant' || _documentsResult != 'compliant')) {
      throw const FormatException(
        'Подтвердите соответствие документов и результата осмотра перед допуском материала.',
      );
    }
    if (_controllers['location_name']!.text.trim().isEmpty) {
      throw const FormatException('Укажите место приёмки.');
    }
    if (widget.references.policy['require_batch_number'] == true &&
        _controllers['batch_number']!.text.trim().isEmpty) {
      throw const FormatException('Укажите номер партии.');
    }
    if (_complete &&
        quantities.accepted > 0 &&
        widget.references.policy['mandatory_documents'] == true &&
        _documents.isEmpty &&
        !_files.any((file) => file.kind == 'quality_document') &&
        !incomingMaps(
          widget.initial['attachments'],
        ).any((file) => file['kind'] == 'quality_document')) {
      throw const FormatException(
        'Выберите паспорт или другой документ качества с версией.',
      );
    }
    for (final file in _files.where(
      (file) => file.kind == 'quality_document',
    )) {
      final coverage = file.metadata['coverage_batch_number'];
      if (coverage != _controllers['batch_number']!.text.trim() &&
          coverage != _controllers['serial_number']!.text.trim()) {
        throw const FormatException(
          'Документ качества должен подтверждать указанную партию или серийный номер.',
        );
      }
    }
    if (_complete && quantities.accepted > 0 && !widget.canAccept) {
      throw const FormatException(
        'Нет полномочий допустить материал. Передайте проверку уполномоченному сотруднику.',
      );
    }
    if (_complete && quantities.rejected > 0 && !widget.canReject) {
      throw const FormatException(
        'Нет полномочий отклонить материал. Передайте проверку уполномоченному сотруднику.',
      );
    }
    if ((quantities.rejected > 0 ||
            quantities.pending > 0 ||
            _inspection != 'compliant' ||
            _documentsResult != 'compliant') &&
        _controllers['reason']!.text.trim().isEmpty) {
      throw const FormatException(
        'Укажите причину отказа или ожидания решения.',
      );
    }
    if (quantities.pending > 0 &&
        _controllers['custodian_name']!.text.trim().isEmpty) {
      throw const FormatException(
        'Укажите хранителя ожидающего решения материала.',
      );
    }
    if (_testingRequired &&
        _controllers['testing_basis']!.text.trim().isEmpty) {
      throw const FormatException(
        'Укажите основание дополнительных испытаний.',
      );
    }
    if (_controllers['restrictions']!.text.trim().isNotEmpty &&
        _workTypeIds.isEmpty) {
      throw const FormatException(
        'Выберите виды работ, для которых разрешено использование материала.',
      );
    }
    return {
      ...quantities.toJson(),
      for (final entry in _controllers.entries.where(
        (entry) => !entry.key.endsWith('_quantity'),
      ))
        entry.key: entry.value.text.trim(),
      'received_at': _receivedAt.toIso8601String(),
      'inspection_result': _inspection,
      'documents_result': _documentsResult,
      'testing_required': _testingRequired,
      'complete': _complete && widget.canComplete,
      'quality_document_versions':
          _documents.values
              .map(
                (document) => {
                  'document_id': document['document_id'],
                  'version_id': document['version_id'],
                  'coverage_confirmed': true,
                  if (widget.materialId != null)
                    'coverage_material_id': widget.materialId,
                  'coverage_batch_number': _batchIdentity,
                },
              )
              .toList(),
      'permitted_work_type_ids': _workTypeIds.toList(),
    };
  }

  Widget _field(
    String name,
    String label, {
    bool quantity = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _controllers[name],
      keyboardType:
          quantity
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.multiline,
      maxLines: lines,
      readOnly:
          (!widget.identityEditable &&
              [
                'document_quantity',
                'presented_quantity',
                'batch_number',
                'serial_number',
              ].contains(name)) ||
          (name == 'accepted_quantity' && (!_complete || !widget.canAccept)) ||
          (name == 'rejected_quantity' && (!_complete || !widget.canReject)) ||
          (name == 'pending_quantity' && !_complete),
      onChanged: (value) {
        if (name == 'presented_quantity' && !_complete) {
          _controllers['pending_quantity']!.text = value;
        }
        if (['batch_number', 'serial_number'].contains(name)) setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final documentOptions = <Map<String, dynamic>>[];
    for (final document in widget.references.qualityDocuments) {
      final versions = incomingMaps(document['versions']);
      if (versions.isEmpty && document['version_id'] != null) {
        documentOptions.add({
          'document_id': document['document_id'] ?? document['id'],
          'version_id': document['version_id'],
          'label':
              '${document['name'] ?? document['title'] ?? 'Документ'} · версия ${document['version_number'] ?? document['version_id']}',
        });
      }
      for (final version in versions) {
        documentOptions.add({
          'document_id': document['document_id'] ?? document['id'],
          'version_id': version['version_id'] ?? version['id'],
          'label':
              '${document['name'] ?? document['title'] ?? 'Документ'} · версия ${version['version_number'] ?? version['id']}',
        });
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_restoring) const LinearProgressIndicator(),
        if (_draftNotice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_draftNotice!),
          ),
        if (widget.references.data['from_cache'] == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Показаны сохранённые правила объекта. Актуальные права и допуск проверит сервер после восстановления связи.',
            ),
          ),
        if (widget.draftId != null &&
            widget.projectId != null &&
            ref.watch(incomingControlOwnerScopeProvider) != null)
          TextButton.icon(
            onPressed: _restoring || _savingDraft ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _savingDraft
                  ? 'Сохраняем черновик…'
                  : 'Сохранить черновик на устройстве',
            ),
          ),
        Text('Входной контроль', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed:
              !widget.identityEditable
                  ? null
                  : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _receivedAt,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && mounted) {
                      setState(() => _receivedAt = date);
                    }
                  },
          icon: const Icon(Icons.event_outlined),
          label: Text(
            'Дата приёмки: ${_receivedAt.day.toString().padLeft(2, '0')}.${_receivedAt.month.toString().padLeft(2, '0')}.${_receivedAt.year}',
          ),
        ),
        _field('location_name', 'Место приёмки'),
        _field('supplier_name', 'Поставщик'),
        _field('manufacturer_name', 'Изготовитель'),
        _field('batch_number', 'Партия изготовителя'),
        _field('serial_number', 'Серийный номер оборудования'),
        _field('document_quantity', 'По документам', quantity: true),
        _field('presented_quantity', 'Предъявлено', quantity: true),
        _field('accepted_quantity', 'Принято', quantity: true),
        _field('pending_quantity', 'Ожидает решения', quantity: true),
        _field('rejected_quantity', 'Отклонено', quantity: true),
        const Text('Паспорта и документы качества'),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final file = await pickIncomingControlDocument(
                    context,
                    batchNumber: _controllers['batch_number']!.text,
                  );
                  if (file != null && mounted) setState(() => _files.add(file));
                } catch (error) {
                  if (context.mounted) AppErrorNotice.show(context, error);
                }
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Загрузить паспорт'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final path =
                      await ref
                          .read(qualityPhotoPickerProvider)
                          .pickInitialPhoto();
                  if (path != null && mounted) {
                    setState(
                      () => _files.add(
                        IncomingControlUpload(
                          path: path,
                          kind: 'inspection_photo',
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) AppErrorNotice.show(context, error);
                }
              },
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Фото осмотра'),
            ),
          ],
        ),
        for (final entry in _files.asMap().entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.value.filename),
            subtitle: Text(
              entry.value.kind == 'quality_document'
                  ? 'Документ качества № ${entry.value.metadata['document_number']} · партия ${entry.value.metadata['coverage_batch_number']}'
                  : 'Фото осмотра',
            ),
            trailing: IconButton(
              tooltip: 'Убрать файл',
              onPressed: () => setState(() => _files.removeAt(entry.key)),
              icon: const Icon(Icons.close),
            ),
          ),
        if (documentOptions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Сохранённых версий документов нет. Загрузите паспорт этой партии или сохраните проверку до получения документов.',
            ),
          ),
        for (final document in documentOptions)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(document['label'].toString()),
            value: _documents.containsKey(
              '${document['document_id']}:${document['version_id']}',
            ),
            onChanged:
                (checked) => setState(() {
                  final key =
                      '${document['document_id']}:${document['version_id']}';
                  if (checked == true) {
                    _documents[key] = document;
                    _coverageConfirmedFor = null;
                  } else {
                    _documents.remove(key);
                  }
                }),
          ),
        if (_documents.isNotEmpty)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Документ относится к этому материалу и партии'),
            subtitle: Text(
              _batchIdentity.isEmpty
                  ? 'Укажите партию или серийный номер.'
                  : 'Партия или серийный номер: $_batchIdentity',
            ),
            value: _coverageConfirmedFor == _coverageScope,
            onChanged:
                (widget.materialId == null &&
                            !widget.materialResolvedBySource) ||
                        _batchIdentity.isEmpty
                    ? null
                    : (value) => setState(
                      () =>
                          _coverageConfirmedFor =
                              value == true ? _coverageScope : null,
                    ),
          ),
        const SizedBox(height: 12),
        _result(
          'Сверка документов',
          _documentsResult,
          (value) => setState(() => _documentsResult = value),
        ),
        _result(
          'Осмотр, маркировка и комплектность',
          _inspection,
          (value) => setState(() => _inspection = value),
        ),
        _field('reason', 'Замечания и основание решения', lines: 3),
        _field('restrictions', 'Ограничения использования', lines: 2),
        if (incomingMaps(widget.references.data['work_types']).isNotEmpty) ...[
          const Text('Виды работ, разрешённые при ограничениях'),
          for (final type in incomingMaps(widget.references.data['work_types']))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(type['name']?.toString() ?? 'Вид работ'),
              value: _workTypeIds.contains(int.parse(type['id'].toString())),
              onChanged:
                  (checked) => setState(() {
                    final id = int.parse(type['id'].toString());
                    if (checked == true) {
                      _workTypeIds.add(id);
                    } else {
                      _workTypeIds.remove(id);
                    }
                  }),
            ),
        ],
        _field('custodian_name', 'Ответственный за хранение'),
        _field('authority_basis', 'Основание полномочий проверяющего'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Нужны дополнительные испытания'),
          value: _testingRequired,
          onChanged: (value) => setState(() => _testingRequired = value),
        ),
        if (_testingRequired) ...[
          _field('testing_basis', 'Основание испытаний'),
          _field('testing_result', 'Результат испытаний', lines: 2),
        ],
        if (widget.canComplete)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Завершить проверку и принять решение'),
            subtitle: const Text(
              'Дополнительная задача инженеру не создаётся автоматически.',
            ),
            value: _complete,
            onChanged:
                (value) => setState(() {
                  _complete = value;
                  if (!value) {
                    _holdPresentedQuantity();
                  }
                }),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Данные сохранятся для решения уполномоченного сотрудника.',
            ),
          ),
      ],
    );
  }

  Widget _result(String label, String value, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'compliant', child: Text('Соответствует')),
            DropdownMenuItem(value: 'not_checked', child: Text('Не проверено')),
            DropdownMenuItem(
              value: 'non_compliant',
              child: Text('Не соответствует'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      );
}
