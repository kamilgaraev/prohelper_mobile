import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_empty_state.dart';
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
  });

  final String moduleSlug;
  final String title;
  final IconData icon;

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
      notifier.load();
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
        notifier.load();
      });
    }

    final list = state.list;
    final title = list?.module.title ?? widget.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed:
                state.isLoading
                    ? null
                    : () => ref.read(provider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(provider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _HeaderCard(
              title: title,
              description: list?.module.description,
              icon: widget.icon,
            ),
            const SizedBox(height: 16),
            _SearchAndFilters(
              controller: _searchController,
              statuses: list?.statuses ?? const [],
              selectedStatus: state.status,
              onSearchChanged: _scheduleSearch,
              onStatusChanged:
                  (status) => ref.read(provider.notifier).setStatus(status),
            ),
            const SizedBox(height: 16),
            if (state.isLoading && list == null)
              const AppLoadingState(message: 'Загружаем раздел')
            else if (state.permissionDenied)
              AppPermissionState(
                title: list?.permissionState.title ?? 'Раздел недоступен',
                description:
                    list?.permissionState.description ??
                    'У вашей роли нет доступа к этому разделу.',
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
              for (final item in list.items) ...[
                _CompanionItemCard(
                  item: item,
                  onTap: () => _openDetail(context, item.id),
                ),
                const SizedBox(height: 12),
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
  });

  final String moduleSlug;
  final String title;
  final IconData icon;
  final int itemId;

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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<CompanionModuleDetailModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState(message: 'Загружаем запись');
          }

          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Не удалось загрузить запись',
              description: snapshot.error.toString(),
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
                _CompanionDetailHeader(item: detail.item, icon: widget.icon),
                const SizedBox(height: 16),
                if (detail.item.actions.isNotEmpty) ...[
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
                if (detail.relatedItems.isNotEmpty) ...[
                  _RelatedItemsCard(items: detail.relatedItems),
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
    final comment = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _ActionBottomSheet(
            action: action,
            requiresComment: action.requiresComment,
          ),
    );

    if (!mounted) {
      return;
    }

    if (comment == null && action.requiresComment) {
      return;
    }

    try {
      await ref
          .read(companionModuleProvider(widget.moduleSlug).notifier)
          .executeAction(
            id: widget.itemId,
            action: action.key,
            comment: comment,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _future = _load();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Действие выполнено')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

    return IndustrialCard(
      child: Row(
        children: [
          _IconBadge(icon: icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
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
            ),
          ),
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

    return IndustrialCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
                ),
              ),
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
                    row.value,
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
  const _RelatedItemsCard({required this.items});

  final List<CompanionRelatedItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Связанные записи',
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
            if (item != items.last) const Divider(height: 8),
          ],
        ],
      ),
    );
  }
}

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
            value ?? 'Нет данных',
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
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
  });

  final CompanionAction action;
  final bool requiresComment;

  @override
  State<_ActionBottomSheet> createState() => _ActionBottomSheetState();
}

class _ActionBottomSheetState extends State<_ActionBottomSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText:
                    widget.requiresComment ? 'Комментарий' : 'Комментарий',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppPrimaryActionButton(
              label: 'Выполнить',
              onPressed: () {
                final text = _controller.text.trim();
                if (widget.requiresComment && text.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(text);
              },
            ),
          ],
        ),
      ),
    );
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
