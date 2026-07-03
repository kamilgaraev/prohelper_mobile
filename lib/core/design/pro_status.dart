import 'package:flutter/material.dart';

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

  final color = switch (tone) {
    ProStatusTone.neutral => scheme.onSurfaceVariant,
    ProStatusTone.info =>
      isDark ? const Color(0xFF5EB1FF) : const Color(0xFF0056B3),
    ProStatusTone.success =>
      isDark ? const Color(0xFF53D88A) : const Color(0xFF087A3B),
    ProStatusTone.warning =>
      isDark ? const Color(0xFFFFC15A) : const Color(0xFF8A5200),
    ProStatusTone.danger =>
      isDark ? const Color(0xFFFF746B) : const Color(0xFFB42318),
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
