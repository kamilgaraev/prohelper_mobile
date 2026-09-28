import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/pro_record_card.dart';
import '../../auth/data/auth_session_identity.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/field_catalog_repository.dart';
import '../data/project_files_repository.dart';

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
    this.detailFieldLabels,
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
  final Map<String, String>? detailFieldLabels;

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
  String? _staleError;
  bool _permissionDenied = false;
  int _requestVersion = 0;
  int? _contextProjectId;
  AuthSessionIdentity? _contextIdentity;
  AuthSessionIdentity? _loadedIdentity;
  int? _loadedProjectId;
  String? _loadedEntity;
  String? _loadedQuery;

  @override
  void initState() {
    super.initState();
    _entity = widget.entities.isEmpty ? null : widget.entities.first.key;
    _contextProjectId = ref.read(projectsProvider).selectedProject?.serverId;
    final auth = ref.read(authProvider);
    _contextIdentity = auth is AuthAuthenticated ? auth.sessionIdentity : null;
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
    final identity = ref.watch(
      authProvider.select(
        (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
      ),
    );
    if (identity != _contextIdentity) {
      _contextIdentity = identity;
      Future.microtask(() {
        if (identity == null) {
          _clearForMissingIdentity();
        } else {
          _load();
        }
      });
    }
    final projectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    if (_usesProjectScope && projectId != _contextProjectId) {
      _contextProjectId = projectId;
      Future.microtask(_load);
    }
    final hasMatchingOwner =
        identity != null &&
        _loadedIdentity == identity &&
        _loadedProjectId == (_usesProjectScope ? projectId : null) &&
        _loadedEntity == _entity;
    final visiblePage = hasMatchingOwner ? _page : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.catalog == 'templates' &&
                  (MediaQuery.sizeOf(context).width < 390 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.15)
              ? 'Шаблоны'
              : widget.title,
        ),
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
            if ((_loadedQuery != (_searchEnabled ? _query : null) ||
                    _staleError != null) &&
                visiblePage != null)
              _StaleCatalogDataNotice(
                previousQuery: _loadedQuery != (_searchEnabled ? _query : null),
              ),
            if (_loading && visiblePage == null)
              const AppLoadingState(message: 'Загружаем записи')
            else if (_permissionDenied && visiblePage == null)
              const AppPermissionState(
                title: 'Раздел недоступен',
                description: 'У вас нет прав для просмотра этих записей.',
              )
            else if (_error != null && visiblePage == null)
              AppErrorState(
                title: 'Не удалось загрузить записи',
                description: _error,
                onRetry: _load,
              )
            else if (visiblePage?.items.isEmpty ?? true)
              AppEmptyState(
                icon: widget.icon,
                title: 'Записей пока нет',
                description: 'По текущему запросу ничего не найдено.',
              )
            else ...[
              Text(
                'Показано ${visiblePage!.items.length} из ${visiblePage.total}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final entry in visiblePage.items) ...[
                ProRecordCard(
                  title: entry.title,
                  subtitle:
                      _catalogSubtitle(widget.catalog, entry) ??
                      'Открыть карточку записи',
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
              if (_loadedQuery == (_searchEnabled ? _query : null) &&
                  visiblePage.currentPage < visiblePage.lastPage)
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
    final identity = ref.read(authProvider);
    final requestIdentity =
        identity is AuthAuthenticated ? identity.sessionIdentity : null;
    final requestProjectId = _usesProjectScope ? _contextProjectId : null;
    final requestEntity = _entity;
    final requestQuery = _searchEnabled ? _query : null;
    if (requestIdentity == null) {
      setState(() {
        _page = null;
        _loadedIdentity = null;
        _loadedProjectId = null;
        _loadedEntity = null;
        _loadedQuery = null;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _staleError = null;
      });
      return;
    }
    final sameOwner =
        _loadedIdentity == requestIdentity &&
        _loadedProjectId == requestProjectId &&
        _loadedEntity == requestEntity;
    setState(() {
      _loading = true;
      _loadingMore = false;
      if (!sameOwner) {
        _page = null;
        _loadedIdentity = null;
        _loadedProjectId = null;
        _loadedEntity = null;
        _loadedQuery = null;
      }
      _error = null;
      _staleError = null;
      _permissionDenied = false;
    });
    try {
      final page = await ref
          .read(fieldCatalogRepositoryProvider)
          .fetchPage(
            catalog: widget.catalog,
            apiPrefix: widget.apiPrefix,
            entity: _entity,
            query: requestQuery,
            queryParameter: widget.queryParameter,
            projectId: requestProjectId,
            extraQueryParameters: widget.extraQueryParameters,
          );
      if (!mounted || version != _requestVersion) return;
      final currentAuth = ref.read(authProvider);
      if (currentAuth is! AuthAuthenticated ||
          currentAuth.sessionIdentity != requestIdentity ||
          (_usesProjectScope &&
              ref.read(projectsProvider).selectedProject?.serverId !=
                  requestProjectId) ||
          _entity != requestEntity) {
        return;
      }
      setState(() {
        _page = page;
        _loadedIdentity = requestIdentity;
        _loadedProjectId = requestProjectId;
        _loadedEntity = requestEntity;
        _loadedQuery = requestQuery;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      final currentAuth = ref.read(authProvider);
      final requestOwnerStillCurrent =
          currentAuth is AuthAuthenticated &&
          currentAuth.sessionIdentity == requestIdentity &&
          (!_usesProjectScope ||
              ref.read(projectsProvider).selectedProject?.serverId ==
                  requestProjectId) &&
          _entity == requestEntity;
      if (isSnapshotOffline(error) &&
          sameOwner &&
          requestOwnerStillCurrent &&
          _page != null) {
        setState(() {
          _staleError = UserMessage.fromError(error);
          _error = null;
          _loading = false;
          _permissionDenied = false;
        });
        return;
      }
      setState(() {
        _page = null;
        _loadedIdentity = null;
        _loadedProjectId = null;
        _loadedEntity = null;
        _loadedQuery = null;
        _error = UserMessage.fromError(error);
        _staleError = null;
        _permissionDenied = error is ApiException && error.statusCode == 403;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final current = _page;
    final auth = ref.read(authProvider);
    final requestIdentity =
        auth is AuthAuthenticated ? auth.sessionIdentity : null;
    final requestProjectId =
        _usesProjectScope
            ? ref.read(projectsProvider).selectedProject?.serverId
            : null;
    final requestEntity = _entity;
    final requestQuery = _searchEnabled ? _query : null;
    final requestVersion = _requestVersion;
    if (current == null ||
        _loadingMore ||
        requestIdentity == null ||
        _loadedIdentity != requestIdentity ||
        _loadedProjectId != requestProjectId ||
        _loadedEntity != requestEntity ||
        _loadedQuery != requestQuery) {
      return;
    }
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
            entity: requestEntity,
            query: requestQuery,
            queryParameter: widget.queryParameter,
            projectId: requestProjectId,
            extraQueryParameters: widget.extraQueryParameters,
            page: current.currentPage + 1,
          );
      if (!mounted ||
          requestVersion != _requestVersion ||
          current != _page ||
          _queryForCurrentRequest != requestQuery ||
          _entity != requestEntity ||
          (ref.read(authProvider) is! AuthAuthenticated) ||
          (ref.read(authProvider) as AuthAuthenticated).sessionIdentity !=
              requestIdentity ||
          (_usesProjectScope &&
              ref.read(projectsProvider).selectedProject?.serverId !=
                  requestProjectId)) {
        return;
      }
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
      if (!mounted || requestVersion != _requestVersion) return;
      final currentAuth = ref.read(authProvider);
      final ownerStillCurrent =
          currentAuth is AuthAuthenticated &&
          currentAuth.sessionIdentity == requestIdentity &&
          _entity == requestEntity &&
          (!_usesProjectScope ||
              ref.read(projectsProvider).selectedProject?.serverId ==
                  requestProjectId);
      if (!ownerStillCurrent) return;
      setState(() {
        _loadingMore = false;
        _error = UserMessage.fromError(error);
        if (!isSnapshotOffline(error)) {
          _page = null;
          _loadedIdentity = null;
          _loadedProjectId = null;
          _loadedEntity = null;
          _loadedQuery = null;
          _staleError = null;
          _permissionDenied = error is ApiException && error.statusCode == 403;
        }
      });
    }
  }

  String? get _queryForCurrentRequest => _searchEnabled ? _query : null;

  void _clearForMissingIdentity() {
    if (!mounted || ref.read(authProvider) is AuthAuthenticated) return;
    _requestVersion++;
    setState(() {
      _page = null;
      _loadedIdentity = null;
      _loadedProjectId = null;
      _loadedEntity = null;
      _loadedQuery = null;
      _loading = false;
      _loadingMore = false;
      _error = null;
      _staleError = null;
      _permissionDenied = false;
    });
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
              detailFieldLabels: widget.detailFieldLabels,
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

class _StaleCatalogDataNotice extends StatelessWidget {
  const _StaleCatalogDataNotice({required this.previousQuery});

  final bool previousQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        previousQuery
            ? 'Показан последний успешно загруженный список. Он может не учитывать текущий поиск.'
            : 'Не удалось обновить список. Показаны данные последней успешной загрузки.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
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
    this.detailFieldLabels,
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
  final Map<String, String>? detailFieldLabels;

  @override
  ConsumerState<FieldCatalogDetailScreen> createState() =>
      _FieldCatalogDetailScreenState();
}

class _FieldCatalogDetailScreenState
    extends ConsumerState<FieldCatalogDetailScreen> {
  late Future<FieldCatalogEntry> _future;
  bool _downloadingProjectFile = false;

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
        final compact =
            MediaQuery.sizeOf(context).width < 390 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.15;
        final subtitle =
            widget.catalog == 'templates'
                ? null
                : _catalogSubtitle(widget.catalog, entry);
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
                title: Text(
                  entry.title,
                  style:
                      compact
                          ? theme.textTheme.bodyLarge
                          : theme.textTheme.titleLarge,
                ),
                subtitle: subtitle == null ? null : Text(subtitle),
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
                      _downloadingProjectFile
                          ? null
                          : widget.catalog == 'project-files'
                          ? _downloadProjectFile
                          : () => _openDownload(
                            entry.fields['download_url'] as String,
                          ),
                  icon:
                      _downloadingProjectFile
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.download_rounded),
                  label: Text(
                    _downloadingProjectFile
                        ? 'Получаем ссылку'
                        : 'Скачать файл',
                  ),
                ),
              ),
            for (final item in entry.fields.entries)
              if (_catalogField(
                    widget.catalog,
                    item.key,
                    item.value,
                    detailFieldLabels: widget.detailFieldLabels,
                  )
                  case final field?)
                Card(
                  child: ListTile(
                    title: Text(field.label),
                    subtitle: Text(field.value),
                  ),
                ),
          ],
        );
      },
    ),
  );

  Future<void> _downloadProjectFile() async {
    final projectId = widget.projectId;
    if (projectId == null || _downloadingProjectFile) {
      _showProjectFileDownloadError();
      return;
    }
    setState(() => _downloadingProjectFile = true);
    try {
      final entry = await ref
          .read(projectFilesRepositoryProvider)
          .fetchDetail(projectId: projectId, fileId: widget.uuid);
      if (!mounted) return;
      final freshUrl = entry.fields['download_url'];
      if (freshUrl is! String || freshUrl.isEmpty) {
        _showProjectFileDownloadError();
        return;
      }
      await _openDownload(freshUrl);
    } catch (_) {
      if (mounted) _showProjectFileDownloadError();
    } finally {
      if (mounted) setState(() => _downloadingProjectFile = false);
    }
  }

  void _showProjectFileDownloadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Не удалось получить ссылку на файл. Повторите попытку.'),
      ),
    );
  }

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

