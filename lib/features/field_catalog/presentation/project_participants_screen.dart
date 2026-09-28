import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/pro_record_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../../auth/data/auth_session_identity.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/project_participants_repository.dart';

class ProjectParticipantsScreen extends ConsumerStatefulWidget {
  const ProjectParticipantsScreen({super.key});

  @override
  ConsumerState<ProjectParticipantsScreen> createState() =>
      _ProjectParticipantsScreenState();
}

class _ProjectParticipantsScreenState
    extends ConsumerState<ProjectParticipantsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  ProjectParticipantsPage? _page;
  String? _query;
  String? _error;
  String? _staleError;
  int? _contextProjectId;
  int? _loadedProjectId;
  int _version = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _showAvailable = false;
  final Set<int> _binding = {};
  AuthSessionIdentity? _loadedIdentity;
  AuthSessionIdentity? _contextIdentity;
  bool? _loadedAvailableUsers;
  String? _loadedQuery;

  @override
  void initState() {
    super.initState();
    _contextProjectId = ref.read(projectsProvider).selectedProject?.serverId;
    final auth = ref.read(authProvider);
    _contextIdentity = auth is AuthAuthenticated ? auth.sessionIdentity : null;
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
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
    final project = ref.watch(
      projectsProvider.select((state) => state.selectedProject),
    );
    final projectId = project?.serverId;
    if (projectId != _contextProjectId) {
      _contextProjectId = projectId;
      Future.microtask(_load);
    }
    final canView = ref
        .watch(permissionServiceProvider)
        .hasPermission('projects.view');
    final canAssign = ref
        .watch(permissionServiceProvider)
        .hasPermission('projects.participants.assign');
    final hasMatchingOwner =
        identity != null &&
        identity == _loadedIdentity &&
        projectId == _loadedProjectId &&
        _showAvailable == _loadedAvailableUsers;
    final visiblePage = hasMatchingOwner ? _page : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Участники объекта'),
        actions: [
          IconButton(
            tooltip: 'Обновить список',
            onPressed: _loading || projectId == null ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (project != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment_rounded),
                  title: Text(project.name),
                  subtitle: const Text('Выбранный объект'),
                ),
              ),
            if (projectId == null)
              const AppEmptyState(
                icon: Icons.apartment_outlined,
                title: 'Выберите объект',
                description: 'Состав команды доступен для выбранного объекта.',
              )
            else if (!canView)
              const AppPermissionState(
                title: 'Раздел недоступен',
                description: 'У вас нет права просматривать состав объекта.',
              )
            else ...[
              SegmentedButton<bool>(
                segments: [
                  const ButtonSegment(value: false, label: Text('Состав')),
                  if (canAssign)
                    const ButtonSegment(value: true, label: Text('Добавить')),
                ],
                selected: {_showAvailable},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  final showAvailable = selection.first;
                  if (showAvailable && !canAssign) return;
                  setState(() {
                    _showAvailable = showAvailable;
                    _page = null;
                    _loadedIdentity = null;
                    _loadedProjectId = null;
                    _loadedAvailableUsers = null;
                    _loadedQuery = null;
                    _staleError = null;
                    _query = null;
                    _search.clear();
                  });
                  _load();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Имя или электронная почта',
                  suffixIcon:
                      _search.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Очистить поиск',
                            onPressed: () {
                              _debounce?.cancel();
                              _search.clear();
                              _query = null;
                              _load();
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                ),
                onChanged: (value) {
                  setState(() {});
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _query = value.trim().isEmpty ? null : value.trim();
                    _load();
                  });
                },
              ),
              const SizedBox(height: 14),
              if (_loading && visiblePage == null)
                const AppLoadingState(message: 'Загружаем состав объекта')
              else if (_error != null && visiblePage == null)
                AppErrorState(
                  title: 'Не удалось загрузить участников',
                  description: _error,
                  onRetry: _load,
                )
              else if (visiblePage?.items.isEmpty ?? true)
                const AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Пользователи не найдены',
                  description: 'Измените запрос или обновите список.',
                )
              else ...[
                if (_loadedQuery != _query || _staleError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _loadedQuery != _query
                          ? 'Показан последний успешно загруженный список. Он может не учитывать текущий поиск.'
                          : 'Не удалось обновить список. Показаны данные последней успешной загрузки.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Text(
                  'Показано ${visiblePage!.items.length} из ${visiblePage.total}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final participant in visiblePage.items) ...[
                  ProRecordCard(
                    title: participant.name,
                    subtitle: [
                      if (!_showAvailable) participant.projectRole,
                      participant.email,
                    ].where((value) => value.trim().isNotEmpty).join(' · '),
                    icon: Icons.person_outline_rounded,
                    trailing:
                        _showAvailable
                            ? participant.alreadyAssigned
                                ? const Chip(label: Text('Уже добавлен'))
                                : FilledButton.tonal(
                                  onPressed:
                                      !canAssign ||
                                              _binding.contains(participant.id)
                                          ? null
                                          : () => _bind(participant.id),
                                  child:
                                      _binding.contains(participant.id)
                                          ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text('Добавить'),
                                )
                            : null,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_loadedQuery == _query &&
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    final auth = ref.read(authProvider);
    final requestIdentity =
        auth is AuthAuthenticated ? auth.sessionIdentity : null;
    final requestQuery = _query;
    final requestAvailableUsers = _showAvailable;
    final version = ++_version;
    if (requestIdentity == null) {
      setState(() {
        _page = null;
        _loadedIdentity = null;
        _loadedProjectId = null;
        _loadedAvailableUsers = null;
        _loadedQuery = null;
        _loading = false;
        _loadingMore = false;
        _error = null;
        _staleError = null;
      });
      return;
    }
    final permissions = ref.read(permissionServiceProvider);
    final allowed =
        _showAvailable
            ? permissions.hasPermission('projects.participants.assign')
            : permissions.hasPermission('projects.view');
    if (projectId == null || !allowed) {
      setState(() {
        _page = null;
        _loadedIdentity = null;
        _loadedProjectId = null;
        _loadedAvailableUsers = null;
        _loadedQuery = null;
        _staleError = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    final sameOwner =
        _loadedIdentity == requestIdentity &&
        _loadedProjectId == projectId &&
        _loadedAvailableUsers == requestAvailableUsers;
    setState(() {
      _loading = true;
      _loadingMore = false;
      if (!sameOwner) {
        _page = null;
        _loadedIdentity = null;
        _loadedProjectId = null;
        _loadedAvailableUsers = null;
        _loadedQuery = null;
      }
      _error = null;
      _staleError = null;
    });
    try {
      final page = await ref
          .read(projectParticipantsRepositoryProvider)
          .fetchPage(
            projectId: projectId,
            query: requestQuery,
            availableUsers: requestAvailableUsers,
          );
      if (!mounted || version != _version) return;
      final currentAuth = ref.read(authProvider);
      if (currentAuth is! AuthAuthenticated ||
          currentAuth.sessionIdentity != requestIdentity ||
          ref.read(projectsProvider).selectedProject?.serverId != projectId ||
          _showAvailable != requestAvailableUsers) {
        return;
      }
      setState(() {
        _page = page;
        _loadedIdentity = requestIdentity;
        _loadedProjectId = projectId;
        _loadedAvailableUsers = requestAvailableUsers;
        _loadedQuery = requestQuery;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      final currentAuth = ref.read(authProvider);
      final requestOwnerStillCurrent =
          currentAuth is AuthAuthenticated &&
          currentAuth.sessionIdentity == requestIdentity &&
          ref.read(projectsProvider).selectedProject?.serverId == projectId &&
          _showAvailable == requestAvailableUsers;
      if (isSnapshotOffline(error) &&
          sameOwner &&
          requestOwnerStillCurrent &&
          _page != null) {
        setState(() {
          _staleError = UserMessage.fromError(error);
          _error = null;
          _loading = false;
        });
        return;
      }
      setState(() {
        _page = null;
        _loadedIdentity = null;
        _loadedProjectId = null;
        _loadedAvailableUsers = null;
        _loadedQuery = null;
        _error = UserMessage.fromError(error);
        _staleError = null;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final page = _page;
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    final auth = ref.read(authProvider);
    final requestIdentity =
        auth is AuthAuthenticated ? auth.sessionIdentity : null;
    final requestQuery = _query;
    final requestAvailableUsers = _showAvailable;
    final requestVersion = _version;
    final permissions = ref.read(permissionServiceProvider);
    final allowed =
        _showAvailable
            ? permissions.hasPermission('projects.participants.assign')
            : permissions.hasPermission('projects.view');
    if (page == null ||
        projectId == null ||
        _loadingMore ||
        !allowed ||
        requestIdentity == null ||
        _loadedIdentity != requestIdentity ||
        _loadedProjectId != projectId ||
        _loadedAvailableUsers != requestAvailableUsers ||
        _loadedQuery != requestQuery) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final next = await ref
          .read(projectParticipantsRepositoryProvider)
          .fetchPage(
            projectId: projectId,
            query: requestQuery,
            availableUsers: requestAvailableUsers,
            page: page.currentPage + 1,
          );
      if (!mounted ||
          requestVersion != _version ||
          projectId != ref.read(projectsProvider).selectedProject?.serverId ||
          projectId != _loadedProjectId ||
          page != _page ||
          _query != requestQuery ||
          _showAvailable != requestAvailableUsers ||
          ref.read(authProvider) is! AuthAuthenticated ||
          (ref.read(authProvider) as AuthAuthenticated).sessionIdentity !=
              requestIdentity) {
        return;
      }
      final ids = page.items.map((item) => item.id).toSet();
      setState(() {
        _page = ProjectParticipantsPage(
          items: [
            ...page.items,
            ...next.items.where((item) => ids.add(item.id)),
          ],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        );
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _version) return;
      final currentAuth = ref.read(authProvider);
      final ownerStillCurrent =
          currentAuth is AuthAuthenticated &&
          currentAuth.sessionIdentity == requestIdentity &&
          ref.read(projectsProvider).selectedProject?.serverId == projectId &&
          _query == requestQuery &&
          _showAvailable == requestAvailableUsers;
      if (!ownerStillCurrent) return;
      setState(() {
        _loadingMore = false;
        _error = UserMessage.fromError(error);
        if (!isSnapshotOffline(error)) {
          _page = null;
          _loadedIdentity = null;
          _loadedProjectId = null;
          _loadedAvailableUsers = null;
          _loadedQuery = null;
          _staleError = null;
        }
      });
    }
  }

  void _clearForMissingIdentity() {
    if (!mounted || ref.read(authProvider) is AuthAuthenticated) return;
    _version++;
    setState(() {
      _page = null;
      _loadedIdentity = null;
      _loadedProjectId = null;
      _loadedAvailableUsers = null;
      _loadedQuery = null;
      _loading = false;
      _loadingMore = false;
      _error = null;
      _staleError = null;
    });
  }

  Future<void> _bind(int userId) async {
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    if (projectId == null ||
        !ref
            .read(permissionServiceProvider)
            .hasPermission('projects.participants.assign')) {
      return;
    }
    setState(() => _binding.add(userId));
    try {
      await ref
          .read(projectParticipantsRepositoryProvider)
          .bind(projectId: projectId, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь добавлен на объект')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
    } finally {
      if (mounted) setState(() => _binding.remove(userId));
    }
  }
}
