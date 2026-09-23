import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/theme/pro_theme.dart';

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
  final brightness = Theme.of(context).brightness;
  final foreground = switch (tone) {
    ProStatusTone.neutral => MostTheme.statusNeutralColor(brightness),
    ProStatusTone.info => MostTheme.statusInfoColor(brightness),
    ProStatusTone.success => MostTheme.statusSuccessColor(brightness),
    ProStatusTone.warning => MostTheme.statusWarningColor(brightness),
    ProStatusTone.danger => MostTheme.statusDangerColor(brightness),
  };
  final icon = switch (tone) {
    ProStatusTone.neutral => Icons.info_outline_rounded,
    ProStatusTone.info => Icons.auto_awesome_rounded,
    ProStatusTone.success => Icons.check_circle_outline_rounded,
    ProStatusTone.warning => Icons.warning_amber_rounded,
    ProStatusTone.danger => Icons.error_outline_rounded,
  };

  return ProStatusStyle(
    foreground: foreground,
    background: foreground.withValues(alpha: 0.1),
    border: foreground.withValues(alpha: 0.22),
    icon: icon,
  );
}