const _crmStatusLabels = <String, String>{
  'active': 'Активна',
  'archived': 'В архиве',
  'cancelled': 'Отменена',
  'converted': 'Преобразована',
  'done': 'Завершена',
  'in_work': 'В работе',
  'inactive': 'Неактивна',
  'lost': 'Проиграна',
  'merged': 'Объединена',
  'new': 'Новая',
  'open': 'Открыта',
  'overdue': 'Просрочена',
  'paused': 'Приостановлена',
  'planned': 'Запланирована',
  'qualified': 'Квалифицирована',
  'won': 'Выиграна',
};

const _crmFieldLabels = <String, String>{
  'legal_name': 'Юридическое название',
  'company_type': 'Тип компании',
  'status': 'Статус',
  'inn': 'ИНН',
  'kpp': 'КПП',
  'ogrn': 'ОГРН',
  'phone': 'Телефон',
  'email': 'Электронная почта',
  'website': 'Сайт',
  'legal_address': 'Юридический адрес',
  'actual_address': 'Фактический адрес',
  'position': 'Должность',
  'is_primary': 'Основной контакт',
  'company': 'Компания',
  'contact': 'Контакт',
  'primary_contact': 'Основной контакт',
  'owner': 'Ответственный',
  'source': 'Источник',
  'title': 'Название',
  'priority': 'Приоритет',
  'estimated_amount': 'Планируемая сумма',
  'amount': 'Сумма',
  'currency': 'Валюта',
  'expected_start_date': 'Планируемое начало',
  'expected_close_at': 'Планируемое закрытие',
  'need_description': 'Потребность',
  'lost_reason': 'Причина отказа',
  'project': 'Проект',
  'contract': 'Договор',
  'pipeline': 'Воронка',
  'stage': 'Этап',
  'probability': 'Вероятность',
  'next_activity_at': 'Следующее действие',
  'last_activity_at': 'Последнее действие',
  'notes': 'Заметки',
  'tags': 'Метки',
};

