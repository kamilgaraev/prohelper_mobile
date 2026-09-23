import 'dart:async';

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
  int? _loadedProjectId;
  int _version = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _showAvailable = false;
  final Set<int> _binding = {};

  @override
  void initState() {
    super.initState();
    _loadedProjectId = ref.read(projectsProvider).selectedProject?.serverId;
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
    final project = ref.watch(
      projectsProvider.select((state) => state.selectedProject),
    );
    final projectId = project?.serverId;
    if (projectId != _loadedProjectId) {
      _loadedProjectId = projectId;
      Future.microtask(_load);
    }
    final canView = ref
        .watch(permissionServiceProvider)
        .hasPermission('projects.view');
    final canAssign = ref
        .watch(permissionServiceProvider)
        .hasPermission('projects.participants.assign');

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
              if (_loading && _page == null)
                const AppLoadingState(message: 'Загружаем состав объекта')
              else if (_error != null && _page == null)
                AppErrorState(
                  title: 'Не удалось загрузить участников',
                  description: _error,
                  onRetry: _load,
                )
              else if (_page?.items.isEmpty ?? true)
                const AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Пользователи не найдены',
                  description: 'Измените запрос или обновите список.',
                )
              else ...[
                Text(
                  'Показано ${_page!.items.length} из ${_page!.total}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final participant in _page!.items) ...[
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
    final version = ++_version;
    final permissions = ref.read(permissionServiceProvider);
    final allowed =
        _showAvailable
            ? permissions.hasPermission('projects.participants.assign')
            : permissions.hasPermission('projects.view');
    if (projectId == null || !allowed) {
      setState(() {
        _page = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadingMore = false;
      _page = null;
      _error = null;
    });
    try {
      final page = await ref
          .read(projectParticipantsRepositoryProvider)
          .fetchPage(
            projectId: projectId,
            query: _query,
            availableUsers: _showAvailable,
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
    final page = _page;
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    final permissions = ref.read(permissionServiceProvider);
    final allowed =
        _showAvailable
            ? permissions.hasPermission('projects.participants.assign')
            : permissions.hasPermission('projects.view');
    if (page == null || projectId == null || _loadingMore || !allowed) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final next = await ref
          .read(projectParticipantsRepositoryProvider)
          .fetchPage(
            projectId: projectId,
            query: _query,
            availableUsers: _showAvailable,
            page: page.currentPage + 1,
          );
      if (!mounted || projectId != _loadedProjectId || page != _page) return;
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
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = UserMessage.fromError(error);
      });
    }
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
