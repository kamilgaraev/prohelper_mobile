import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_search.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/logout_confirmation_dialog.dart';
import 'package:prohelpers_mobile/features/auth/presentation/widgets/user_profile_bottom_sheet.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_hub_screen.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';

class MobileMoreScreen extends ConsumerWidget {
  const MobileMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectsProvider).selectedProject;
    final authState = ref.watch(authProvider);
    final modules = ref.watch(supportedMobileModulesProvider);
    final hasSelectedProject = project != null;
    final managementDestinations = uniqueDestinations(
          modules.map(
            (module) =>
                MobileNavigationRegistry.destinationForRoute(module.route) ??
                MobileNavigationRegistry.destinationForRoute(module.slug),
          ),
        )
        .where(
          (destination) =>
              destination.group == MobileModuleGroup.management &&
              (!destination.requiresProject || hasSelectedProject),
        )
        .toList(growable: false);

    final user = authState is AuthAuthenticated ? authState.user : null;
    final projectTitle = project?.name ?? 'Объект не выбран';
    final projectDescription =
        project?.address ?? 'Выберите объект для рабочих разделов.';
    final projectSemanticLabel =
        project == null
            ? 'Выбрать текущий объект для рабочих разделов'
            : 'Сменить текущий объект: $projectTitle. Адрес: $projectDescription';

    return ProPageScaffold(
      title: 'Ещё',
      subtitle: 'Управление, справочники и профиль',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null) ...[
            ProSurface(
              semanticLabel: 'Открыть профиль: ${user.name}, ${user.email}',
              onTap: () => _showUserProfileBottomSheet(context, user),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text(_initials(user.name)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge(
                            context,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _MoreProjectContextCard(
            title: projectTitle,
            description: projectDescription,
            tone: project == null ? ProStatusTone.warning : ProStatusTone.info,
            actionLabel: project == null ? 'Выбрать' : 'Сменить',
            semanticLabel: projectSemanticLabel,
            onTap: () => _openProjectSelection(context),
          ),
          const SizedBox(height: 20),
          _MoreActionPanel(
            title: 'Помощь',
            subtitle:
                'Быстрый доступ к инструкциям по модулям и рабочим сценариям.',
            items: [
              _MoreActionItem(
                title: 'База знаний',
                subtitle: 'Статьи, вложенные разделы и поиск по инструкциям',
                icon: Icons.menu_book_outlined,
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const KnowledgeHubScreen(),
                      ),
                    ),
              ),
            ],
          ),
          if (managementDestinations.isNotEmpty) ...[
            const SizedBox(height: 20),
            _MoreActionPanel(
              title: 'Управление',
              subtitle: 'Вторичные разделы, настройки данных и контроль.',
              items: [
                for (final destination in managementDestinations)
                  _MoreActionItem(
                    title: destination.shortTitle,
                    subtitle:
                        destination.title == destination.shortTitle
                            ? destination.recommendedReason
                            : '${destination.title} · ${destination.recommendedReason}',
                    icon: destination.icon,
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: destination.builder)),
                  ),
              ],
            ),
          ],
          if (user != null) ...[
            const SizedBox(height: 20),
            _MoreActionPanel(
              title: 'Аккаунт',
              items: [
                _MoreActionItem(
                  title: 'Профиль',
                  subtitle: 'Данные пользователя и организации',
                  icon: Icons.person_outline_rounded,
                  onTap: () => _showUserProfileBottomSheet(context, user),
                ),
                _MoreActionItem(
                  title: 'Выйти',
                  subtitle: 'Завершить текущую сессию',
                  icon: Icons.logout_rounded,
                  tone: ProStatusTone.danger,
                  onTap: () async {
                    final confirmed = await showLogoutConfirmationDialog(
                      context,
                    );
                    if (!confirmed || !context.mounted) {
                      return;
                    }

                    await ref.read(authProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openProjectSelection(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProjectSelectionScreen()));
  }
}

class _MoreProjectContextCard extends StatelessWidget {
  const _MoreProjectContextCard({
    required this.title,
    required this.description,
    required this.tone,
    required this.actionLabel,
    required this.semanticLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final ProStatusTone tone;
  final String actionLabel;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, tone);
    final theme = Theme.of(context);

    return ProSurface(
      key: const ValueKey('more_project_context_surface'),
      tone: ProSurfaceTone.elevated,
      padding: const EdgeInsets.all(ProSpacing.sm),
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status.background,
              borderRadius: BorderRadius.circular(ProRadius.sm),
              border: Border.all(color: status.border),
            ),
            child: Icon(status.icon, color: status.foreground, size: 22),
          ),
          const SizedBox(width: ProSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800, height: 1.15),
                ),
                const SizedBox(height: ProSpacing.xxs),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ProSpacing.sm),
          _MoreProjectSwitchPill(label: actionLabel),
        ],
      ),
    );
  }
}

class _MoreProjectSwitchPill extends StatelessWidget {
  const _MoreProjectSwitchPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: ProTouchTarget.min),
      padding: const EdgeInsets.symmetric(
        horizontal: ProSpacing.sm,
        vertical: ProSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ProRadius.sm),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            color: theme.colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: ProSpacing.xxs),
          Text(
            label,
            style: AppTypography.bodyMedium(context).copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreActionItem {
  const _MoreActionItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.tone = ProStatusTone.info,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final ProStatusTone tone;
}

class _MoreActionPanel extends StatelessWidget {
  const _MoreActionPanel({
    required this.title,
    required this.items,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<_MoreActionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ProSpacing.md,
              ProSpacing.md,
              ProSpacing.md,
              0,
            ),
            child: ProSectionHeader(title: title, subtitle: subtitle),
          ),
          const ProSectionDivider(indent: ProSpacing.md),
          for (var index = 0; index < items.length; index++) ...[
            _MoreActionRow(item: items[index]),
            if (index != items.length - 1) const ProSectionDivider(indent: 72),
          ],
        ],
      ),
    );
  }
}

class _MoreActionRow extends StatelessWidget {
  const _MoreActionRow({required this.item});

  final _MoreActionItem item;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, item.tone);
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      button: true,
      enabled: item.onTap != null,
      child: InkWell(
        onTap:
            item.onTap == null
                ? null
                : () {
                  HapticFeedback.selectionClick();
                  item.onTap!();
                },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ProTouchTarget.min),
          child: Padding(
            padding: const EdgeInsets.all(ProSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(ProRadius.sm),
                  ),
                  child: Icon(item.icon, color: status.foreground, size: 22),
                ),
                const SizedBox(width: ProSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: ProSpacing.xxs),
                        Text(
                          item.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: ProSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showUserProfileBottomSheet(BuildContext context, User user) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierLabel: 'Закрыть профиль',
    builder: (_) => UserProfileBottomSheet(user: user),
  );
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) {
    return 'P';
  }

  return parts.take(2).map((part) => part.substring(0, 1)).join();
}