const _templateReportTypeLabels = <String, String>{
  'material_usage': 'Расход материалов',
  'work_completion': 'Выполнение работ',
  'foreman_activity': 'Работа прораба',
  'project_status_summary': 'Состояние объекта',
  'contractor_summary': 'Подрядчики: сводка',
  'contractor_detail': 'Подрядчики: детализация',
};

String? _catalogSubtitle(String catalog, FieldCatalogEntry entry) {
  if (catalog == 'project-files') return null;
  if (catalog == 'templates') {
    return _templateReportTypeLabels[_displayValue(
      entry.fields['report_type'],
    )];
  }
  if (catalog != 'crm') return entry.subtitle;
  final statusLabel = _displayValue(entry.fields['status_label']);
  if (statusLabel != null) return statusLabel;
  final status = _displayValue(entry.fields['status']);
  if (status != null) {
    final label = _crmStatusLabels[status];
    if (label != null) return label;
  }
  return _displayValue(entry.fields['email']) ??
      _displayValue(entry.fields['phone']);
}

({String label, String value})? _catalogField(
  String catalog,
  String key,
  dynamic value, {
  Map<String, String>? detailFieldLabels,
}) {
  if (key == 'download_url') return null;
  if (detailFieldLabels != null) {
    final label = detailFieldLabels[key];
    if (label == null || value == null) return null;
    final text = switch (key) {
      'size' => _formatFileSize(value),
      'mime_type' => _formatFileType(value),
      'created_at' => _formatFileDate(value),
      _ => _displayValue(value),
    };
    return text == null ? null : (label: label, value: text);
  }
  if (catalog == 'templates') {
    if (key == 'report_type') {
      final type = _displayValue(value);
      return type == null
          ? null
          : (
            label: 'Тип отчёта',
            value: _templateReportTypeLabels[type] ?? 'Другой тип',
          );
    }
    if (key == 'is_default' && value is bool) {
      return (label: 'Стандартный шаблон', value: value ? 'Да' : 'Нет');
    }
    if (key == 'columns_config' && value is List) {
      final headers =
          value
              .whereType<Map>()
              .map((column) => _displayValue(column['header']))
              .whereType<String>()
              .toList();
      return headers.isEmpty
          ? null
          : (label: 'Столбцы', value: headers.join(', '));
    }
    return null;
  }
  if (catalog != 'crm') {
    final text = _displayValue(value);
    if (text == null) return null;
    return (label: _fieldLabel(key), value: text);
  }
  final label = _crmFieldLabels[key];
  if (label == null || value == null) return null;
  String? text;
  if (key == 'status') {
    text = _crmStatusLabels[value.toString()];
  } else if (key == 'company_type') {
    text =
        const {
          'legal_entity': 'Юридическое лицо',
          'individual': 'Физическое лицо',
          'holding': 'Холдинг',
          'partner': 'Партнёр',
        }[value.toString()];
  } else if (key == 'priority') {
    text =
        const {
          'low': 'Низкий',
          'normal': 'Обычный',
          'high': 'Высокий',
          'urgent': 'Срочный',
        }[value.toString()];
  } else if (value is bool) {
    text = value ? 'Да' : 'Нет';
  } else if (value is Map) {
    for (final field in const ['name', 'full_name', 'title', 'number']) {
      text = _displayValue(value[field]);
      if (text != null) break;
    }
  } else if (value is List) {
    if (key == 'tags') {
      text = value
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .join(', ');
    }
  } else {
    text = _displayValue(value);
  }
  return text == null || text.isEmpty ? null : (label: label, value: text);
}

String? _formatFileSize(dynamic value) {
  if (value is! num || value < 0) return null;
  if (value < 1024) return '${value.toInt()} Б';
  final kilobytes = value / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} КБ';
  return '${(kilobytes / 1024).toStringAsFixed(1)} МБ';
}

String? _formatFileType(dynamic value) {
  final mimeType = _displayValue(value)?.toLowerCase();
  if (mimeType == null) return null;
  if (mimeType.startsWith('image/')) return 'Изображение';
  return const {
        'application/pdf': 'PDF',
        'application/msword': 'DOC',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
            'DOCX',
        'application/vnd.ms-excel': 'XLS',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
            'XLSX',
      }[mimeType] ??
      'Документ';
}

String? _formatFileDate(dynamic value) {
  final text = _displayValue(value);
  final date = text == null ? null : DateTime.tryParse(text);
  return date == null
      ? null
      : DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
}

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
