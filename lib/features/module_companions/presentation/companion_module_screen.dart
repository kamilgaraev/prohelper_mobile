import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/user_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/companion_module_model.dart';
import '../domain/companion_module_provider.dart';

class CompanionModuleScreen extends ConsumerStatefulWidget {
  const CompanionModuleScreen({
    super.key,
    required this.moduleSlug,
    required this.title,
    required this.icon,
    this.requiresProject = false,
  });

  final String moduleSlug;
  final String title;
  final IconData icon;
  final bool requiresProject;

  @override
  ConsumerState<CompanionModuleScreen> createState() =>
      _CompanionModuleScreenState();
}

class _CompanionModuleScreenState extends ConsumerState<CompanionModuleScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final projectId = ref.read(projectsProvider).selectedProject?.serverId;
      final notifier = ref.read(
        companionModuleProvider(widget.moduleSlug).notifier,
      );
      notifier.syncProject(projectId);
      if (projectId != null || !widget.requiresProject) {
        notifier.load();
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = companionModuleProvider(widget.moduleSlug);
    final state = ref.watch(provider);
    final selectedProjectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );

    if (state.projectId != selectedProjectId) {
      Future.microtask(() {
        final notifier = ref.read(provider.notifier);
        notifier.syncProject(selectedProjectId);
        if (selectedProjectId != null || !widget.requiresProject) {
          notifier.load();
        }
      });
    }

    final projectChanged = state.projectId != selectedProjectId;
    final list = projectChanged ? null : state.list;
    final title = list?.module.title ?? widget.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Обновить список',
            onPressed:
                state.isLoading ||
                        projectChanged ||
                        (widget.requiresProject && selectedProjectId == null)
                    ? null
                    : () => ref.read(provider.notifier).load(),
            icon: const Icon(
              Icons.refresh_rounded,
              semanticLabel: 'Обновить список',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (projectChanged ||
              (widget.requiresProject && selectedProjectId == null)) {
            return;
          }
          await ref.read(provider.notifier).load();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _HeaderCard(
              title: title,
              description: list?.module.description,
              icon: widget.icon,
            ),
            const SizedBox(height: 16),
            if (widget.requiresProject && selectedProjectId == null)
              const AppEmptyState(
                icon: Icons.domain_disabled_outlined,
                title: 'Выберите объект',
                description: 'Записи показываются для выбранного объекта.',
              )
            else ...[
              if (projectChanged)
                const AppLoadingState(message: 'Обновляем выбранный объект')
              else ...[
                _SearchAndFilters(
                  controller: _searchController,
                  statuses: list?.statuses ?? const [],
                  selectedStatus: state.status,
                  onSearchChanged: _scheduleSearch,
                  onStatusChanged:
                      (status) => ref.read(provider.notifier).setStatus(status),
                ),
                const SizedBox(height: 16),
                if (state.showingStaleList && list != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      state.listQuery != state.query ||
                              state.listStatus != state.status
                          ? 'Показан последний успешно загруженный список. Он может не учитывать текущие фильтры.'
                          : 'Не удалось обновить список. Показаны данные последней успешной загрузки.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (state.isLoading && list == null)
                  const AppLoadingState(message: 'Загружаем раздел')
                else if (state.permissionDenied)
                  AppPermissionState(
                    title: list?.permissionState.title ?? 'Раздел недоступен',
                    description:
                        list?.permissionState.description ??
                        'У вас нет прав на просмотр этого раздела.',
                  )
                else if (state.error != null && list == null)
                  AppErrorState(
                    title: 'Не удалось загрузить раздел',
                    description: state.error,
                    onRetry: () => ref.read(provider.notifier).load(),
                  )
                else if (list == null || list.items.isEmpty)
                  AppEmptyState(
                    icon: widget.icon,
                    title: list?.emptyState.title ?? 'Нет записей',
                    description: list?.emptyState.description,
                  )
                else ...[
                  if (list.meta.total > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Показано ${list.items.length} из ${list.meta.total}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  for (final item in list.items) ...[
                    _CompanionItemCard(
                      item: item,
                      onTap: () => _openDetail(context, item.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!state.showingStaleList &&
                      state.listQuery == state.query &&
                      state.listStatus == state.status &&
                      list.meta.currentPage < list.meta.lastPage)
                    OutlinedButton.icon(
                      onPressed:
                          state.isLoadingMore
                              ? null
                              : () => ref.read(provider.notifier).loadMore(),
                      icon:
                          state.isLoadingMore
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        state.isLoadingMore ? 'Загружаем' : 'Загрузить ещё',
                      ),
                    ),
                  if (state.error != null &&
                      list.items.isNotEmpty &&
                      !state.showingStaleList)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Не удалось загрузить следующую страницу: ${state.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _scheduleSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(companionModuleProvider(widget.moduleSlug).notifier)
          .setQuery(value);
    });
  }

  void _openDetail(BuildContext context, int id) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CompanionModuleDetailScreen(
              moduleSlug: widget.moduleSlug,
              title: widget.title,
              icon: widget.icon,
              itemId: id,
              requiresProject: widget.requiresProject,
              projectId: ref.read(projectsProvider).selectedProject?.serverId,
            ),
      ),
    );
  }
}

class CompanionModuleDetailScreen extends ConsumerStatefulWidget {
  const CompanionModuleDetailScreen({
    super.key,
    required this.moduleSlug,
    required this.title,
    required this.icon,
    required this.itemId,
    this.requiresProject = false,
    this.projectId,
  });

  final String moduleSlug;
  final String title;
  final IconData icon;
  final int itemId;
  final bool requiresProject;
  final int? projectId;

  @override
  ConsumerState<CompanionModuleDetailScreen> createState() =>
      _CompanionModuleDetailScreenState();
}

class _CompanionModuleDetailScreenState
    extends ConsumerState<CompanionModuleDetailScreen> {
  late Future<CompanionModuleDetailModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CompanionModuleDetailModel> _load() {
    return ref
        .read(companionModuleProvider(widget.moduleSlug).notifier)
        .fetchDetail(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = companionModuleProvider(widget.moduleSlug);
    final state = ref.watch(provider);
    final selectedProjectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    final projectMatches =
        !widget.requiresProject ||
        (selectedProjectId != null && widget.projectId == selectedProjectId);
    if (widget.requiresProject && state.projectId != selectedProjectId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(provider.notifier);
        notifier.syncProject(selectedProjectId);
        if (selectedProjectId != null) notifier.load();
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body:
          !projectMatches
              ? AppEmptyState(
                icon: Icons.domain_disabled_outlined,
                title:
                    selectedProjectId == null
                        ? 'Выберите объект'
                        : 'Объект изменился',
                description:
                    selectedProjectId == null
                        ? 'Вернитесь к списку после выбора объекта.'
                        : 'Вернитесь к списку и откройте запись выбранного объекта.',
              )
              : FutureBuilder<CompanionModuleDetailModel>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const AppLoadingState(message: 'Загружаем запись');
                  }

                  if (snapshot.hasError) {
                    return AppErrorState(
                      title: 'Не удалось загрузить запись',
                      description: UserMessage.fromError(snapshot.error!),
                      onRetry:
                          () => setState(() {
                            _future = _load();
                          }),
                    );
                  }

                  final detail = snapshot.requireData;

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _future = _load();
                      });
                      await _future;
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _CompanionDetailHeader(
                          item: detail.item,
                          icon: widget.icon,
                        ),
                        const SizedBox(height: 16),
                        if (detail.item.actions.isNotEmpty &&
                            projectMatches) ...[
                          _ActionPanel(
                            actions: detail.item.actions,
                            onAction: (action) => _runAction(action),
                          ),
                          const SizedBox(height: 16),
                        ],
                        for (final section in detail.sections) ...[
                          _SectionCard(section: section),
                          const SizedBox(height: 12),
                        ],
                        if (detail.result.isNotEmpty) ...[
                          _SectionCard(
                            section: CompanionSection(
                              title: 'Результат',
                              rows: detail.result,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (detail.files.isNotEmpty) ...[
                          _FilesCard(files: detail.files, onOpen: _openFile),
                          const SizedBox(height: 12),
                        ],
                        if (detail.comments.isNotEmpty) ...[
                          _CommentsCard(comments: detail.comments),
                          const SizedBox(height: 12),
                        ],
                        if (detail.workflowHistory.isNotEmpty) ...[
                          _HistoryCard(entries: detail.workflowHistory),
                          const SizedBox(height: 12),
                        ],
                        if (detail.relatedItems.isNotEmpty) ...[
                          _RelatedItemsCard(
                            items: detail.relatedItems,
                            title:
                                widget.moduleSlug == 'executive-documentation'
                                    ? 'Исполнительные документы'
                                    : 'Связанные записи',
                            onAction: _runRelatedAction,
                            showActions: projectMatches,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Future<void> _runAction(CompanionAction action) async {
    if (!_projectContextCurrent) return;
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder:
          (_) => _ActionBottomSheet(
            action: action,
            requiresComment: action.requiresComment,
            onExecute: (comment) async {
              if (!mounted || !_projectContextCurrent) return false;
              await ref
                  .read(companionModuleProvider(widget.moduleSlug).notifier)
                  .executeAction(
                    id: widget.itemId,
                    action: action.key,
                    comment: comment,
                  );
              return true;
            },
          ),
    );

    if (!mounted || completed != true || !_projectContextCurrent) return;
    setState(() {
      _future = _load();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Действие выполнено')));
  }

  Future<void> _runRelatedAction(
    CompanionRelatedItem item,
    CompanionAction action,
  ) async {
    if (widget.moduleSlug != 'executive-documentation' ||
        !_projectContextCurrent) {
      return;
    }
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder:
          (_) => _ActionBottomSheet(
            action: action,
            requiresComment: action.requiresComment,
            onExecute: (comment) async {
              if (!mounted || !_projectContextCurrent) return false;
              await ref
                  .read(companionModuleProvider(widget.moduleSlug).notifier)
                  .executeExecutiveDocumentAction(
                    documentId: item.id,
                    action: action.key,
                    comment: comment,
                  );
              return true;
            },
          ),
    );
    if (!mounted || completed != true || !_projectContextCurrent) return;
    setState(() {
      _future = _load();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Действие выполнено')));
  }

  Future<void> _openFile(CompanionFile file, String purpose) async {
    if (!_projectContextCurrent) return;
    final uri = file.uriFor(purpose);
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('companion_file_open_failed');
      }
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    }
  }

  bool get _projectContextCurrent {
    if (!widget.requiresProject) return true;
    final selectedProjectId =
        ref.read(projectsProvider).selectedProject?.serverId;
    return selectedProjectId != null && selectedProjectId == widget.projectId;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String? description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact =
        MediaQuery.sizeOf(context).width < 400 &&
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.h2(context).copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );

    return IndustrialCard(
      child:
          compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBadge(icon: icon, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  content,
                ],
              )
              : Row(
                children: [
                  _IconBadge(icon: icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 14),
                  Expanded(child: content),
                ],
              ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.statuses,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final List<CompanionStatusFilter> statuses;
  final String? selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          key: const Key('companion-search'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Поиск',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
          ),
          onChanged: onSearchChanged,
        ),
        if (statuses.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Все'),
                  selected: selectedStatus == null,
                  onSelected: (_) => onStatusChanged(null),
                ),
                const SizedBox(width: 8),
                for (final status in statuses) ...[
                  FilterChip(
                    label: Text(status.label),
                    selected: selectedStatus == status.value,
                    onSelected: (_) => onStatusChanged(status.value),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CompanionItemCard extends StatelessWidget {
  const _CompanionItemCard({required this.item, required this.onTap});

  final CompanionListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(context, item.statusTone);
    final compact = MediaQuery.sizeOf(context).width < 400;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: AppTypography.bodyLarge(context).copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (item.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            item.subtitle!,
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );

    return IndustrialCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (item.statusLabel != null) ...[
                  const SizedBox(height: 8),
                  _StatusPill(
                    label: item.statusLabel!,
                    color: color,
                    maxWidth: MediaQuery.sizeOf(context).width - 64,
                    allowWrap: true,
                  ),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                if (item.statusLabel != null)
                  _StatusPill(label: item.statusLabel!, color: color),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: item.primaryLabel,
                  value: item.primaryValue,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBlock(
                  label: item.secondaryLabel,
                  value: item.secondaryValue,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompanionDetailHeader extends StatelessWidget {
  const _CompanionDetailHeader({required this.item, required this.icon});

  final CompanionListItem item;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(context, item.statusTone);

    return IndustrialCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.h2(context).copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle!,
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (item.statusLabel != null) ...[
                  const SizedBox(height: 10),
                  _StatusPill(label: item.statusLabel!, color: color),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.actions, required this.onAction});

  final List<CompanionAction> actions;
  final ValueChanged<CompanionAction> onAction;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        children: [
          for (final action in actions) ...[
            AppPrimaryActionButton(
              label: action.title,
              leading: const Icon(Icons.play_arrow_rounded, size: 20),
              onPressed: () => onAction(action),
            ),
            if (action != actions.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final CompanionSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: AppTypography.bodyLarge(context).copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in section.rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: AppTypography.caption(
                      context,
                    ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.displayValue ?? row.value,
                    textAlign: TextAlign.right,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (row != section.rows.last) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _RelatedItemsCard extends StatelessWidget {
  const _RelatedItemsCard({
    required this.items,
    required this.title,
    required this.onAction,
    required this.showActions,
  });

  final List<CompanionRelatedItem> items;
  final String title;
  final void Function(CompanionRelatedItem, CompanionAction) onAction;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge(context).copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.title ?? item.id.toString()),
              subtitle: item.subtitle == null ? null : Text(item.subtitle!),
              trailing:
                  item.statusLabel == null
                      ? null
                      : _StatusPill(
                        label: item.statusLabel!,
                        color: theme.colorScheme.primary,
                      ),
            ),
            if (showActions && item.actions.isNotEmpty)
              _ActionPanel(
                actions: item.actions,
                onAction: (action) => onAction(item, action),
              ),
            if (item != items.last) const Divider(height: 8),
          ],
        ],
      ),
    );
  }
}

class _FilesCard extends StatelessWidget {
  const _FilesCard({required this.files, required this.onOpen});

  final List<CompanionFile> files;
  final Future<void> Function(CompanionFile, String) onOpen;

  @override
  Widget build(BuildContext context) => IndustrialCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Файлы',
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final file in files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(file.name),
            subtitle: file.mimeType == null ? null : Text(file.mimeType!),
            trailing: Wrap(
              children: [
                if (file.uriFor('preview') != null)
                  IconButton(
                    tooltip: 'Просмотреть',
                    onPressed: () => onOpen(file, 'preview'),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                if (file.uriFor('download') != null)
                  IconButton(
                    tooltip: 'Скачать',
                    onPressed: () => onOpen(file, 'download'),
                    icon: const Icon(Icons.download_outlined),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({required this.comments});

  final List<CompanionComment> comments;

  @override
  Widget build(BuildContext context) => IndustrialCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Комментарии',
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final comment in comments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(comment.author),
            subtitle: Text(
              [
                comment.body,
                if (comment.status != null)
                  comment.statusLabel ?? comment.status!,
                if (comment.createdAt != null) _formatDate(comment.createdAt!),
              ].join('\n'),
            ),
          ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entries});

  final List<CompanionHistoryEntry> entries;

  @override
  Widget build(BuildContext context) => IndustrialCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'История',
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.title),
            subtitle: Text(
              [
                if (entry.description != null) entry.description!,
                if (entry.createdAt != null) _formatDate(entry.createdAt!),
              ].join('\n'),
            ),
          ),
      ],
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = _formatMetricValue(label, value);

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            displayValue ?? 'Нет данных',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium(context).copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.maxWidth,
    this.allowWrap = false,
  });

  final String label;
  final Color color;
  final double? maxWidth;
  final bool allowWrap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          maxWidth == null ? null : BoxConstraints(maxWidth: maxWidth!),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: allowWrap ? null : 1,
        overflow: allowWrap ? TextOverflow.visible : TextOverflow.ellipsis,
        style: AppTypography.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _ActionBottomSheet extends StatefulWidget {
  const _ActionBottomSheet({
    required this.action,
    required this.requiresComment,
    required this.onExecute,
  });

  final CompanionAction action;
  final bool requiresComment;
  final Future<bool> Function(String? comment) onExecute;

  @override
  State<_ActionBottomSheet> createState() => _ActionBottomSheetState();
}

class _ActionBottomSheetState extends State<_ActionBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  bool _isComplete = false;
  bool _allowPopAfterAcknowledgement = false;
  String? _error;
  String? _commentError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return PopScope<bool>(
      canPop: (!_isSubmitting && !_isComplete) || _allowPopAfterAcknowledgement,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.action.title,
                    style: AppTypography.h2(context).copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('companion-action-comment'),
                    controller: _controller,
                    enabled: !_isSubmitting && !_isComplete,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) {
                      if (_commentError != null) {
                        setState(() => _commentError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText:
                          widget.requiresComment
                              ? 'Комментарий'
                              : 'Комментарий (необязательно)',
                      errorText: _commentError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('companion-action-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (_isComplete) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Действие выполнено.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppPrimaryActionButton(
                    label:
                        _isComplete
                            ? 'Готово'
                            : _error == null
                            ? 'Выполнить'
                            : 'Повторить',
                    onPressed:
                        _isSubmitting
                            ? null
                            : _isComplete
                            ? _acknowledge
                            : _execute,
                    isBusy: _isSubmitting,
                    busyLabel: 'Выполняем',
                  ),
                  TextButton(
                    onPressed:
                        _isSubmitting || _isComplete
                            ? null
                            : () => Navigator.of(context).pop(false),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _execute() async {
    if (_isSubmitting || _isComplete) return;

    final comment = _controller.text.trim();
    if (widget.requiresComment && comment.isEmpty) {
      setState(() => _commentError = 'Укажите комментарий к действию.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _commentError = null;
    });

    try {
      final completed = await widget.onExecute(
        comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isComplete = completed;
        _error =
            completed
                ? null
                : 'Объект изменился. Закройте окно и откройте запись снова.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = UserMessage.fromError(error);
      });
    }
  }

  void _acknowledge() {
    setState(() => _allowPopAfterAcknowledgement = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }
}

Color _toneColor(BuildContext context, String? tone) {
  return switch (tone) {
    'success' => AppColors.success,
    'warning' => AppColors.warning,
    'critical' => AppColors.error,
    _ => Theme.of(context).colorScheme.primary,
  };
}

final NumberFormat _ruAmountFormatter =
    NumberFormat.decimalPattern('ru_RU')
      ..minimumFractionDigits = 2
      ..maximumFractionDigits = 2;

String? _formatMetricValue(String label, String? value) {
  if (value == null) {
    return null;
  }

  if (!_isAmountLabel(label)) {
    return value;
  }

  final normalizedValue = value.trim();

  if (!_looksLikeDecimalAmount(normalizedValue)) {
    return value;
  }

  final parsed = double.tryParse(
    normalizedValue.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.'),
  );

  if (parsed == null) {
    return value;
  }

  return _ruAmountFormatter.format(parsed);
}

bool _isAmountLabel(String label) {
  final normalized = label.toLowerCase().replaceAll('ё', 'е');

  return normalized.contains('сумм') ||
      normalized.contains('стоим') ||
      normalized.contains('цена') ||
      normalized.contains('бюджет');
}

bool _looksLikeDecimalAmount(String value) {
  return RegExp(r'^[+-]?\d[\d\s]*[,.]\d{1,2}$').hasMatch(value);
}
