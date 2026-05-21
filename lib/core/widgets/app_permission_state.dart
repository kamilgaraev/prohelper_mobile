import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/widgets/app_state_layout.dart';

class AppPermissionState extends StatelessWidget {
  const AppPermissionState({
    super.key,
    this.title = 'Раздел недоступен',
    this.description =
        'Для вашей роли нет доступа к этому действию. Обратитесь к администратору.',
    this.minHeight = 260,
  });

  final String title;
  final String description;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppStateLayout(
      icon: Icons.lock_outline_rounded,
      title: title,
      description: description,
      minHeight: minHeight,
      iconColor: theme.colorScheme.onSurfaceVariant,
    );
  }
}
