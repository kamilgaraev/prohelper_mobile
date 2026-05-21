import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_layout.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    this.description,
    this.onRetry,
    this.retryLabel = 'Повторить',
    this.minHeight = 260,
  });

  final String title;
  final String? description;
  final VoidCallback? onRetry;
  final String retryLabel;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppStateLayout(
      icon: Icons.error_outline_rounded,
      title: title,
      description: description,
      minHeight: minHeight,
      iconColor: theme.colorScheme.error,
      action:
          onRetry == null
              ? null
              : AppSecondaryActionButton(
                label: retryLabel,
                onPressed: onRetry,
                leading: const Icon(Icons.refresh_rounded),
                expanded: false,
              ),
    );
  }
}
