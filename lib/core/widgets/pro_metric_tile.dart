import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class ProMetricTile extends StatelessWidget {
  const ProMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return ProSurface(
      padding: const EdgeInsets.all(ProSpacing.sm),
      tone: ProSurfaceTone.subtle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth >= 180;
          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.h2(context).copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: ProSpacing.xxs),
              Text(label, style: AppTypography.caption(context)),
            ],
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: accent, size: 20),
                  const SizedBox(width: ProSpacing.sm),
                ],
                Expanded(child: textContent),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: 20),
                const SizedBox(height: ProSpacing.sm),
              ],
              textContent,
            ],
          );
        },
      ),
    );
  }
}
