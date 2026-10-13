import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/bim_models.dart';
import '../data/bim_repository.dart';
import '../domain/bim_provider.dart';
import '../offline/bim_offline_models.dart';
import '../offline/bim_offline_provider.dart';
import 'bim_viewer_screen.dart';

String _operationKey() =>
    base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)));

class BimIssuesScreen extends ConsumerStatefulWidget {
  const BimIssuesScreen({super.key, required this.projectId, this.versionId});
  final int projectId;
  final int? versionId;
  @override
  ConsumerState<BimIssuesScreen> createState() => _BimIssuesScreenState();
}

class _BimIssuesScreenState extends ConsumerState<BimIssuesScreen> {
  BimPage<BimIssue>? _page;
  bool _loading = true;
  String? _error;
  String? _status;
  int _request = 0;
  bool _denied = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    final current = _page;
    setState(() {
      _loading = true;
      _error = null;
      _denied = false;
    });
    try {
      final page = await ref
          .read(bimRepositoryProvider)
          .issues(
            widget.projectId,
            page: more ? (current?.page ?? 0) + 1 : 1,
            status: _status,
            versionId: widget.versionId,
          );
      if (mounted && request == _request) {
        setState(
          () => _page = more && current != null ? current.append(page) : page,
        );
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = UserMessage.fromError(error);
          _denied = error is ApiException && error.statusCode == 403;
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Замечания по моделям'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          selected != widget.projectId
              ? const AppPermissionState(
                title: 'Объект изменился',
                description: 'Откройте замечания выбранного объекта заново.',
              )
              : _denied
              ? const AppPermissionState(
                title: 'Замечания недоступны',
                description: 'У вас нет прав на просмотр замечаний.',
              )
              : _loading && _page == null
              ? const AppLoadingState(message: 'Загружаем замечания')
              : _error != null && _page == null
              ? AppErrorState(
                title: 'Не удалось загрузить замечания',
                description: _error!,
                onRetry: _load,
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: (_page?.items.length ?? 0) + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey('issue-status-$_status'),
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Статус',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Все замечания'),
                              ),
                              DropdownMenuItem(
                                value: 'open',
                                child: Text('Открыты'),
                              ),
                              DropdownMenuItem(
                                value: 'in_progress',
                                child: Text('В работе'),
                              ),
                              DropdownMenuItem(
                                value: 'resolved',
                                child: Text('Устранены'),
                              ),
                              DropdownMenuItem(
                                value: 'verified',
                                child: Text('Подтверждены'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _status = value;
                                _page = null;
                              });
                              _load();
                            },
                          ),
                          if (_loading) const LinearProgressIndicator(),
                          if (_error != null)
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (_page?.items.isEmpty ?? true)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Text(
                                    _status == null
                                        ? 'Замечаний пока нет. Создайте замечание из просмотра модели.'
                                        : 'Нет замечаний по выбранным условиям.',
                                  ),
                                  if (_status != null)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _status = null;
                                          _page = null;
                                        });
                                        _load();
                                      },
                                      child: const Text('Сбросить фильтры'),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }
                    if (index > (_page?.items.length ?? 0)) {
                      return _page != null && _page!.page < _page!.lastPage
                          ? OutlinedButton(
                            onPressed:
                                _loading ? null : () => _load(more: true),
                            child: const Text('Показать ещё'),
                          )
                          : const SizedBox.shrink();
                    }
                    final issue = _page!.items[index - 1];
                    return Card(
                      child: ListTile(
                        title: Text(issue.title),
                        subtitle: Text(
                          '${issue.statusLabel}${issue.blocking ? ' · Блокирующее' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap:
                            () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) =>
                                            BimIssueDetailScreen(id: issue.id),
                                  ),
                                )
                                .then((_) {
                                  if (mounted) _load();
                                }),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

