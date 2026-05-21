import 'package:flutter/material.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';

class AppStateLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final double minHeight;

  const AppStateLayout({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.iconColor,
    this.titleStyle,
    this.minHeight = 260,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.onSurfaceVariant;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight, maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: titleStyle ?? AppTypography.h2(context),
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: AppTypography.bodyMedium(
                    context,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
