import 'package:flutter/material.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';

class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final Color? iconColor;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.h2(context),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
