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
    this.surfaceTone = ProSurfaceTone.subtle,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? description;
  final ProStatusTone tone;
  final ProSurfaceTone surfaceTone;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, tone);
    final iconExtent = compact ? 36.0 : 40.0;
    final iconSize = compact ? 19.0 : 21.0;

    return ProSurface(
      tone: surfaceTone,
      padding: EdgeInsets.all(compact ? ProSpacing.sm : ProSpacing.md),
      borderRadius: ProRadius.sm,
      bordered: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconExtent,
            height: iconExtent,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status.background,
              borderRadius: BorderRadius.circular(ProRadius.sm),
              border: Border.all(color: status.border),
            ),
            child: Icon(status.icon, color: status.foreground, size: iconSize),
          ),
          const SizedBox(width: ProSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact && action != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _StatusTitle(title: title, compact: true),
                      ),
                      const SizedBox(width: ProSpacing.xs),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: action!,
                        ),
                      ),
                    ],
                  )
                else
                  _StatusTitle(title: title, compact: compact),
                if (description != null) ...[
                  const SizedBox(height: ProSpacing.xxs),
                  Text(
                    description!,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (!compact && action != null) ...[
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

class _StatusTitle extends StatelessWidget {
  const _StatusTitle({required this.title, required this.compact});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyLarge(
        context,
      ).copyWith(fontWeight: FontWeight.w800, height: compact ? 1.12 : null),
    );
  }
}
