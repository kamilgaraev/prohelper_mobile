import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';

class ProBottomSheet extends StatelessWidget {
  const ProBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.actions,
  });

  final String title;
  final String? description;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: ProSpacing.md,
          right: ProSpacing.md,
          top: ProSpacing.sm,
          bottom: MediaQuery.viewInsetsOf(context).bottom + ProSpacing.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(ProRadius.sheet),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ProSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.22,
                      ),
                      borderRadius: BorderRadius.circular(ProRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: ProSpacing.md),
                Text(title, style: AppTypography.h2(context)),
                if (description != null) ...[
                  const SizedBox(height: ProSpacing.xs),
                  Text(description!, style: AppTypography.bodyMedium(context)),
                ],
                const SizedBox(height: ProSpacing.md),
                Flexible(child: SingleChildScrollView(child: child)),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: ProSpacing.md),
                  Row(
                    children: [
                      for (final action in actions!) ...[
                        Expanded(child: action),
                        if (action != actions!.last)
                          const SizedBox(width: ProSpacing.sm),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
