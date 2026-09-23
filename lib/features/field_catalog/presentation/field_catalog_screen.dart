import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/pro_record_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/field_catalog_repository.dart';

class FieldCatalogOption {
  const FieldCatalogOption(
    this.key,
    this.label, {
    this.hasDetail = true,
    this.supportsSearch = true,
  });
  final String key;
  final String label;
  final bool hasDetail;
  final bool supportsSearch;
}

class FieldCatalogScreen extends ConsumerStatefulWidget {
  const FieldCatalogScreen({
    super.key,
    required this.title,
    required this.catalog,
    required this.icon,
    this.apiPrefix,
    this.entities = const [],
    this.allowSearch = true,
    this.projectScoped = false,
    this.queryParameter = 'q',
    this.extraQueryParameters = const {},
    this.appBarAction,
    this.appBarActionBuilder,
    this.detailActionBuilder,
  });

  final String title;
  final String catalog;
  final IconData icon;
  final String? apiPrefix;
  final List<FieldCatalogOption> entities;
  final bool allowSearch;
  final bool projectScoped;
  final String queryParameter;
  final Map<String, Object?> extraQueryParameters;
  final Widget? appBarAction;
  final Widget Function(BuildContext context, Future<void> Function() refresh)?
  appBarActionBuilder;
  final Widget Function(
    BuildContext context,
    FieldCatalogEntry entry,
    int? projectId,
  )?
  detailActionBuilder;

  @override
  ConsumerState<FieldCatalogScreen> createState() => _FieldCatalogScreenState();
}

class _FieldCatalogScreenState extends ConsumerState<FieldCatalogScreen> {
  final _queryController = TextEditingController();
  Timer? _searchTimer;
  String? _entity;
  String? _query;
  FieldCatalogPage? _page;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _permissionDenied = false;
  int _requestVersion = 0;
  int? _contextProjectId;

  @override
  void initState() {
    super.initState();
    _entity = widget.entities.isEmpty ? null : widget.entities.first.key;
    _contextProjectId = ref.read(projectsProvider).selectedProject?.serverId;
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    if (_usesProjectScope && projectId != _contextProjectId) {
      _contextProjectId = projectId;
      Future.microtask(_load);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.appBarAction != null) widget.appBarAction!,
          if (widget.appBarActionBuilder != null)
            widget.appBarActionBuilder!(context, _load),
          IconButton(
            tooltip: 'Обновить список',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (widget.entities.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _entity,
                decoration: const InputDecoration(labelText: 'Тип записей'),
                items: [
                  for (final option in widget.entities)
                    DropdownMenuItem(
                      value: option.key,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _entity = value;
                    _query = null;
                    _queryController.clear();
                  });
                  _load();
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_searchEnabled)
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Поиск',
                  suffixIcon:
                      _queryController.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Очистить поиск',
                            onPressed: () {
                              _searchTimer?.cancel();
                              _queryController.clear();
                              _query = null;
                              _load();
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                ),
                onChanged: (value) {
                  _searchTimer?.cancel();
                  _searchTimer = Timer(const Duration(milliseconds: 350), () {
                    _query = value.trim().isEmpty ? null : value.trim();
                    _load();
                  });
                  setState(() {});
                },
              ),
            if (_searchEnabled) const SizedBox(height: 16),
            if (_loading && _page == null)
              const AppLoadingState(message: 'Загружаем записи')
            else if (_permissionDenied && _page == null)
              const AppPermissionState(
                title: 'Раздел недоступен',
                description: 'У вас нет прав для просмотра этих записей.',
              )
            else if (_error != null && _page == null)
              AppErrorState(
                title: 'Не удалось загрузить записи',
                description: _error,
                onRetry: _load,
              )
            else if (_page?.items.isEmpty ?? true)
              AppEmptyState(
                icon: widget.icon,
                title: 'Записей пока нет',
                description: 'По текущему запросу ничего не найдено.',
              )
            else ...[
              Text(
                'Показано ${_page!.items.length} из ${_page!.total}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final entry in _page!.items) ...[
                ProRecordCard(
                  title: entry.title,
                  subtitle: entry.subtitle ?? 'Открыть карточку записи',
                  icon: widget.icon,
                  onTap:
                      _entityOption?.hasDetail == false
                          ? null
                          : () => _open(entry),
                  trailing:
                      _entityOption?.hasDetail == false
                          ? Icon(
                            Icons.info_outline_rounded,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          )
                          : null,
                ),
                const SizedBox(height: 10),
              ],
              if (_page!.currentPage < _page!.lastPage)
                OutlinedButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon:
                      _loadingMore
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.expand_more_rounded),
                  label: Text(_loadingMore ? 'Загружаем' : 'Загрузить ещё'),
                ),
              if (_error != null)
                Text(
                  'Не удалось загрузить следующую страницу: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _page = null;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final page = await ref
          .read(fieldCatalogRepositoryProvider)
          .fetchPage(
            catalog: widget.catalog,
            apiPrefix: widget.apiPrefix,
            entity: _entity,
            query: _searchEnabled ? _query : null,
            queryParameter: widget.queryParameter,
            projectId: _usesProjectScope ? _contextProjectId : null,
            extraQueryParameters: widget.extraQueryParameters,
          );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _error = UserMessage.fromError(error);
        _permissionDenied = error is ApiException && error.statusCode == 403;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final current = _page;
    if (current == null || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final next = await ref
          .read(fieldCatalogRepositoryProvider)
          .fetchPage(
            catalog: widget.catalog,
            apiPrefix: widget.apiPrefix,
            entity: _entity,
            query: _searchEnabled ? _query : null,
            queryParameter: widget.queryParameter,
            projectId: _usesProjectScope ? _contextProjectId : null,
            extraQueryParameters: widget.extraQueryParameters,
            page: current.currentPage + 1,
          );
      if (!mounted || current != _page) return;
      final ids = current.items.map((item) => item.uuid).toSet();
      setState(() {
        _page = FieldCatalogPage(
          items: [
            ...current.items,
            ...next.items.where((item) => ids.add(item.uuid)),
          ],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        );
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = UserMessage.fromError(error);
      });
    }
  }

