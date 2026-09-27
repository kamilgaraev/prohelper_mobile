import 'package:flutter/material.dart';

import 'most_color_tokens.dart';

enum ProStatusTone { neutral, info, success, warning, danger }

class ProStatusStyle {
  const ProStatusStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });

  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
}

ProStatusStyle proStatusStyle(BuildContext context, ProStatusTone tone) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final tokens = isDark ? MostColorTokens.dark : MostColorTokens.light;
  final color = switch (tone) {
    ProStatusTone.neutral => scheme.onSurfaceVariant,
    ProStatusTone.info => tokens.info,
    ProStatusTone.success => tokens.success,
    ProStatusTone.warning => tokens.warning,
    ProStatusTone.danger => tokens.danger,
  };

  final icon = switch (tone) {
    ProStatusTone.neutral => Icons.info_outline_rounded,
    ProStatusTone.info => Icons.auto_awesome_rounded,
    ProStatusTone.success => Icons.check_circle_outline_rounded,
    ProStatusTone.warning => Icons.warning_amber_rounded,
    ProStatusTone.danger => Icons.error_outline_rounded,
  };

  return ProStatusStyle(
    foreground: color,
    background: color.withValues(alpha: 0.1),
    border: color.withValues(alpha: 0.22),
    icon: icon,
  );
}
