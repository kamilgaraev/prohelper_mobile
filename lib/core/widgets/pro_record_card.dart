import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class ProRecordCard extends StatelessWidget {
  const ProRecordCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.tone = ProStatusTone.info,
    this.meta,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final ProStatusTone tone;
  final String? meta;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, tone);
    final theme = Theme.of(context);

    return ProSurface(
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
            child: Icon(icon, color: status.foreground, size: 22),
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
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: ProSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (meta != null) ...[
                  const SizedBox(height: ProSpacing.xs),
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(context).copyWith(
                      color: status.foreground,
                      fontWeight: FontWeight.w700,
                    ),
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