  Future<void> _open(FieldCatalogEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => FieldCatalogDetailScreen(
              title: widget.title,
              catalog: widget.catalog,
              apiPrefix: widget.apiPrefix,
              entity: _entity,
              uuid: entry.uuid,
              icon: widget.icon,
              projectId: _usesProjectScope ? _contextProjectId : null,
              actionBuilder: widget.detailActionBuilder,
            ),
      ),
    );
  }

  bool get _usesProjectScope =>
      widget.projectScoped ||
      widget.catalog == 'tenders' ||
      (widget.catalog == 'crm' && _entity == 'deals');

  FieldCatalogOption? get _entityOption {
    for (final option in widget.entities) {
      if (option.key == _entity) return option;
    }
    return null;
  }

  bool get _searchEnabled =>
      widget.allowSearch && (_entityOption?.supportsSearch ?? true);
}

class FieldCatalogDetailScreen extends ConsumerStatefulWidget {
  const FieldCatalogDetailScreen({
    super.key,
    required this.title,
    required this.catalog,
    required this.uuid,
    required this.icon,
    this.apiPrefix,
    this.projectId,
    this.entity,
    this.actionBuilder,
  });

  final String title;
  final String catalog;
  final String? entity;
  final String uuid;
  final IconData icon;
  final String? apiPrefix;
  final int? projectId;
  final Widget Function(
    BuildContext context,
    FieldCatalogEntry entry,
    int? projectId,
  )?
  actionBuilder;

  @override
  ConsumerState<FieldCatalogDetailScreen> createState() =>
      _FieldCatalogDetailScreenState();
}

