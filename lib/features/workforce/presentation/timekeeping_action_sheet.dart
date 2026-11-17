import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/month_timekeeping_model.dart';
import '../domain/month_timekeeping_provider.dart';

class TimekeepingActionSheet extends ConsumerStatefulWidget {
  const TimekeepingActionSheet({
    super.key,
    required this.period,
    required this.action,
  });
  final TimekeepingPeriod period;
  final TimekeepingAction action;
  @override
  ConsumerState<TimekeepingActionSheet> createState() =>
      _TimekeepingActionSheetState();
}

class _TimekeepingActionSheetState
    extends ConsumerState<TimekeepingActionSheet> {
  final _comment = TextEditingController();
  final _basis = TextEditingController();
  final _signer = TextEditingController();
  final _location = TextEditingController();
  TimekeepingDocument? _document;
  PlatformFile? _file;
  int? _uploadedId;
  DateTime _signedOn = DateTime.now();
  bool _saving = false;
  bool _canAct = true;
  late TimekeepingPeriod _period;
  String? _error;
  bool get _approval => widget.action.code == 'approve';
  String get _date =>
      '${_signedOn.year}-${_signedOn.month.toString().padLeft(2, '0')}-${_signedOn.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _period = widget.period;
  }

  Future<void> _reload() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(timekeepingDetailProvider(widget.period.id).notifier)
          .load();
      if (!mounted) return;
      final latest =
          ref.read(timekeepingDetailProvider(widget.period.id)).requireValue;
      setState(() {
        if (latest.revision != _period.revision) {
          _document = null;
          _uploadedId = null;
          _file = null;
        }
        _period = latest;
        _canAct = latest.actions.any(
          (action) => action.code == widget.action.code && action.enabled,
        );
        _error =
            _canAct
                ? null
                : 'Статус или права изменились. Закройте окно и проверьте табель.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Не удалось загрузить свежую версию табеля. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    _basis.dispose();
    _signer.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 20 * 1024 * 1024) {
        throw const FormatException(
          'Размер подписанного файла не должен превышать 20 МБ.',
        );
      }
      setState(() {
        _file = file;
        _uploadedId = null;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  error is FormatException
                      ? error.message.toString()
                      : 'Не удалось выбрать файл.',
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'comment': _comment.text.trim(),
        'basis_reference': _basis.text.trim(),
      };
      if (widget.action.code == 'reopen' && _basis.text.trim().isEmpty) {
        throw const FormatException(
          'Укажите основание возврата табеля в работу.',
        );
      }
      final notifier = ref.read(
        timekeepingDetailProvider(widget.period.id).notifier,
      );
      if (_approval) {
        if (_document == null ||
            _file == null ||
            _signer.text.trim().isEmpty ||
            _location.text.trim().isEmpty) {
          throw const FormatException(
            'Выберите документ и подписанный скан, укажите подписанта и место хранения оригинала.',
          );
        }
        if (_uploadedId == null) {
          final subtype = switch (_file!.extension?.toLowerCase()) {
            'pdf' => 'pdf',
            'png' => 'png',
            _ => 'jpeg',
          };
          final mime = DioMediaType(
            subtype == 'pdf' ? 'application' : 'image',
            subtype,
          );
          final file =
              _file!.path != null
                  ? await MultipartFile.fromFile(
                    _file!.path!,
                    filename: _file!.name,
                    contentType: mime,
                  )
                  : _file!.bytes != null
                  ? MultipartFile.fromBytes(
                    _file!.bytes!,
                    filename: _file!.name,
                    contentType: mime,
                  )
                  : throw const FormatException(
                    'Файл недоступен. Выберите его повторно.',
                  );
          _uploadedId = await notifier.upload(_document!.id, file);
        }
        data.addAll({
          'document_id': _document!.id,
          'document_revision': _document!.revision,
          'signed_file_id': _uploadedId,
          'signer_name': _signer.text.trim(),
          'signed_at': _date,
          'signed_on': _date,
          'paper_original_location': _location.text.trim(),
        });
      }
      final id = await notifier.action(widget.action.code, data);
      if (mounted) {
        Navigator.of(context).pop(id == widget.period.id ? null : id);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  error is ApiException
                      ? error.message
                      : error is FormatException
                      ? error.message.toString()
                      : 'Не удалось изменить статус табеля. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents =
        _period.documents
            .where((doc) => doc.revision == _period.revision)
            .toList();
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.action.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_error != null)
                TextButton(
                  onPressed: _saving ? null : _reload,
                  child: const Text('Загрузить новую версию'),
                ),
              AbsorbPointer(
                absorbing: _saving,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_approval) ...[
                      if (documents.isEmpty)
                        const Text(
                          'Сначала экспортируйте документ текущей версии, подпишите его и обновите табель.',
                        ),
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          'approval-document-${_period.id}-${_period.revision}',
                        ),
                        initialValue: _document?.id,
                        decoration: const InputDecoration(
                          labelText: 'Документ текущей версии',
                        ),
                        isExpanded: true,
                        items:
                            documents
                                .map(
                                  (doc) => DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(
                                      doc.filename,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (id) => setState(() {
                              _document = documents.firstWhere(
                                (doc) => doc.id == id,
                              );
                              _uploadedId = null;
                            }),
                      ),
                      TextField(
                        controller: _signer,
                        maxLength: 255,
                        decoration: const InputDecoration(
                          labelText: 'Подписант',
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Дата подписания'),
                        subtitle: Text(_date),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _signedOn,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null && mounted) {
                            setState(() => _signedOn = date);
                          }
                        },
                      ),
                      TextField(
                        controller: _location,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Где хранится бумажный оригинал',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_file?.name ?? 'Выбрать подписанный скан'),
                      ),
                    ],
                    TextField(
                      controller: _basis,
                      maxLength: 255,
                      decoration: InputDecoration(
                        labelText:
                            widget.action.code == 'reopen'
                                ? 'Основание возврата в работу'
                                : 'Основание (необязательно)',
                      ),
                    ),
                    TextField(
                      controller: _comment,
                      maxLength: 2000,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    _saving || !_canAct || (_approval && documents.isEmpty)
                        ? null
                        : _save,
                child: Text(_saving ? 'Сохранение…' : 'Подтвердить'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
