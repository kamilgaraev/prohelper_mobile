import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/bim_models.dart';
import '../data/bim_repository.dart';
import '../domain/bim_provider.dart';
import 'bim_issue_screens.dart';
import 'bim_offline_panel.dart';
import 'bim_viewer_screen.dart';

class BimCatalogScreen extends ConsumerStatefulWidget {
  const BimCatalogScreen({super.key, required this.projectId});
  final int projectId;
  @override
  ConsumerState<BimCatalogScreen> createState() => _BimCatalogScreenState();
}

class _BimCatalogScreenState extends ConsumerState<BimCatalogScreen> {
  final _search = TextEditingController();
  bool _busy = false;
  bool get _online => ref.read(bimOnlineProvider).valueOrNull ?? false;
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(bimCatalogProvider(widget.projectId).notifier).load(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bimOnlineProvider);
    final state = ref.watch(bimCatalogProvider(widget.projectId));
    final selected = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    if (selected != widget.projectId) {
      return const AppEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Объект изменился',
        description: 'Вернитесь в ПИР и откройте модели выбранного объекта.',
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BIM-модели'),
          actions: [
            IconButton(
              tooltip: 'Замечания',
              icon: const Icon(Icons.comment_outlined),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => BimIssuesScreen(projectId: widget.projectId),
                    ),
                  ),
            ),
            IconButton(
              tooltip: 'Обновить',
              onPressed: state.loading ? null : _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Модели'),
              Tab(text: 'Наборы'),
              Tab(text: 'На устройстве'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _models(state),
            _sets(state),
            BimOfflinePanel(projectId: widget.projectId),
          ],
        ),
      ),
    );
  }

  Future<void> _reload() =>
      ref.read(bimCatalogProvider(widget.projectId).notifier).load();
  Widget? _initialState(BimCatalogState state) {
    if (state.loading && state.versions == null) {
      return const AppLoadingState(message: 'Загружаем модели');
    }
    if (state.permissionDenied) {
      return const AppPermissionState(
        title: 'Модели недоступны',
        description: 'У вас нет прав на просмотр моделей этого объекта.',
      );
    }
    if (state.error != null && state.versions == null) {
      return AppErrorState(
        title: 'Не удалось загрузить модели',
        description: state.error!,
        onRetry: _reload,
      );
    }
    return null;
  }

  Widget _models(BimCatalogState state) {
    final initial = _initialState(state);
    if (initial != null) return initial;
    final versions = state.versions;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: (versions?.items.length ?? 0) + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Найти модель или пакет',
                    suffixIcon: IconButton(
                      tooltip: 'Найти',
                      icon: const Icon(Icons.search),
                      onPressed:
                          () => ref
                              .read(
                                bimCatalogProvider(widget.projectId).notifier,
                              )
                              .load(query: _search.text),
                    ),
                  ),
                  onSubmitted:
                      (value) => ref
                          .read(bimCatalogProvider(widget.projectId).notifier)
                          .load(query: value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: state.status,
                  decoration: const InputDecoration(
                    labelText: 'Подготовка модели',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Все версии')),
                    DropdownMenuItem(
                      value: 'ready',
                      child: Text('Готовы к просмотру'),
                    ),
                    DropdownMenuItem(
                      value: 'processing',
                      child: Text('Подготавливаются'),
                    ),
                    DropdownMenuItem(
                      value: 'failed',
                      child: Text('Ошибка подготовки'),
                    ),
                    DropdownMenuItem(
                      value: 'missing',
                      child: Text('Нужна подготовка'),
                    ),
                  ],
                  onChanged:
                      (value) => ref
                          .read(bimCatalogProvider(widget.projectId).notifier)
                          .load(status: value, clearStatus: value == null),
                ),
                const SizedBox(height: 16),
                if (state.loading) const LinearProgressIndicator(),
                if (state.error != null)
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (versions?.items.isEmpty ?? true)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Модели не найдены. Модели добавляют в документацию на сайте МОСТ.',
                    ),
                  ),
              ],
            );
          }
          if (index > (versions?.items.length ?? 0)) {
            return versions != null && versions.page < versions.lastPage
                ? OutlinedButton(
                  onPressed:
                      state.loadingMore
                          ? null
                          : () =>
                              ref
                                  .read(
                                    bimCatalogProvider(
                                      widget.projectId,
                                    ).notifier,
                                  )
                                  .loadMoreVersions(),
                  child: Text(state.loadingMore ? 'Загружаем' : 'Показать ещё'),
                )
                : const SizedBox.shrink();
          }
          final item = versions!.items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IndustrialCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.modelTitle.isEmpty ? item.title : item.modelTitle,
                    ),
                    subtitle: Text(
                      '${item.packageTitle}\nВерсия ${item.versionNumber}${item.isCurrent ? ' · Текущая' : ''}',
                    ),
                    isThreeLine: true,
                  ),
                  Chip(label: Text(item.statusLabel)),
                  if (item.processing)
                    LinearProgressIndicator(
                      value: item.progress > 0 ? item.progress / 100 : null,
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _openVersion(item),
                        icon: const Icon(Icons.view_in_ar_outlined),
                        label: const Text('Открыть'),
                      ),
                      if (!item.ready &&
                          (item.can('prepare_viewer') || item.can('prepare')))
                        TextButton(
                          onPressed:
                              _busy || !_online ? null : () => _prepare(item),
                          child: Text(
                            item.processing
                                ? 'Повторить подготовку'
                                : 'Подготовить к просмотру',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sets(BimCatalogState state) {
    final initial = _initialState(state);
    if (initial != null) return initial;
    final page = state.sets;
    final canCreate =
        page?.actions.any(
          (action) => action.enabled && action.key == 'create',
        ) ??
        false;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (canCreate)
            FilledButton.icon(
              onPressed: _busy || !_online ? null : () => _editSet(null, state),
              icon: const Icon(Icons.add),
              label: const Text('Создать набор'),
            ),
          if (page?.items.isEmpty ?? true)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Наборов пока нет. Набор сохраняет состав и положение выбранных версий моделей.',
              ),
            ),
          for (final set in page?.items ?? <BimModelSet>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IndustrialCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Редакция ${set.revision} · Моделей: ${set.current?.versionIds.length ?? 0}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _busy || !_online
                                  ? null
                                  : () => _openSet(set, set.revision),
                          child: const Text('Открыть'),
                        ),
                        if (set.can('update'))
                          TextButton(
                            onPressed:
                                _busy || !_online
                                    ? null
                                    : () => _editSet(set, state),
                            child: const Text('Изменить'),
                          ),
                        if (set.can('delete'))
                          TextButton(
                            onPressed:
                                _busy || !_online
                                    ? null
                                    : () => _deleteSet(set),
                            child: const Text('Удалить'),
                          ),
                      ],
                    ),
                    if (set.revisions.length > 1)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Предыдущие редакции'),
                        children: [
                          for (final revision in set.revisions.where(
                            (item) => item.revision != set.revision,
                          ))
                            ListTile(
                              title: Text('Редакция ${revision.revision}'),
                              subtitle: Text(
                                'Моделей: ${revision.versionIds.length}',
                              ),
                              trailing: const Icon(Icons.open_in_new),
                              onTap:
                                  _online
                                      ? () => _openSet(set, revision.revision)
                                      : null,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (page != null && page.page < page.lastPage)
            OutlinedButton(
              onPressed:
                  state.loadingMore
                      ? null
                      : () =>
                          ref
                              .read(
                                bimCatalogProvider(widget.projectId).notifier,
                              )
                              .loadMoreSets(),
              child: const Text('Показать ещё'),
            ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepare(BimModelVersion model) => _run(() async {
    await ref.read(bimRepositoryProvider).prepare(model.id);
    await _reload();
  });
  void _openVersion(BimModelVersion model) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (_) => BimViewerScreen(
            projectId: widget.projectId,
            title: model.title,
            versionIds: [model.id],
            canCreateIssue: model.can('create_issue'),
            canPrepare: model.can('prepare_viewer') || model.can('prepare'),
          ),
    ),
  );
  Future<void> _openSet(BimModelSet set, int revision) => _run(() async {
    final opened = await ref
        .read(bimRepositoryProvider)
        .openSet(set.id, revision);
    if (!mounted) return;
    final source = bimMap(opened['revision']);
    final data = source.isNotEmpty ? source : opened;
    final selected = BimSetRevision.fromJson({
      ...data,
      'revision': data['model_set_revision'] ?? data['revision'],
      'version_ids': data['models'] ?? data['version_ids'],
      'id': data['model_set_revision_id'] ?? data['id'],
    });
    if (selected.versionIds.isEmpty) {
      throw StateError('В этой редакции нет моделей.');
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => BimViewerScreen(
              projectId: widget.projectId,
              title: '${set.title} · ${selected.revision}',
              versionIds: selected.versionIds,
              transforms: selected.transforms,
              modelSetRevisionId:
                  selected.id ?? bimInt(opened['model_set_revision_id']),
              modelSetId: set.id,
              canCreateIssue: set.can('create_issue'),
            ),
      ),
    );
  });
  Future<void> _editSet(BimModelSet? set, BimCatalogState state) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => BimSetEditorScreen(
              projectId: widget.projectId,
              existing: set,
              versions: state.versions?.items ?? [],
            ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _deleteSet(BimModelSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить набор?'),
            content: Text(set.title),
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
    if (confirmed == true) {
      await _run(() async {
        await ref.read(bimRepositoryProvider).deleteSet(set);
        await _reload();
      });
    }
  }
}

