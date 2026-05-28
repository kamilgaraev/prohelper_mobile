import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class ProActionTile extends StatelessWidget {
  const ProActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.tone = ProStatusTone.info,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final IconData icon;
  final VoidCallback? onTap;
  final ProStatusTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, tone);
    final theme = Theme.of(context);

    return ProSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(ProSpacing.sm),
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
                      _ProActionBadge(label: badge!, color: status.foreground),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: ProSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: ProSpacing.xs),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ],
      ),
    );
  }
}

class _ProActionBadge extends StatelessWidget {
  const _ProActionBadge({required this.label, required this.color});

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