class _FieldCatalogDetailScreenState
    extends ConsumerState<FieldCatalogDetailScreen> {
  late Future<FieldCatalogEntry> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<FieldCatalogEntry> _load() => ref
      .read(fieldCatalogRepositoryProvider)
      .fetchDetail(
        catalog: widget.catalog,
        apiPrefix: widget.apiPrefix,
        entity: widget.entity,
        uuid: widget.uuid,
        projectId: widget.projectId,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<FieldCatalogEntry>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(message: 'Загружаем запись');
        }
        if (snapshot.hasError) {
          final error = snapshot.error!;
          if (error is ApiException && error.statusCode == 403) {
            return const AppPermissionState(
              title: 'Запись недоступна',
              description: 'У вас нет прав для просмотра этой записи.',
            );
          }
          return AppErrorState(
            title: 'Не удалось загрузить запись',
            description: UserMessage.fromError(error),
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final entry = snapshot.requireData;
        final theme = Theme.of(context);
        final canCreateCrmActivity =
            widget.catalog == 'crm' &&
            const {
              'companies',
              'contacts',
              'leads',
              'deals',
            }.contains(widget.entity) &&
            ref
                .watch(permissionServiceProvider)
                .hasPermission('crm.activities.create');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(widget.icon, color: theme.colorScheme.primary),
                title: Text(entry.title, style: theme.textTheme.titleLarge),
                subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.actionBuilder != null) ...[
              widget.actionBuilder!(context, entry, widget.projectId),
              const SizedBox(height: 12),
            ],
            if (canCreateCrmActivity) ...[
              FilledButton.icon(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder:
                          (_) => CrmActivityFormScreen(
                            targetType: widget.entity!,
                            targetId: entry.uuid,
                          ),
                    ),
                  );
                  if (created == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Запись добавлена в CRM')),
                    );
                  }
                },
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Добавить заметку или контакт'),
              ),
              const SizedBox(height: 12),
            ],
            if (entry.fields['download_url'] is String &&
                (entry.fields['download_url'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  onPressed:
                      () =>
                          _openDownload(entry.fields['download_url'] as String),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Скачать файл'),
                ),
              ),
            for (final item in entry.fields.entries)
              if (item.key != 'download_url' &&
                  _displayValue(item.value) != null)
                Card(
                  child: ListTile(
                    title: Text(_fieldLabel(item.key)),
                    subtitle: Text(_displayValue(item.value)!),
                  ),
                ),
          ],
        );
      },
    ),
  );

  Future<void> _openDownload(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ссылка для скачивания недоступна. Обновите запись и повторите попытку.',
          ),
        ),
      );
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('download_url_not_opened');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось открыть файл. Обновите запись и повторите попытку.',
          ),
        ),
      );
    }
  }
}

class CrmActivityFormScreen extends ConsumerStatefulWidget {
  const CrmActivityFormScreen({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  ConsumerState<CrmActivityFormScreen> createState() =>
      _CrmActivityFormScreenState();
}

class _CrmActivityFormScreenState extends ConsumerState<CrmActivityFormScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'note';
  DateTime? _dueAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref
        .watch(permissionServiceProvider)
        .hasPermission('crm.activities.create');
    return Scaffold(
      appBar: AppBar(title: const Text('Новая запись CRM')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!allowed)
            const AppPermissionState(
              title: 'Действие недоступно',
              description: 'У вас нет права добавлять записи CRM.',
            )
          else ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'note', label: Text('Заметка')),
                ButtonSegment(value: 'next_contact', label: Text('Контакт')),
              ],
              selected: {_kind},
              onSelectionChanged:
                  _saving
                      ? null
                      : (value) => setState(() {
                        _kind = value.first;
                        if (_kind == 'note') _dueAt = null;
                      }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _subject,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Тема',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
              ),
            ),
            if (_kind == 'next_contact') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDueDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dueAt == null
                      ? 'Выбрать дату следующего контакта'
                      : 'Следующий контакт: ${_formatDate(_dueAt!)}',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Сохраняем' : 'Сохранить'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date != null && mounted) setState(() => _dueAt = date);
  }

  Future<void> _submit() async {
    if (!ref
        .read(permissionServiceProvider)
        .hasPermission('crm.activities.create')) {
      return;
    }
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'Укажите тему записи.');
      return;
    }
    if (_kind == 'next_contact' && _dueAt == null) {
      setState(() => _error = 'Укажите дату следующего контакта.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(fieldCatalogRepositoryProvider)
          .createCrmActivity(
            kind: _kind,
            targetType: widget.targetType,
            targetId: widget.targetId,
            subject: _subject.text.trim(),
            body: _body.text,
            dueAt: _dueAt,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = UserMessage.fromError(error);
      });
    }
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

String? _displayValue(dynamic value) {
  if (value == null) return null;
  if (value is Map || value is List) return value.toString();
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _fieldLabel(String key) {
  final spaced = key.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match[1]} ${match[2]}',
  );
  return spaced
      .replaceAll('_', ' ')
      .replaceFirstMapped(RegExp(r'^.'), (match) => match[0]!.toUpperCase());
}
