import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/bim_models.dart';
import '../data/bim_repository.dart';
import '../domain/bim_provider.dart';
import '../domain/bim_issue_capture.dart';
import '../offline/bim_offline_provider.dart';
import '../realtime/bim_realtime_section.dart';
import '../viewer/bim_viewer_surface.dart';
import 'bim_issue_screens.dart';
import 'bim_offline_panel.dart';

class BimViewerScreen extends ConsumerStatefulWidget {
  const BimViewerScreen({
    super.key,
    required this.projectId,
    required this.title,
    required this.versionIds,
    this.transforms = const {},
    this.modelSetRevisionId,
    this.modelSetId,
    this.preferOffline = false,
    this.canCreateIssue = false,
    this.canPrepare = false,
    this.initialViewState,
    this.snapshotTargetIssue,
  });
  final int projectId;
  final String title;
  final List<int> versionIds;
  final Map<int, BimTransform> transforms;
  final int? modelSetRevisionId;
  final int? modelSetId;
  final bool preferOffline;
  final bool canCreateIssue;
  final bool canPrepare;
  final BimJson? initialViewState;
  final BimIssue? snapshotTargetIssue;
  @override
  ConsumerState<BimViewerScreen> createState() => _BimViewerScreenState();
}

class _BimViewerScreenState extends ConsumerState<BimViewerScreen> {
  final _controller = BimViewerController();
  StreamSubscription<Map<String, dynamic>>? _viewerEvents;
  late String _snapshotOperationKey;
  BimIssue? _snapshotTarget;
  bool _snapshotConflict = false;
  BimViewerDocument? _document;
  BimViewerSelection? _selection;
  BimJson? _properties;
  bool _loading = true;
  bool _offline = false;
  bool get _networkOffline =>
      !(ref.read(bimOnlineProvider).valueOrNull ?? false);
  bool _propertiesLoading = false;
  bool _busy = false;
  bool _canCreateIssue = false;
  bool _permissionDenied = false;
  String? _error;
  List<BimPreparedViewer> _pending = [];
  int _propertyRequest = 0;
  @override
  void initState() {
    super.initState();
    _snapshotTarget = widget.snapshotTargetIssue;
    _snapshotOperationKey =
        'snapshot-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    _viewerEvents = _controller.events.listen((event) {
      if (event['type'] == 'ready' &&
          widget.initialViewState?.isNotEmpty == true) {
        _run(() => _controller.restoreIssueView(widget.initialViewState!));
      }
    });
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _viewerEvents?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final models = <BimViewerModel>[];
      final pending = <BimPreparedViewer>[];
      var offline = widget.preferOffline;
      var canCreateIssue = false;
      for (final id in widget.versionIds) {
        if (!mounted) return;
        BimPreparedViewer? prepared;
        if (!widget.preferOffline) {
          try {
            prepared = await ref.read(bimRepositoryProvider).viewer(id);
          } on ApiException catch (error) {
            if (error.statusCode != null) rethrow;
            offline = true;
          }
        }
        if (prepared != null) {
          canCreateIssue =
              canCreateIssue ||
              bimMaps(prepared.raw['available_actions']).any(
                (action) =>
                    action['key'] == 'create_issue' &&
                    action['enabled'] == true,
              );
          if (prepared.ready) {
            models.add(
              BimViewerModel(
                versionId: id,
                geometryUrl: prepared.url!,
                geometryLength:
                    prepared.sizeBytes > 0 ? prepared.sizeBytes : null,
                transform: widget.transforms[id]?.toJson(),
              ),
            );
          } else {
            pending.add(prepared);
          }
        } else {
          final service = await ref.read(bimOfflineServiceProvider.future);
          final local = await service.cachedVersion(id);
          if (local == null) {
            throw const ApiException(
              'Эта версия не сохранена на устройстве. Подключитесь к интернету.',
            );
          }
          if (bimInt(local.manifest['project_id']) != widget.projectId) {
            throw const ApiException(
              'Сохранённая версия относится к другому объекту.',
            );
          }
          canCreateIssue =
              canCreateIssue ||
              bimMaps(local.manifest['available_actions']).any(
                (action) =>
                    action['key'] == 'create_issue' &&
                    action['enabled'] == true,
              );
          models.add(
            BimViewerModel.local(
              versionId: id,
              source: BimViewerBinarySource(
                length: local.length,
                mime: local.mime,
                read: (start, end) => local.geometry(start: start, end: end),
              ),
              transform: widget.transforms[id]?.toJson(),
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _offline = offline;
        _canCreateIssue = canCreateIssue && widget.canCreateIssue;
        _pending = pending;
        _document =
            pending.isEmpty
                ? BimViewerDocument(
                  models: models,
                  modelSetRevisionId: widget.modelSetRevisionId,
                )
                : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = UserMessage.fromError(error);
        _permissionDenied = error is ApiException && error.statusCode == 403;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bimOnlineProvider);
    final selectedProject = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Обновить модель',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Замечания',
            onPressed:
                _offline || _networkOffline
                    ? null
                    : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => BimIssuesScreen(
                              projectId: widget.projectId,
                              versionId:
                                  widget.versionIds.length == 1
                                      ? widget.versionIds.single
                                      : null,
                            ),
                      ),
                    ),
            icon: const Icon(Icons.comment_outlined),
          ),
        ],
      ),
      body:
          selectedProject != widget.projectId
              ? const AppPermissionState(
                title: 'Объект изменился',
                description: 'Откройте модель для выбранного объекта заново.',
              )
              : _body(),
    );
  }

  Widget _body() {
    if (_loading) return const AppLoadingState(message: 'Открываем модель');
    if (_permissionDenied) {
      return const AppPermissionState(
        title: 'Модель недоступна',
        description: 'У вас нет прав на просмотр этой модели.',
      );
    }
    if (_document == null && _error != null) {
      return AppErrorState(
        title: 'Не удалось открыть модель',
        description: _error!,
        onRetry: _load,
      );
    }
    if (_document == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final pending in _pending) ...[
            Text(
              'Версия ${pending.versionId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(switch (pending.status) {
              'queued' => 'Модель ожидает подготовки.',
              'processing' => 'Модель подготавливается на сервере.',
              'unsupported' => 'Формат этой модели не поддерживается.',
              'failed' => 'Не удалось подготовить модель.',
              _ => 'Модель ещё не подготовлена.',
            }),
            if (pending.status == 'processing' || pending.status == 'queued')
              LinearProgressIndicator(
                value: pending.progress > 0 ? pending.progress / 100 : null,
              ),
            if (pending.failure != null) Text(pending.failure!),
            if (widget.canPrepare && pending.status != 'unsupported')
              FilledButton(
                onPressed:
                    _busy || _networkOffline
                        ? null
                        : () => _run(() async {
                          await ref
                              .read(bimRepositoryProvider)
                              .prepare(pending.versionId);
                          await _load();
                        }),
                child: Text(
                  ['queued', 'processing'].contains(pending.status)
                      ? 'Повторить подготовку'
                      : 'Подготовить к просмотру',
                ),
              ),
            const SizedBox(height: 16),
          ],
          OutlinedButton(
            onPressed: _load,
            child: const Text('Проверить готовность'),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (_offline || _networkOffline)
          const Material(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text('Без интернета · Используется сохранённая версия'),
            ),
          ),
        if (_error != null)
          Material(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        if (_snapshotConflict)
          TextButton(
            onPressed:
                _busy || _networkOffline
                    ? null
                    : () => _run(() async {
                      _snapshotTarget = await ref
                          .read(bimRepositoryProvider)
                          .issue(widget.snapshotTargetIssue!.id);
                      _snapshotOperationKey =
                          'snapshot-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
                      if (mounted) {
                        setState(() {
                          _snapshotConflict = false;
                          _error = null;
                        });
                      }
                    }),
            child: const Text('Обновить замечание'),
          ),
        Expanded(
          child: BimViewerSurface(
            document: _document!,
            controller: _controller,
            onSelection: _select,
            onError: (error) {
              if (mounted) {
                setState(() => _error = UserMessage.fromError(error));
              }
            },
            onViewChanged: (_) {},
          ),
        ),
        if (_selection != null)
          ListTile(
            dense: true,
            title: Text(
              'Элемент ${_selection!.expressId} · Версия ${_selection!.versionId}',
            ),
            trailing:
                _propertiesLoading
                    ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : IconButton(
                      tooltip: 'Свойства элемента',
                      icon: const Icon(Icons.list_alt),
                      onPressed: _showProperties,
                    ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Показать всю модель',
                onPressed: () => _run(_controller.fit),
                icon: const Icon(Icons.fit_screen),
              ),
              IconButton(
                tooltip: 'Скрыть выбранный элемент',
                onPressed:
                    _selection == null
                        ? null
                        : () => _run(_controller.hideSelected),
                icon: const Icon(Icons.visibility_off_outlined),
              ),
              IconButton(
                tooltip: 'Оставить выбранный элемент',
                onPressed:
                    _selection == null
                        ? null
                        : () => _run(_controller.isolateSelected),
                icon: const Icon(Icons.filter_center_focus),
              ),
              IconButton(
                tooltip: 'Показать все элементы',
                onPressed: () => _run(_controller.showAll),
                icon: const Icon(Icons.visibility_outlined),
              ),
              IconButton(
                tooltip: 'Камера',
                onPressed: _camera,
                icon: const Icon(Icons.threed_rotation),
              ),
              IconButton(
                tooltip: 'Сечение',
                onPressed: _sections,
                icon: const Icon(Icons.cut),
              ),
              IconButton(
                tooltip: 'Сохранить на устройстве',
                onPressed:
                    _offline || _networkOffline || _busy ? null : _saveOffline,
                icon: const Icon(Icons.download_for_offline_outlined),
              ),
              if (_canCreateIssue)
                IconButton(
                  tooltip: 'Добавить замечание',
                  onPressed: _busy ? null : _createIssue,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              if (_snapshotTarget != null)
                IconButton(
                  tooltip: 'Обновить снимок замечания',
                  onPressed:
                      _busy || _offline || _networkOffline || _snapshotConflict
                          ? null
                          : _updateIssueSnapshot,
                  icon: const Icon(Icons.add_a_photo_outlined),
                ),
            ],
          ),
        ),
        BimRealtimeSection(
          projectId: widget.projectId,
          document: _document!,
          controller: _controller,
          offline: _offline || _networkOffline,
        ),
      ],
    );
  }

  Future<void> _select(BimViewerSelection? selection) async {
    final request = ++_propertyRequest;
    setState(() {
      _selection = selection;
      _properties = null;
      _propertiesLoading = selection != null;
    });
    if (selection == null) return;
    try {
      BimJson? properties;
      if (!_offline && !_networkOffline) {
        properties = await ref
            .read(bimRepositoryProvider)
            .element(selection.versionId, selection.expressId);
      } else {
        properties = await (await ref.read(
          bimOfflineServiceProvider.future,
        )).elementProperties(selection.versionId, selection.expressId);
      }
      if (mounted && request == _propertyRequest) {
        setState(() => _properties = properties);
      }
    } catch (error) {
      if (mounted && request == _propertyRequest) {
        setState(() => _error = UserMessage.fromError(error));
      }
    } finally {
      if (mounted && request == _propertyRequest) {
        setState(() => _propertiesLoading = false);
      }
    }
  }

  void _showProperties() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (context) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            builder:
                (context, scroll) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Свойства элемента',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_properties == null)
                      const Text(
                        'Свойства недоступны. Выберите элемент повторно.',
                      ),
                    ..._propertyWidgets(_properties ?? {}, ''),
                  ],
                ),
          ),
        ),
  );
  List<Widget> _propertyWidgets(BimJson json, String prefix) => [
    for (final entry in json.entries)
      if (entry.value is Map)
        ..._propertyWidgets(bimMap(entry.value), '$prefix${entry.key} · ')
      else
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('$prefix${entry.key}'),
          subtitle: SelectableText('${entry.value ?? '—'}'),
        ),
  ];
  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _camera() => showModalBottomSheet<void>(
    context: context,
    builder:
        (context) => SafeArea(
          child: Wrap(
            children: [
              for (final entry
                  in {
                    'iso': 'Изометрия',
                    'top': 'Сверху',
                    'front': 'Спереди',
                    'right': 'Справа',
                  }.entries)
                ListTile(
                  title: Text(entry.value),
                  onTap: () {
                    Navigator.pop(context);
                    _run(() => _controller.setCameraPreset(entry.key));
                  },
                ),
            ],
          ),
        ),
  );
  Future<void> _sections() async {
    var axis = 'x';
    final offset = TextEditingController(text: '0');
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, update) => AlertDialog(
                  title: const Text('Сечение модели'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: axis,
                        items: [
                          for (final value in ['x', 'y', 'z'])
                            DropdownMenuItem(
                              value: value,
                              child: Text('Ось ${value.toUpperCase()}'),
                            ),
                        ],
                        onChanged: (value) => update(() => axis = value!),
                      ),
                      TextField(
                        controller: offset,
                        decoration: const InputDecoration(
                          labelText: 'Положение плоскости',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'clear'),
                      child: const Text('Убрать сечения'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, 'apply'),
                      child: const Text('Применить'),
                    ),
                  ],
                ),
          ),
    );
    final number = double.tryParse(offset.text.replaceAll(',', '.'));
    offset.dispose();
    if (result == 'clear') await _run(_controller.clearSections);
    if (result == 'apply') {
      if (number == null || !number.isFinite) {
        if (mounted) {
          setState(() => _error = 'Введите корректное положение плоскости.');
        }
      } else {
        await _run(() => _controller.setSection(axis, number));
      }
    }
  }

  Future<void> _saveOffline() => _run(() async {
    final repository = ref.read(bimRepositoryProvider);
    var size = 0;
    for (final id in widget.versionIds) {
      final manifest = await repository.offlinePackage(id);
      size +=
          bimInt(bimMap(manifest['geometry'])['size']) +
          bimInt(bimMap(manifest['properties'])['size']);
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Сохранить модели на устройстве?'),
            content: Text(
              'Объём: ${bimBytes(size)}. Ход сохранения доступен во вкладке «На устройстве».',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final service = await ref.read(bimOfflineServiceProvider.future);
    Future<void> download() async {
      if (widget.modelSetId != null && widget.modelSetRevisionId != null) {
        await service.saveSet(
          projectId: widget.projectId,
          setId: widget.modelSetId!,
          modelSetRevisionId: widget.modelSetRevisionId!,
          title: widget.title,
          versionIds: widget.versionIds,
          transforms: widget.transforms,
        );
      } else {
        for (final id in widget.versionIds) {
          await service.saveVersion(
            id,
            title: widget.title,
            projectId: widget.projectId,
          );
        }
      }
    }

    unawaited(
      download().catchError((Object error) {
        if (mounted) setState(() => _error = UserMessage.fromError(error));
      }),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Сохранение началось'),
          action: SnackBarAction(
            label: 'Ход сохранения',
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => BimOfflineScreen(projectId: widget.projectId),
                  ),
                ),
          ),
        ),
      );
    }
  });
  Future<void> _createIssue() => _run(() async {
    final frame = await captureBimIssueContext(_controller);
    final view = frame.viewState;
    final snapshot = frame.snapshot;
    final selections =
        bimMaps(view['selection'])
            .map(
              (selection) => {
                'version_id': bimInt(selection['version_id']),
                'element_id': bimInt(selection['element_id']),
              },
            )
            .where(
              (selection) =>
                  widget.versionIds.contains(selection['version_id']) &&
                  selection['element_id']! > 0,
            )
            .toList();
    if (selections.length > 100) {
      throw const ApiException(
        'В замечании можно отметить не более 100 элементов.',
      );
    }
    final versionId =
        selections.isEmpty
            ? widget.versionIds.first
            : selections.first['version_id']!;
    final contextPayload = <String, dynamic>{
      'version_id': versionId,
      'camera': view,
      if (selections.isNotEmpty) 'elements': selections,
      if (selections.isNotEmpty)
        'bim_element_id': '${selections.first['element_id']}',
      if (widget.modelSetRevisionId != null && widget.modelSetRevisionId! > 0)
        'model_set_revision_id': widget.modelSetRevisionId
      else
        'view_models': [
          for (final id in widget.versionIds)
            {
              'version_id': id,
              'transform':
                  (widget.transforms[id] ?? const BimTransform()).toJson(),
            },
        ],
    };
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => BimIssueEditorScreen(
              projectId: widget.projectId,
              versionId: versionId,
              contextPayload: contextPayload,
              snapshot: snapshot,
              snapshotUnavailable: snapshot == null,
              offline: _offline || _networkOffline,
            ),
      ),
    );
  });
  Future<void> _updateIssueSnapshot() => _run(() async {
    try {
      final snapshot = await _controller.captureSnapshot();
      if (ref.read(projectsProvider).selectedProject?.serverId !=
          widget.projectId) {
        throw const ApiException('Объект изменился.');
      }
      await ref
          .read(bimRepositoryProvider)
          .attachSnapshot(
            _snapshotTarget!,
            snapshot,
            idempotencyKey: _snapshotOperationKey,
          );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (error.statusCode == 409 && mounted) {
        setState(() => _snapshotConflict = true);
      }
      rethrow;
    }
  });
}
