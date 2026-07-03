import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class MobileRecommendedActionsSection extends StatelessWidget {
  const MobileRecommendedActionsSection({
    super.key,
    required this.actions,
    required this.onOpen,
    this.title = 'Рекомендуемые',
    this.subtitle = 'Самые полезные действия для текущей роли и объекта.',
  });

  final List<MobileActionRecommendation> actions;
  final ValueChanged<MobileActionRecommendation> onOpen;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final rows =
        actions.isEmpty
            ? const <_RecommendedActionRow>[
              _RecommendedActionRow(
                title: 'Рекомендации появятся после загрузки данных',
                subtitle: 'Пока можно открыть нужный раздел через поиск.',
                icon: Icons.auto_awesome_outlined,
              ),
            ]
            : [
              for (final action in actions.take(5))
                _RecommendedActionRow(
                  title: action.destination.shortTitle,
                  subtitle:
                      action.source == MobileActionSource.pinned
                          ? 'Закреплено'
                          : action.destination.title ==
                              action.destination.shortTitle
                          ? action.reason
                          : '${action.destination.title} · ${action.reason}',
                  badge:
                      action.source == MobileActionSource.pinned
                          ? 'Закреплено'
                          : null,
                  icon: action.destination.icon,
                  onTap: () => onOpen(action),
                ),
            ];

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
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1) const ProSectionDivider(indent: 72),
          ],
        ],
      ),
    );
  }
}

class _RecommendedActionRow extends StatelessWidget {
  const _RecommendedActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, ProStatusTone.info);
    final theme = Theme.of(context);
    final row = Padding(
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
            child: Icon(icon, color: status.foreground, size: 22),
          ),
          const SizedBox(width: ProSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: ProSpacing.xs),
                      _ActionBadge(label: badge!, color: status.foreground),
                    ],
                  ],
                ),
                const SizedBox(height: ProSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: ProSpacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            color:
                onTap == null
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.36)
                    : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(container: true, enabled: false, child: row);
    }

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ProSpacing.xs,
        vertical: ProSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ProRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