class BimSetEditorScreen extends ConsumerStatefulWidget {
  const BimSetEditorScreen({
    super.key,
    required this.projectId,
    required this.versions,
    this.existing,
  });
  final int projectId;
  final List<BimModelVersion> versions;
  final BimModelSet? existing;
  @override
  ConsumerState<BimSetEditorScreen> createState() => _BimSetEditorScreenState();
}

class _BimSetEditorScreenState extends ConsumerState<BimSetEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late Map<int, BimTransform> _composition;
  late List<BimModelVersion> _versions;
  BimPage<BimModelVersion>? _versionPage;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title);
    final revision = widget.existing?.current;
    _composition = {
      for (final id in revision?.versionIds ?? <int>[])
        id: revision?.transforms[id] ?? const BimTransform(),
    };
    _versions = widget.versions;
    Future.microtask(_loadAllVersions);
  }

  Future<void> _loadAllVersions({bool more = false}) async {
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(bimRepositoryProvider)
          .versions(
            widget.projectId,
            status: 'ready',
            page: more ? (_versionPage?.page ?? 0) + 1 : 1,
          );
      final versions = {
        if (more)
          for (final version in _versions) version.id: version,
        for (final version in page.items) version.id: version,
      };
      for (final id in _composition.keys) {
        versions.putIfAbsent(
          id,
          () => BimModelVersion(id: id, title: 'Версия $id', status: 'ready'),
        );
      }
      if (mounted) {
        setState(() {
          _versions = versions.values.toList();
          _versionPage = page;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(bimOnlineProvider).valueOrNull ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Новый набор' : 'Изменить набор'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Название набора'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Укажите название'
                          : null,
            ),
            const Text(
              'Выберите точные версии моделей. Смещение задаётся по осям, поворот — в градусах.',
            ),
            if (_loading) const LinearProgressIndicator(),
            for (final version in _versions.where(
              (item) => item.ready || _composition.containsKey(item.id),
            )) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${version.title} · ${version.versionNumber}'),
                subtitle: Text(version.packageTitle),
                value: _composition.containsKey(version.id),
                onChanged:
                    _saving
                        ? null
                        : (value) => setState(() {
                          if (value == true) {
                            _composition[version.id] = const BimTransform();
                          } else {
                            _composition.remove(version.id);
                          }
                        }),
              ),
              if (_composition.containsKey(version.id))
                Row(
                  children: [
                    for (var index = 0; index < 3; index++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextFormField(
                            key: ValueKey('${version.id}-$index'),
                            initialValue:
                                '${_composition[version.id]!.shift[index]}',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              labelText: ['X', 'Y', 'Z'][index],
                            ),
                            validator: _number,
                            onChanged: (value) {
                              final transform = _composition[version.id]!;
                              final shift = [...transform.shift];
                              shift[index] =
                                  double.tryParse(value.replaceAll(',', '.')) ??
                                  0;
                              _composition[version.id] = BimTransform(
                                shift: shift,
                                rotation: transform.rotation,
                              );
                            },
                          ),
                        ),
                      ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${version.id}-rotation'),
                        initialValue: '${_composition[version.id]!.rotation}',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Поворот'),
                        validator: (value) {
                          final error = _number(value);
                          if (error != null) return error;
                          return double.parse(
                                    value!.replaceAll(',', '.'),
                                  ).abs() >
                                  360
                              ? 'От −360 до 360'
                              : null;
                        },
                        onChanged: (value) {
                          final transform = _composition[version.id]!;
                          _composition[version.id] = BimTransform(
                            shift: transform.shift,
                            rotation:
                                double.tryParse(value.replaceAll(',', '.')) ??
                                0,
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_versionPage != null &&
                _versionPage!.page < _versionPage!.lastPage)
              OutlinedButton(
                onPressed: _loading ? null : () => _loadAllVersions(more: true),
                child: const Text('Показать ещё модели'),
              ),
            if (!online)
              const Text('Для изменения наборов подключитесь к интернету.'),
            FilledButton(
              onPressed: _saving || _loading || !online ? null : _save,
              child: Text(_saving ? 'Сохраняем' : 'Сохранить набор'),
            ),
          ],
        ),
      ),
    );
  }

  String? _number(String? value) {
    final number = double.tryParse(value?.replaceAll(',', '.') ?? '');
    return number == null || !number.isFinite ? 'Введите число' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_composition.isEmpty) {
      setState(() => _error = 'Выберите хотя бы одну модель.');
      return;
    }
    if (_composition.length > 100) {
      setState(() => _error = 'В набор можно включить не более 100 моделей.');
      return;
    }
    final selected = ref.read(projectsProvider).selectedProject?.serverId;
    if (selected != widget.projectId) {
      setState(() => _error = 'Объект изменился. Откройте набор заново.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(bimRepositoryProvider)
          .saveSet(
            projectId: widget.projectId,
            title: _title.text,
            composition: _composition,
            existing: widget.existing,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
