import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_visuals.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/industrial_card.dart';

class NavigationSectionHeader extends StatelessWidget {
  const NavigationSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.h2(context).copyWith(fontSize: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationProjectBanner extends StatelessWidget {
  const NavigationProjectBanner({
    super.key,
    required this.projectName,
    this.trailing,
  });

  final String? projectName;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.42,
      ),
      borderColor: theme.colorScheme.outline.withValues(alpha: 0.12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.domain_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Текущий объект', style: AppTypography.caption(context)),
                const SizedBox(height: 3),
                Text(
                  projectName ?? 'Объект не выбран',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class NavigationActionCard extends ConsumerWidget {
  const NavigationActionCard({
    super.key,
    required this.action,
    required this.onTap,
    this.compact = false,
    this.onTogglePinned,
    this.isPinned,
  });

  final MobileActionRecommendation action;
  final VoidCallback onTap;
  final bool compact;
  final VoidCallback? onTogglePinned;
  final bool? isPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final destination = action.destination;
    final groupVisual = NavigationGroupVisual.resolve(
      context,
      destination.group,
    );
    final sourceVisual = NavigationActionVisual.resolve(action.source);
    final actionId = destination.actionId;
    final bool resolvedPinned =
        isPinned ??
        ref.watch(
          mobilePinnedActionIdsProvider.select(
            (ids) => actionId != null && ids.contains(actionId),
          ),
        );

    return IndustrialCard(
      padding: EdgeInsets.all(compact ? 12 : 14),
      backgroundColor: theme.colorScheme.surface,
      borderColor: groupVisual.accent.withValues(alpha: 0.18),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: groupVisual.container,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              destination.icon,
              color: groupVisual.accent,
              size: compact ? 21 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        compact
                            ? destination.recommendedReason
                            : destination.shortTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      _ActionBadge(
                        icon: sourceVisual.icon,
                        label: sourceVisual.label,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  action.source == MobileActionSource.pinned
                      ? 'Закреплено'
                      : action.reason,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
          if (onTogglePinned != null && actionId != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: resolvedPinned ? 'Открепить' : 'Закрепить',
              visualDensity: VisualDensity.compact,
              onPressed: onTogglePinned,
              icon: Icon(
                resolvedPinned ? Icons.star_rounded : Icons.star_border_rounded,
                color:
                    resolvedPinned
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class NavigationGroupBlock extends StatelessWidget {
  const NavigationGroupBlock({
    super.key,
    required this.group,
    required this.children,
  });

  final MobileModuleGroup group;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final visual = NavigationGroupVisual.resolve(context, group);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.container,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(visual.icon, color: visual.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.label,
                      style: AppTypography.h2(context).copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      visual.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class NavigationModuleRow extends StatelessWidget {
  const NavigationModuleRow({
    super.key,
    required this.destination,
    required this.onTap,
  });

  final MobileModuleDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = NavigationGroupVisual.resolve(context, destination.group);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.container,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(destination.icon, color: visual.accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.shortTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(context),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationGroupDivider extends StatelessWidget {
  const NavigationGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 64,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
