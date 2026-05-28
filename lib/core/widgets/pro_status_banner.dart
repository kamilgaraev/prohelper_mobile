import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class ProStatusBanner extends StatelessWidget {
  const ProStatusBanner({
    super.key,
    required this.title,
    this.description,
    this.tone = ProStatusTone.info,
    this.action,
  });

  final String title;
  final String? description;
  final ProStatusTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, tone);

    return ProSurface(
      tone: ProSurfaceTone.subtle,
      borderRadius: ProRadius.sm,
      bordered: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status.background,
              borderRadius: BorderRadius.circular(ProRadius.sm),
              border: Border.all(color: status.border),
            ),
            child: Icon(status.icon, color: status.foreground, size: 21),
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
                if (description != null) ...[
                  const SizedBox(height: ProSpacing.xxs),
                  Text(
                    description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: ProSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
