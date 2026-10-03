import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../data/bim_models.dart';
import '../domain/bim_provider.dart';
import '../offline/bim_offline_models.dart';
import '../offline/bim_offline_provider.dart';
import '../offline/bim_offline_service.dart';
import 'bim_issue_screens.dart';
import 'bim_viewer_screen.dart';

String bimBytes(int bytes) =>
    bytes >= 1024 * 1024 * 1024
        ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ'
        : bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ'
        : '${(bytes / 1024).toStringAsFixed(0)} КБ';

class BimOfflinePanel extends ConsumerStatefulWidget {
  const BimOfflinePanel({super.key, required this.projectId});
  final int projectId;
  @override
  ConsumerState<BimOfflinePanel> createState() => _BimOfflinePanelState();
}

class _BimOfflinePanelState extends ConsumerState<BimOfflinePanel> {
  BimOfflineService? _service;
  StreamSubscription<void>? _subscription;
  Timer? _reloadTimer;
  List<BimOfflinePackage> _packages = [];
  List<BimIssueDraft> _drafts = [];
  List<BimSavedSet> _sets = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    try {
      final service = await ref.read(bimOfflineServiceProvider.future);
      if (!mounted) return;
      _service = service;
      _subscription = service.changes.listen((_) {
        _reloadTimer ??= Timer(const Duration(milliseconds: 300), () {
          _reloadTimer = null;
          if (mounted) {
            _reload();
          }
        });
      });
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = UserMessage.fromError(error);
        });
      }
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final results = await Future.wait<dynamic>([
        _service!.packages(),
        _service!.drafts(),
        _service!.savedSets(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _packages =
            (results[0] as List<BimOfflinePackage>)
                .where(
                  (package) =>
                      bimInt(package.manifest['project_id']) ==
                      widget.projectId,
                )
                .toList();
        _drafts =
            (results[1] as List<BimIssueDraft>)
                .where(
                  (draft) =>
                      bimInt(draft.payload['project_id']) == widget.projectId &&
                      draft.status != 'completed',
                )
                .toList();
        _sets =
            (results[2] as List<BimSavedSet>)
                .where((set) => set.projectId == widget.projectId)
                .toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = UserMessage.fromError(error);
        });
      }
    }
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(bimOnlineProvider).valueOrNull ?? false;
    if (_loading) {
      return const AppLoadingState(message: 'Читаем сохранённые модели');
    }
    if (_service == null) {
      return AppErrorState(
        title: 'Не удалось открыть сохранённые модели',
        description: _error ?? 'Повторите попытку.',
        onRetry: _initialize,
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Модели сохраняются только по вашей команде. Незавершённое сохранение можно продолжить.',
          ),
          const SizedBox(height: 12),
          for (final set in _sets)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Готово моделей: ${set.completedModels} из ${set.totalModels}',
                    ),
                    if (!set.isReady)
                      LinearProgressIndicator(
                        value:
                            set.totalModels == 0
                                ? null
                                : set.completedModels / set.totalModels,
                      ),
                    if (set.lastError != null) Text(set.lastError!),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: set.isReady ? () => _openSet(set) : null,
                          child: const Text('Открыть набор'),
                        ),
                        if (!set.isReady && set.status != 'downloading')
                          TextButton(
                            onPressed:
                                () => _run(
                                  () => _service!.resumeSet(set.localId),
                                ),
                            child: const Text('Продолжить сохранение'),
                          ),
                        if (set.status == 'downloading')
                          TextButton(
                            onPressed:
                                () => _run(
                                  () => _service!.cancelSet(set.localId),
                                ),
                            child: const Text('Отменить'),
                          ),
                        TextButton(
                          onPressed: () async {
                            if (await _confirm('Удалить сохранённый набор?')) {
                              await _run(
                                () => _service!.removeSet(set.localId),
                              );
                            }
                          },
                          child: const Text('Удалить набор'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_packages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Сохранённых моделей нет. Откройте модель и нажмите «Сохранить на устройстве».',
              ),
            ),
          for (final package in _packages)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${bimBytes(package.downloadedBytes)} из ${bimBytes(package.totalBytes)} · ${_packageStatus(package.status)}',
                    ),
                    if (!package.isReady)
                      LinearProgressIndicator(
                        value: package.progress.clamp(0.0, 1.0),
                      ),
                    if (package.lastError != null)
                      Text(
                        package.lastError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (package.isReady)
                          OutlinedButton(
                            onPressed:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => BimViewerScreen(
                                          projectId: widget.projectId,
                                          title: package.title,
                                          versionIds: [package.versionId],
                                          preferOffline: true,
                                          canCreateIssue: bimMaps(
                                            package
                                                .manifest['available_actions'],
                                          ).any(
                                            (action) =>
                                                action['key'] ==
                                                    'create_issue' &&
                                                action['enabled'] == true,
                                          ),
                                        ),
                                  ),
                                ),
                            child: const Text('Открыть'),
                          ),
                        if (package.status == 'downloading')
                          TextButton(
                            onPressed:
                                () =>
                                    _service!.cancelVersion(package.versionId),
                            child: const Text('Отменить'),
                          ),
                        if (!package.isReady && package.status != 'downloading')
                          TextButton(
                            onPressed:
                                () => _run(
                                  () => _service!.saveVersion(
                                    package.versionId,
                                    title: package.title,
                                    projectId: widget.projectId,
                                  ),
                                ),
                            child: const Text('Продолжить'),
                          ),
                        TextButton(
                          onPressed: () => _removePackage(package),
                          child: const Text('Удалить с устройства'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Замечания к отправке',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Отправить замечания',
                onPressed: _syncing || _drafts.isEmpty ? null : _sync,
                icon:
                    _syncing
                        ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.sync),
              ),
            ],
          ),
          if (_drafts.isEmpty) const Text('Неотправленных замечаний нет.'),
          for (final draft in _drafts)
            Card(
              child: ListTile(
                title: Text('${draft.payload['title'] ?? 'Замечание'}'),
                subtitle: Text(
                  '${_draftStatus(draft.status)}${draft.lastError == null ? '' : '\n${draft.lastError}'}',
                ),
                onTap:
                    draft.editable
                        ? () => Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => BimIssueEditorScreen(
                                      projectId: widget.projectId,
                                      versionId: draft.versionId,
                                      contextPayload: draft.payload,
                                      draft: draft,
                                      offline: true,
                                    ),
                              ),
                            )
                            .then((_) => _reload())
                        : draft.serverId != null && online
                        ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) =>
                                    BimIssueDetailScreen(id: draft.serverId!),
                          ),
                        )
                        : null,
                trailing: IconButton(
                  tooltip: 'Удалить черновик',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeDraft(draft),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _packageStatus(String status) => switch (status) {
    'ready' => 'Готова',
    'downloading' => 'Сохраняется',
    'cancelled' => 'Сохранение отменено',
    'failed' => 'Ошибка сохранения',
    'paused' => 'Сохранение приостановлено',
    _ => 'Ожидает сохранения',
  };
  String _draftStatus(String status) => switch (status) {
    'completed' => 'Отправлено',
    'syncing' || 'sending' => 'Отправляется',
    'conflict' => 'Конфликт редакций: откройте замечание онлайн',
    'failed' => 'Не удалось отправить',
    'blocked' => 'Требует проверки прав',
    'needs_review' => 'Требует проверки перед отправкой',
    _ => 'Ожидает отправки',
  };
  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    }
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(title),
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
      ) ??
      false;
  Future<void> _removePackage(BimOfflinePackage package) async {
    if (await _confirm('Удалить модель с устройства?')) {
      await _run(() => _service!.removeVersion(package.versionId));
    }
  }

  Future<void> _removeDraft(BimIssueDraft draft) async {
    if (await _confirm(
      draft.serverId == null
          ? 'Удалить неотправленное замечание?'
          : 'Удалить очередь вложений? Замечание №${draft.serverId} уже создано на сервере.',
    )) {
      await _run(() => _service!.removeDraft(draft.localId));
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await _run(() => _service!.syncPending());
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _openSet(BimSavedSet set) async {
    await _run(() async {
      final cached = await _service!.cachedSet(set.localId);
      if (cached == null) {
        throw const FormatException(
          'Набор ещё не сохранён полностью. Продолжите сохранение.',
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => BimViewerScreen(
                projectId: cached.projectId,
                title: cached.title,
                versionIds: cached.versionIds,
                transforms: cached.transforms,
                modelSetId: cached.setId,
                modelSetRevisionId: cached.modelSetRevisionId,
                preferOffline: true,
                canCreateIssue: true,
              ),
        ),
      );
    });
  }
}

class BimOfflineScreen extends StatelessWidget {
  const BimOfflineScreen({super.key, required this.projectId});
  final int projectId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('На устройстве')),
    body: BimOfflinePanel(projectId: projectId),
  );
}
