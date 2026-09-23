import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/pro_record_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/field_catalog_repository.dart';
import '../data/team_expansion_repository.dart';
import 'field_catalog_screen.dart';

enum _BrigadeTab { catalog, requests, invitations }

class BrigadesScreen extends ConsumerStatefulWidget {
  const BrigadesScreen({super.key});

  @override
  ConsumerState<BrigadesScreen> createState() => _BrigadesScreenState();
}

class _BrigadesScreenState extends ConsumerState<BrigadesScreen> {
  _BrigadeTab _tab = _BrigadeTab.catalog;
  final _search = TextEditingController();
  String? _query;
  FieldCatalogPage? _page;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _projectId;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    final permissions = ref.read(permissionServiceProvider);
    if (!permissions.hasPermission('brigades.catalog.view')) {
      _tab =
          permissions.hasPermission('brigades.requests.view')
              ? _BrigadeTab.requests
              : _BrigadeTab.invitations;
    }
    _projectId = ref.read(projectsProvider).selectedProject?.serverId;
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(
      projectsProvider.select((state) => state.selectedProject?.serverId),
    );
    if (projectId != _projectId) {
      _projectId = projectId;
      Future.microtask(_load);
    }
    final permissions = ref.watch(permissionServiceProvider);
    final canSee = switch (_tab) {
      _BrigadeTab.catalog => permissions.hasPermission('brigades.catalog.view'),
      _BrigadeTab.requests => permissions.hasPermission(
        'brigades.requests.view',
      ),
      _BrigadeTab.invitations => permissions.hasPermission(
        'brigades.invitations.view',
      ),
    };
    final canCreateRequest =
        _tab == _BrigadeTab.requests &&
        permissions.hasPermission('brigades.requests.create');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бригады'),
        actions: [
          if (canCreateRequest)
            IconButton(
              tooltip: 'Создать запрос бригады',
              onPressed: () => _createRequest(projectId),
              icon: const Icon(Icons.add_rounded),
            ),
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
            SegmentedButton<_BrigadeTab>(
              segments: [
                ButtonSegment(
                  value: _BrigadeTab.catalog,
                  label: const Text('Каталог'),
                  enabled: permissions.hasPermission('brigades.catalog.view'),
                ),
                ButtonSegment(
                  value: _BrigadeTab.requests,
                  label: const Text('Запросы'),
                  enabled: permissions.hasPermission('brigades.requests.view'),
                ),
                ButtonSegment(
                  value: _BrigadeTab.invitations,
                  label: const Text('Приглашения'),
                  enabled: permissions.hasPermission(
                    'brigades.invitations.view',
                  ),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                setState(() {
                  _tab = selection.first;
                  _page = null;
                  _query = null;
                  _search.clear();
                });
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_tab != _BrigadeTab.catalog && projectId != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(
                    ref.watch(projectsProvider).selectedProject!.name,
                  ),
                  subtitle: const Text('Фильтр выбранного объекта'),
                ),
              ),
            if (_tab == _BrigadeTab.catalog)
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Название, описание, специализация или город',
                  suffixIcon:
                      _search.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Очистить поиск',
                            onPressed: () {
                              _search.clear();
                              _query = null;
                              _load();
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                ),
                onChanged: (value) {
                  setState(() {});
                  _query = value.trim().isEmpty ? null : value.trim();
                  _load();
                },
              ),
            if (_tab == _BrigadeTab.catalog) const SizedBox(height: 12),
            if (!canSee)
              const AppPermissionState(
                title: 'Раздел недоступен',
                description: 'У вас нет права просматривать этот список.',
              )
            else if (_loading && _page == null)
              const AppLoadingState(message: 'Загружаем список')
            else if (_error != null && _page == null)
              AppErrorState(
                title: 'Не удалось загрузить список',
                description: _error,
                onRetry: _load,
              )
            else if (_page?.items.isEmpty ?? true)
              AppEmptyState(
                icon: Icons.groups_outlined,
                title: switch (_tab) {
                  _BrigadeTab.catalog => 'Подходящие бригады не найдены',
                  _BrigadeTab.requests => 'Запросов пока нет',
                  _BrigadeTab.invitations => 'Приглашений пока нет',
                },
                description: switch (_tab) {
                  _BrigadeTab.catalog =>
                    'Попробуйте изменить поисковый запрос.',
                  _BrigadeTab.requests =>
                    'Создайте запрос, чтобы найти бригаду.',
                  _BrigadeTab.invitations =>
                    'Приглашения появятся после отправки бригаде.',
                },
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
                  subtitle: entry.subtitle ?? 'Открыть карточку',
                  icon: Icons.groups_outlined,
                  onTap:
                      _tab == _BrigadeTab.catalog
                          ? () => _openBrigade(entry)
                          : _tab == _BrigadeTab.requests
                          ? () => _openResponses(entry)
                          : null,
                  trailing:
                      _tab != _BrigadeTab.invitations
                          ? null
                          : Icon(
                            Icons.info_outline_rounded,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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

  String get _path => switch (_tab) {
    _BrigadeTab.catalog => '/team-expansion/brigades',
    _BrigadeTab.requests => '/team-expansion/brigade-requests',
    _BrigadeTab.invitations => '/team-expansion/brigade-invitations',
  };

  Future<void> _load() async {
    final version = ++_version;
    final permission = switch (_tab) {
      _BrigadeTab.catalog => 'brigades.catalog.view',
      _BrigadeTab.requests => 'brigades.requests.view',
      _BrigadeTab.invitations => 'brigades.invitations.view',
    };
    if (!ref.read(permissionServiceProvider).hasPermission(permission)) {
      setState(() {
        _page = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _page = null;
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final page = await ref
          .read(teamExpansionRepositoryProvider)
          .fetchPage(
            path: _path,
            filters: {
              if (_tab == _BrigadeTab.catalog && _query != null)
                'search': _query,
              if (_tab != _BrigadeTab.catalog && _projectId != null)
                'project_id': _projectId,
            },
          );
      if (!mounted || version != _version) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() {
        _error = UserMessage.fromError(error);
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
          .read(teamExpansionRepositoryProvider)
          .fetchPage(
            path: _path,
            filters: {
              if (_tab == _BrigadeTab.catalog && _query != null)
                'search': _query,
              if (_tab != _BrigadeTab.catalog && _projectId != null)
                'project_id': _projectId,
            },
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

  Future<void> _openBrigade(FieldCatalogEntry entry) async {
    final permissions = ref.read(permissionServiceProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => FieldCatalogDetailScreen(
              title: 'Бригада',
              catalog: 'brigades',
              apiPrefix: '/team-expansion/brigades',
              uuid: entry.uuid,
              icon: Icons.groups_outlined,
              actionBuilder:
                  permissions.hasPermission('brigades.invitations.create')
                      ? (context, detail, projectId) =>
                          _BrigadeInvitationAction(brigade: detail)
                      : null,
            ),
      ),
    );
  }

  Future<void> _openResponses(FieldCatalogEntry request) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => BrigadeResponsesScreen(
              requestId: request.uuid,
              requestTitle: request.title,
            ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _createRequest(int? projectId) async {
    if (!ref
        .read(permissionServiceProvider)
        .hasPermission('brigades.requests.create')) {
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BrigadeRequestFormScreen(projectId: projectId),
      ),
    );
    if (created == true) _load();
  }
}

class BrigadeResponsesScreen extends ConsumerStatefulWidget {
  const BrigadeResponsesScreen({
    super.key,
    required this.requestId,
    required this.requestTitle,
  });

  final String requestId;
  final String requestTitle;

  @override
  ConsumerState<BrigadeResponsesScreen> createState() =>
      _BrigadeResponsesScreenState();
}

class _BrigadeResponsesScreenState
    extends ConsumerState<BrigadeResponsesScreen> {
  FieldCatalogPage? _page;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionServiceProvider);
    final canView = permissions.hasPermission('brigades.responses.view');
    final canApprove = permissions.hasPermission('brigades.responses.approve');
    return Scaffold(
      appBar: AppBar(title: const Text('Отклики бригад')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(widget.requestTitle),
                subtitle: Text('Запрос №${widget.requestId}'),
              ),
            ),
            if (!canView)
              const AppPermissionState(
                title: 'Отклики недоступны',
                description: 'У вас нет права просматривать отклики.',
              )
            else if (_loading && _page == null)
              const AppLoadingState(message: 'Загружаем отклики')
            else if (_error != null && _page == null)
              AppErrorState(
                title: 'Не удалось загрузить отклики',
                description: _error,
                onRetry: _load,
              )
            else if (_page?.items.isEmpty ?? true)
              const AppEmptyState(
                icon: Icons.mark_email_read_outlined,
                title: 'Откликов пока нет',
                description: 'Ответы бригад появятся здесь.',
              )
            else ...[
              for (final response in _page!.items) ...[
                ProRecordCard(
                  title: _brigadeName(response),
                  subtitle: [
                    if (response.fields['status'] != null)
                      response.fields['status'].toString(),
                    if (response.fields['cover_message'] != null)
                      response.fields['cover_message'].toString(),
                  ].join(' · '),
                  icon: Icons.groups_outlined,
                  trailing:
                      response.fields['status'] == 'pending'
                          ? FilledButton.tonal(
                            onPressed:
                                canApprove ? () => _approve(response) : null,
                            child: const Text('Принять'),
                          )
                          : const Icon(Icons.check_circle_outline_rounded),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _brigadeName(FieldCatalogEntry response) {
    final brigade = response.fields['brigade'];
    if (brigade is Map) return (brigade['name'] ?? 'Бригада').toString();
    return 'Бригада ${response.fields['brigade_id'] ?? ''}'.trim();
  }

  Future<void> _load() async {
    if (!ref
        .read(permissionServiceProvider)
        .hasPermission('brigades.responses.view')) {
      setState(() {
        _page = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(teamExpansionRepositoryProvider)
          .fetchPage(
            path:
                '/team-expansion/brigade-requests/${widget.requestId}/responses',
            filters: const {'status': 'pending'},
          );
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = UserMessage.fromError(error);
        _loading = false;
      });
    }
  }

  Future<void> _approve(FieldCatalogEntry response) async {
    if (!ref
        .read(permissionServiceProvider)
        .hasPermission('brigades.responses.approve')) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Принять отклик?'),
            content: const Text(
              'Бригада будет назначена на объект по этому запросу.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Принять'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(teamExpansionRepositoryProvider)
          .action(
            path:
                '/team-expansion/brigade-requests/${widget.requestId}/responses/${response.uuid}/approve',
            payload: const {},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отклик принят, бригада назначена')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
    }
  }
}

class BrigadeRequestFormScreen extends ConsumerStatefulWidget {
  const BrigadeRequestFormScreen({super.key, this.projectId});

  final int? projectId;

  @override
  ConsumerState<BrigadeRequestFormScreen> createState() =>
      _BrigadeRequestFormScreenState();
}

class _BrigadeRequestFormScreenState
    extends ConsumerState<BrigadeRequestFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _specialization = TextEditingController();
  final _city = TextEditingController();
  final _teamSize = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _specialization.dispose();
    _city.dispose();
    _teamSize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Запрос бригады')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.projectId == null)
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Запрос будет создан без привязки к объекту.'),
          ),
        _input(_title, 'Название работ'),
        const SizedBox(height: 12),
        _input(_description, 'Описание', minLines: 4),
        const SizedBox(height: 12),
        _input(_specialization, 'Специализация (необязательно)'),
        const SizedBox(height: 12),
        _input(_city, 'Город (необязательно)'),
        const SizedBox(height: 12),
        _input(
          _teamSize,
          'Минимальный размер бригады',
          keyboardType: TextInputType.number,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon:
              _saving
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.send_rounded),
          label: Text(_saving ? 'Создаём запрос' : 'Опубликовать запрос'),
        ),
      ],
    ),
  );

  Widget _input(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    minLines: minLines,
    maxLines: minLines == 1 ? 1 : 8,
    keyboardType: keyboardType,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  Future<void> _submit() async {
    if (!ref
        .read(permissionServiceProvider)
        .hasPermission('brigades.requests.create')) {
      return;
    }
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'Заполните название и описание работ.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(teamExpansionRepositoryProvider)
          .create(
            path: '/team-expansion/brigade-requests',
            payload: {
              if (widget.projectId != null) 'project_id': widget.projectId,
              'title': _title.text.trim(),
              'description': _description.text.trim(),
              if (_specialization.text.trim().isNotEmpty)
                'specialization_name': _specialization.text.trim(),
              if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
              if (int.tryParse(_teamSize.text.trim()) case final int size
                  when size > 0)
                'team_size_min': size,
            },
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

class _BrigadeInvitationAction extends ConsumerWidget {
  const _BrigadeInvitationAction({required this.brigade});

  final FieldCatalogEntry brigade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(
      projectsProvider.select((state) => state.selectedProject),
    );
    final permission = ref
        .watch(permissionServiceProvider)
        .hasPermission('brigades.invitations.create');
    if (!permission) return const SizedBox.shrink();
    if (project == null) {
      return const ListTile(
        leading: Icon(Icons.info_outline_rounded),
        title: Text('Выберите объект, чтобы пригласить бригаду'),
      );
    }
    return FilledButton.icon(
      onPressed:
          () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder:
                  (_) => BrigadeInvitationFormScreen(
                    brigade: brigade,
                    projectId: project.serverId,
                    projectName: project.name,
                  ),
            ),
          ),
      icon: const Icon(Icons.mail_outline_rounded),
      label: const Text('Пригласить на объект'),
    );
  }
}

class BrigadeInvitationFormScreen extends ConsumerStatefulWidget {
  const BrigadeInvitationFormScreen({
    super.key,
    required this.brigade,
    required this.projectId,
    required this.projectName,
  });

  final FieldCatalogEntry brigade;
  final int projectId;
  final String projectName;

  @override
  ConsumerState<BrigadeInvitationFormScreen> createState() =>
      _BrigadeInvitationFormScreenState();
}

class _BrigadeInvitationFormScreenState
    extends ConsumerState<BrigadeInvitationFormScreen> {
  final _message = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Приглашение бригаде')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: Text(widget.projectName),
            subtitle: Text(widget.brigade.title),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Сообщение (необязательно)',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon:
              _saving
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.send_rounded),
          label: Text(_saving ? 'Отправляем' : 'Отправить приглашение'),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!ref
        .read(permissionServiceProvider)
        .hasPermission('brigades.invitations.create')) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(teamExpansionRepositoryProvider)
          .create(
            path: '/team-expansion/brigade-invitations',
            payload: {
              'brigade_id': int.tryParse(widget.brigade.uuid),
              'project_id': widget.projectId,
              if (_message.text.trim().isNotEmpty)
                'message': _message.text.trim(),
            },
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
