import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_layout.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.minHeight = 260,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppStateLayout(
      icon: icon,
      title: title,
      description: description,
      action: action,
      minHeight: minHeight,
      iconColor: theme.colorScheme.onSurfaceVariant,
      titleStyle: AppTypography.h2(context),
    );
  }
}