class BimIssueEditorScreen extends ConsumerStatefulWidget {
  const BimIssueEditorScreen({
    super.key,
    required this.projectId,
    required this.versionId,
    required this.contextPayload,
    this.snapshot,
    this.snapshotUnavailable = false,
    this.offline = false,
    this.draft,
  });
  final int projectId;
  final int versionId;
  final BimJson contextPayload;
  final Uint8List? snapshot;
  final bool snapshotUnavailable;
  final bool offline;
  final BimIssueDraft? draft;
  @override
  ConsumerState<BimIssueEditorScreen> createState() =>
      _BimIssueEditorScreenState();
}

class _BimIssueEditorScreenState extends ConsumerState<BimIssueEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _photos = <XFile>[];
  BimJson? _assignee;
  DateTime? _dueDate;
  String _severity = 'minor';
  String? _error;
  bool _saving = false;
  bool _createAttempted = false;
  bool get _online => ref.read(bimOnlineProvider).valueOrNull ?? false;
  bool get _draftOnly => _saveAsDraft || (!_online && !_createAttempted);
  BimIssueDraft? _submittedDraft;
  late bool _saveAsDraft;
  @override
  void initState() {
    super.initState();
    final payload = widget.draft?.payload ?? widget.contextPayload;
    _title = TextEditingController(text: payload['title'] as String?);
    _description = TextEditingController(
      text: payload['description'] as String?,
    );
    _severity = '${payload['severity'] ?? 'minor'}';
    _dueDate = DateTime.tryParse('${payload['due_date'] ?? ''}');
    _saveAsDraft = widget.offline || widget.draft != null;
    _submittedDraft = widget.draft;
    _createAttempted = widget.draft?.attempted ?? false;
    if (payload['assignee_id'] != null) {
      _assignee = {
        'id': payload['assignee_id'],
        'name': 'Исполнитель ${payload['assignee_id']}',
      };
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bimOnlineProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.draft == null ? 'Новое замечание' : 'Изменить черновик',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Версия ${widget.versionId}${widget.contextPayload['bim_element_id'] == null ? '' : ' · Элемент ${widget.contextPayload['bim_element_id']}'}',
            ),
            if (widget.snapshotUnavailable) ...[
              const SizedBox(height: 12),
              const Text(
                'Не удалось сделать снимок модели. Замечание сохранится с привязкой к выбранным элементам и текущему виду. Можно прикрепить фотографию.',
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('bim-issue-title'),
              controller: _title,
              enabled: !_createAttempted && !_saving,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Название замечания',
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Укажите название'
                          : null,
            ),
            TextFormField(
              controller: _description,
              enabled: !_createAttempted && !_saving,
              minLines: 3,
              maxLines: 8,
              maxLength: 5000,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Важность'),
              items: const [
                DropdownMenuItem(value: 'minor', child: Text('Обычная')),
                DropdownMenuItem(value: 'major', child: Text('Высокая')),
                DropdownMenuItem(value: 'critical', child: Text('Критическая')),
              ],
              onChanged:
                  _createAttempted || _saving
                      ? null
                      : (value) => setState(() => _severity = value!),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Исполнитель'),
              subtitle: Text('${_assignee?['name'] ?? 'Не назначен'}'),
              trailing: const Icon(Icons.person_add_alt),
              onTap:
                  widget.offline || !_online || _createAttempted || _saving
                      ? null
                      : _pickAssignee,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Срок устранения'),
              subtitle: Text(
                _dueDate == null
                    ? 'Не указан'
                    : '${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}',
              ),
              trailing:
                  _dueDate == null
                      ? const Icon(Icons.calendar_today)
                      : IconButton(
                        tooltip: 'Убрать срок',
                        icon: const Icon(Icons.close),
                        onPressed:
                            _createAttempted || _saving
                                ? null
                                : () => setState(() => _dueDate = null),
                      ),
              onTap:
                  _createAttempted || _saving
                      ? null
                      : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (mounted && date != null) {
                          setState(() => _dueDate = date);
                        }
                      },
            ),
            if (widget.snapshot != null) ...[
              const Text('Снимок модели и положение камеры сохранены'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Image.memory(
                  widget.snapshot!,
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ],
            if (widget.draft != null && widget.draft!.attachments.isNotEmpty)
              Text('Сохранённых вложений: ${widget.draft!.attachments.length}'),
            Wrap(
              spacing: 8,
              children: [
                for (final photo in _photos)
                  SizedBox(
                    width: 100,
                    child: Column(
                      children: [
                        Image.file(
                          File(photo.path),
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                        IconButton(
                          tooltip: 'Убрать фото',
                          onPressed:
                              _saving || _createAttempted
                                  ? null
                                  : () => setState(() => _photos.remove(photo)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                if (widget.draft == null)
                  OutlinedButton.icon(
                    onPressed:
                        _saving || _createAttempted
                            ? null
                            : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Сделать фото'),
                  ),
                if (widget.draft == null)
                  OutlinedButton.icon(
                    onPressed:
                        _saving || _createAttempted
                            ? null
                            : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Из галереи'),
                  ),
              ],
            ),
            if (!widget.offline && widget.draft == null && !_createAttempted)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Сохранить для отправки позже'),
                value: _draftOnly,
                onChanged:
                    _saving || !_online
                        ? null
                        : (value) => setState(() => _saveAsDraft = value),
              ),
            if ((widget.offline || !_online) && !_createAttempted)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Замечание сохранится на устройстве. Перед отправкой можно изменить текст.',
                ),
              ),
            if (_submittedDraft?.serverId != null)
              Text(
                'Замечание №${_submittedDraft!.serverId} создано. Оставшиеся вложения сохранены на устройстве.',
              ),
            if (_submittedDraft != null && _createAttempted)
              const Text(
                'Отправка сохранена. Можно закрыть экран и продолжить во вкладке «На устройстве».',
              ),
            if (!_online && _createAttempted)
              const Text('Для завершения отправки подключитесь к интернету.'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed:
                  _saving ||
                          widget.draft?.editable == false ||
                          (_createAttempted && !_online)
                      ? null
                      : _save,
              child: Text(
                _saving
                    ? 'Сохраняем'
                    : _submittedDraft?.serverId != null
                    ? 'Отправить вложения'
                    : _draftOnly
                    ? 'Сохранить черновик'
                    : 'Создать замечание',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAssignee() async {
    final selected = await showDialog<BimJson>(
      context: context,
      builder: (_) => BimAssigneeDialog(projectId: widget.projectId),
    );
    if (mounted && selected != null) setState(() => _assignee = selected);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (photo != null && await photo.length() > 10 * 1024 * 1024) {
        if (mounted) {
          setState(() => _error = 'Фото должно быть не больше 10 МБ.');
        }
        return;
      }
      if (mounted && photo != null) {
        setState(() {
          _photos.add(photo);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    }
  }

  BimJson _payload() => {
    ...widget.contextPayload,
    'project_id': widget.projectId,
    'version_id': widget.versionId,
    'title': _title.text.trim(),
    'description': _description.text.trim(),
    'severity': _severity,
    'assignee_id': _assignee == null ? null : bimInt(_assignee!['id']),
    'due_date': _dueDate?.toIso8601String().split('T').first,
  };
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.snapshot != null && widget.snapshot!.length > 10 * 1024 * 1024) {
      setState(() => _error = 'Снимок модели должен быть не больше 10 МБ.');
      return;
    }
    if (ref.read(projectsProvider).selectedProject?.serverId !=
        widget.projectId) {
      setState(() => _error = 'Объект изменился. Откройте замечание заново.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = await ref.read(bimOfflineServiceProvider.future);
      if (_submittedDraft == null) {
        _submittedDraft = await service.createDraft(
          versionId: widget.versionId,
          payload: _payload(),
          snapshot: widget.snapshot,
          attachments: [
            for (final photo in _photos)
              BimDraftAttachmentInput(
                path: photo.path,
                filename: photo.name,
                mime: photo.mimeType ?? 'image/jpeg',
                kind: 'photo',
              ),
          ],
        );
      } else if (!_createAttempted) {
        await service.updateDraft(
          _submittedDraft!.localId,
          payload: _payload(),
        );
      }
      if (!_draftOnly) {
        _createAttempted = true;
        await service.syncDraft(_submittedDraft!.localId);
        _submittedDraft = (await service.drafts()).firstWhere(
          (draft) => draft.localId == _submittedDraft!.localId,
        );
        if (_submittedDraft!.status != 'completed') {
          if (mounted) {
            setState(
              () =>
                  _error =
                      _submittedDraft!.lastError ??
                      'Отправка сохранена на устройстве. Повторите её после проверки соединения.',
            );
          }
          return;
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  error is ApiException && error.statusCode == 409
                      ? 'Замечание изменилось на сервере. Откройте его заново перед отправкой вложений.'
                      : UserMessage.fromError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class BimDraftReviewScreen extends ConsumerStatefulWidget {
  const BimDraftReviewScreen({
    super.key,
    required this.projectId,
    required this.draft,
  });
  final int projectId;
  final BimIssueDraft draft;
  @override
  ConsumerState<BimDraftReviewScreen> createState() =>
      _BimDraftReviewScreenState();
}

class _BimDraftReviewScreenState extends ConsumerState<BimDraftReviewScreen> {
  late BimIssueDraft _draft = widget.draft;
  bool _busy = false;
  String? _error;
  final Map<String, Future<Uint8List>> _attachments = {};

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (ref.read(projectsProvider).selectedProject?.serverId !=
          widget.projectId) {
        throw const ApiException(
          'Объект изменился. Откройте замечание заново.',
        );
      }
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() => _run(() async {
    final service = await ref.read(bimOfflineServiceProvider.future);
    await service.syncDraft(_draft.localId);
    final updated = (await service.drafts()).firstWhere(
      (item) => item.localId == _draft.localId,
    );
    if (mounted) setState(() => _draft = updated);
  });

  Future<void> _clone() => _run(() async {
    final service = await ref.read(bimOfflineServiceProvider.future);
    final editable = await service.cloneRejectedDraft(_draft.localId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => BimIssueEditorScreen(
              projectId: widget.projectId,
              versionId: editable.versionId,
              contextPayload: editable.payload,
              draft: editable,
              offline: true,
            ),
      ),
    );
    if (mounted) Navigator.pop(context);
  });

  Future<void> _remove() => _run(() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              _draft.serverId == null
                  ? 'Удалить неотправленное замечание?'
                  : 'Удалить очередь вложений?',
            ),
            content: Text(
              _draft.serverId == null
                  ? 'Текст и сохранённые вложения будут удалены с устройства.'
                  : 'Замечание №${_draft.serverId} уже создано на сервере и останется там. Неотправленные вложения будут удалены с устройства.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
    if (accepted != true) return;
    final service = await ref.read(bimOfflineServiceProvider.future);
    await service.removeDraft(_draft.localId);
    if (mounted) Navigator.pop(context);
  });

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(bimOnlineProvider).valueOrNull ?? false;
    final selected = ref.watch(
      projectsProvider.select((state) => state.selectedProject?.serverId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Сохранённое замечание')),
      body:
          selected != widget.projectId
              ? const AppPermissionState(
                title: 'Объект изменился',
                description: 'Откройте замечания выбранного объекта заново.',
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${_draft.payload['title'] ?? 'Замечание'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${_draft.payload['description'] ?? ''}'),
                  Text(
                    'Важность: ${_severityLabel('${_draft.payload['severity'] ?? 'minor'}')}',
                  ),
                  if (_draft.payload['due_date'] != null)
                    Text('Срок: ${_draft.payload['due_date']}'),
                  if (_draft.lastError != null)
                    Text(
                      _draft.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_draft.status == 'completed')
                    const Text('Замечание и все вложения отправлены.'),
                  if (_draft.rejectedBeforeCreate)
                    const Text(
                      'Сервер отклонил создание замечания. Исправьте черновик или удалите его.',
                    )
                  else if (_draft.status != 'completed')
                    const Text(
                      'Результат отправки требует проверки. Повторная отправка продолжит сохранённую операцию без создания копии. Содержание и вложения остаются на устройстве.',
                    ),
                  for (final attachment in _draft.attachments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: FutureBuilder<Uint8List>(
                        future: _attachments.putIfAbsent(
                          attachment['key'] as String,
                          () async {
                            final service = await ref.read(
                              bimOfflineServiceProvider.future,
                            );
                            return service.draftAttachmentBytes(
                              _draft.localId,
                              attachment['key'] as String,
                            );
                          },
                        ),
                        builder:
                            (context, snapshot) =>
                                snapshot.hasData
                                    ? Image.memory(
                                      snapshot.requireData,
                                      height: 180,
                                      fit: BoxFit.contain,
                                    )
                                    : snapshot.hasError
                                    ? const Text(
                                      'Вложение недоступно. Повторите открытие замечания.',
                                    )
                                    : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                      ),
                    ),
                  if (_draft.serverId != null && online)
                    OutlinedButton(
                      onPressed:
                          _busy
                              ? null
                              : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => BimIssueDetailScreen(
                                        id: _draft.serverId!,
                                      ),
                                ),
                              ),
                      child: const Text('Открыть замечание на сервере'),
                    ),
                  if (_draft.status != 'completed')
                    FilledButton(
                      onPressed: _busy || !online ? null : _retry,
                      child: const Text('Повторить отправку'),
                    ),
                  if (_draft.rejectedBeforeCreate)
                    OutlinedButton(
                      onPressed: _busy ? null : _clone,
                      child: const Text('Исправить черновик'),
                    ),
                  if (_draft.removable)
                    TextButton(
                      onPressed: _busy ? null : _remove,
                      child: const Text('Удалить с устройства'),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ),
    );
  }
}

String _severityLabel(String value) => switch (value) {
  'critical' => 'Критическая',
  'major' => 'Высокая',
  'minor' => 'Обычная',
  _ => 'Не указана',
};

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

class BimIssueDetailScreen extends ConsumerStatefulWidget {
  const BimIssueDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<BimIssueDetailScreen> createState() =>
      _BimIssueDetailScreenState();
}

class _BimIssueDetailScreenState extends ConsumerState<BimIssueDetailScreen> {
  bool _busy = false;
  String? _error;
  XFile? _pendingPhoto;
  BimIssue? _photoIssue;
  String? _photoOperationKey;
  @override
  Widget build(BuildContext context) {
    final online = ref.watch(bimOnlineProvider).valueOrNull ?? false;
    final result = ref.watch(bimIssueProvider(widget.id));
    final selected = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Замечание'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed:
                _busy
                    ? null
                    : () => ref.invalidate(bimIssueProvider(widget.id)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: result.when(
        loading: () => const AppLoadingState(message: 'Загружаем замечание'),
        error:
            (error, _) =>
                error is ApiException && error.statusCode == 403
                    ? const AppPermissionState(
                      title: 'Замечание недоступно',
                      description: 'У вас нет прав на просмотр.',
                    )
                    : AppErrorState(
                      title: 'Не удалось загрузить замечание',
                      description: UserMessage.fromError(error),
                      onRetry:
                          () => ref.invalidate(bimIssueProvider(widget.id)),
                    ),
        data:
            (issue) =>
                selected != issue.projectId
                    ? const AppPermissionState(
                      title: 'Объект изменился',
                      description:
                          'Откройте замечание выбранного объекта заново.',
                    )
                    : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          issue.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Chip(label: Text(issue.statusLabel)),
                        if (issue.blocking)
                          const Text('Замечание блокирует выпуск документации'),
                        if (issue.blocking &&
                            issue.blockingReason?.isNotEmpty == true)
                          Text('Причина блокировки: ${issue.blockingReason}'),
                        Text(issue.description),
                        Text('Важность: ${_severityLabel(issue.severity)}'),
                        if (issue.dueDate != null)
                          Text('Срок устранения: ${_date(issue.dueDate!)}'),
                        if (issue.authorName?.isNotEmpty == true)
                          Text('Автор: ${issue.authorName}'),
                        if (issue.assigneeId != null)
                          Text(
                            'Исполнитель: ${issue.assigneeName ?? 'Имя недоступно'}',
                          ),
                        if (issue.history.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'История замечания',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final entry in issue.history)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                BimIssue(
                                  id: issue.id,
                                  projectId: issue.projectId,
                                  revision: issue.revision,
                                  title: issue.title,
                                  status: entry.status,
                                ).statusLabel,
                              ),
                              subtitle: Text(
                                [
                                  if (entry.author != null) entry.author!,
                                  if (entry.changedAt != null)
                                    _date(entry.changedAt!.toLocal()),
                                  if (entry.comment?.isNotEmpty == true)
                                    entry.comment!,
                                ].join('\n'),
                              ),
                            ),
                        ],
                        if (issue.snapshotUrl != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Image.network(
                              issue.snapshotUrl.toString(),
                              height: 220,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, _, _) => const Text(
                                    'Снимок недоступен. Обновите замечание.',
                                  ),
                            ),
                          ),
                        for (final photo in issue.photos)
                          if (photo['url'] is String)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Image.network(
                                photo['url'],
                                height: 200,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (_, _, _) => const Text('Фото недоступно.'),
                              ),
                            ),
                        if (bimMap(
                              issue.context['annotations'],
                            )['page_number'] ==
                            null)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _openContext(issue),
                            icon: const Icon(Icons.view_in_ar),
                            label: const Text('Открыть место в модели'),
                          ),
                        const SizedBox(height: 12),
                        for (final action in issue.actions.where(
                          (action) =>
                              action.key != 'snapshot' ||
                              bimMap(
                                    issue.context['annotations'],
                                  )['page_number'] ==
                                  null,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FilledButton.tonal(
                              onPressed:
                                  _busy || !online || !action.enabled
                                      ? null
                                      : () => _perform(issue, action),
                              child: Text(action.label),
                            ),
                          ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
      ),
    );
  }

  Future<void> _perform(BimIssue issue, BimAction action) async {
    if (action.key == 'snapshot') {
      await _openContext(issue, updateSnapshot: true);
      return;
    }
    if (action.key == 'photos') {
      await _attachPhoto(issue);
      return;
    }
    final payload = <String, dynamic>{};
    if (action.key == 'assign') {
      final assignee = await showDialog<BimJson>(
        context: context,
        builder: (_) => BimAssigneeDialog(projectId: issue.projectId),
      );
      if (assignee == null) return;
      payload['assignee_id'] = bimInt(assignee['id']);
    }
    final comment = TextEditingController();
    var accepted = true;
    var active = !issue.blocking;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: Text(action.label),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (action.key == 'verify')
                        SwitchListTile(
                          title: const Text('Подтвердить устранение'),
                          value: accepted,
                          onChanged: (value) => update(() => accepted = value),
                        ),
                      if (action.key == 'blocking_flag' ||
                          action.key == 'blocking')
                        SwitchListTile(
                          title: const Text('Блокировать выпуск'),
                          value: active,
                          onChanged: (value) => update(() => active = value),
                        ),
                      TextField(
                        controller: comment,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Выполнить'),
                    ),
                  ],
                ),
          ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (confirmed != true) return;
    if (action.key == 'verify') payload['accepted'] = accepted;
    final blocking = action.key == 'blocking_flag' || action.key == 'blocking';
    if (blocking) {
      payload['active'] = active;
      payload['reason'] = text;
    } else if (text.isNotEmpty) {
      payload['comment'] = text;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (ref.read(projectsProvider).selectedProject?.serverId !=
          issue.projectId) {
        throw const ApiException('Объект изменился.');
      }
      await ref
          .read(bimRepositoryProvider)
          .issueAction(
            issue,
            blocking ? 'blocking' : action.key,
            payload,
            idempotencyKey: _operationKey(),
          );
      ref.invalidate(bimIssueProvider(widget.id));
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  error is ApiException && error.statusCode == 409
                      ? 'Замечание изменилось. Обновите данные и проверьте действие ещё раз.'
                      : UserMessage.fromError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openContext(
    BimIssue issue, {
    bool updateSnapshot = false,
  }) async {
    setState(() => _busy = true);
    try {
      final context = await ref
          .read(bimRepositoryProvider)
          .issueContext(issue.id);
      final viewContext = BimViewContext.fromJson(context);
      if (viewContext.versionIds.isEmpty) {
        throw const ApiException(
          'У замечания нет сохранённого контекста модели.',
        );
      }
      if (!mounted) return;
      await Navigator.of(this.context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => BimViewerScreen(
                projectId: issue.projectId,
                title: issue.title,
                versionIds: viewContext.versionIds,
                transforms: viewContext.transforms,
                modelSetRevisionId: viewContext.modelSetRevisionId,
                initialViewState: viewContext.viewState,
                snapshotTargetIssue: updateSnapshot ? issue : null,
              ),
        ),
      );
      ref.invalidate(bimIssueProvider(widget.id));
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachPhoto(BimIssue issue) async {
    if (_pendingPhoto == null) {
      try {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2000,
        );
        if (photo == null || !mounted) return;
        if (await photo.length() > 10 * 1024 * 1024) {
          if (mounted) {
            setState(() => _error = 'Фото должно быть не больше 10 МБ.');
          }
          return;
        }
        _pendingPhoto = photo;
        _photoIssue = issue;
        _photoOperationKey = _operationKey();
      } catch (error) {
        if (mounted) {
          setState(() => _error = UserMessage.fromError(error));
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (ref.read(projectsProvider).selectedProject?.serverId !=
          issue.projectId) {
        throw const ApiException('Объект изменился.');
      }
      await ref
          .read(bimRepositoryProvider)
          .attachPhoto(
            _photoIssue!,
            _pendingPhoto!.path,
            idempotencyKey: _photoOperationKey,
          );
      _pendingPhoto = null;
      _photoIssue = null;
      _photoOperationKey = null;
      ref.invalidate(bimIssueProvider(widget.id));
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        _pendingPhoto = null;
        _photoIssue = null;
        _photoOperationKey = null;
      }
      if (mounted) {
        setState(
          () =>
              _error =
                  error.statusCode == 409
                      ? 'Замечание изменилось. Обновите данные перед добавлением фото.'
                      : UserMessage.fromError(error),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class BimAssigneeDialog extends ConsumerStatefulWidget {
  const BimAssigneeDialog({super.key, required this.projectId});
  final int projectId;
  @override
  ConsumerState<BimAssigneeDialog> createState() => _BimAssigneeDialogState();
}

class _BimAssigneeDialogState extends ConsumerState<BimAssigneeDialog> {
  final _search = TextEditingController();
  BimPage<BimJson>? _page;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    final current = _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(bimRepositoryProvider)
          .assignees(
            widget.projectId,
            page: more ? (current?.page ?? 0) + 1 : 1,
            query: _search.text,
          );
      if (mounted && generation == _generation) {
        setState(
          () => _page = more && current != null ? current.append(page) : page,
        );
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = UserMessage.fromError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Исполнитель'),
    content: SizedBox(
      width: 380,
      height: 380,
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Найти по имени',
              suffixIcon: IconButton(
                tooltip: 'Найти',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          Expanded(
            child: ListView.builder(
              itemCount: (_page?.items.length ?? 0) + 1,
              itemBuilder: (context, index) {
                if (index == (_page?.items.length ?? 0)) {
                  return _page != null && _page!.page < _page!.lastPage
                      ? TextButton(
                        onPressed: _loading ? null : () => _load(more: true),
                        child: const Text('Показать ещё'),
                      )
                      : _page?.items.isEmpty == true
                      ? const Text('Исполнителей не найдено')
                      : const SizedBox.shrink();
                }
                final person = _page!.items[index];
                return ListTile(
                  title: Text('${person['name']}'),
                  onTap: () => Navigator.pop(context, person),
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
    ],
  );
}
