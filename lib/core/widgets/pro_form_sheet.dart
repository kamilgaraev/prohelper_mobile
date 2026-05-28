import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';

class ProFormSheet extends StatelessWidget {
  const ProFormSheet({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          ProSpacing.pageHorizontal,
          ProSpacing.lg,
          ProSpacing.pageHorizontal,
          MediaQuery.viewInsetsOf(context).bottom + ProSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(ProRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: ProSpacing.lg),
            Text(title, style: AppTypography.h2(context)),
            if (subtitle != null) ...[
              const SizedBox(height: ProSpacing.xxs),
              Text(subtitle!, style: AppTypography.caption(context)),
            ],
            const SizedBox(height: ProSpacing.md),
            ...children,
            if (actions != null) ...[
              const SizedBox(height: ProSpacing.lg),
              ...actions!,
            ],
          ],
        ),
      ),
    );
  }
}
