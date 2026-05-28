import 'package:flutter/material.dart';

import 'mobile_action_recommendation.dart';
import 'mobile_destination.dart';

class NavigationGroupVisual {
  const NavigationGroupVisual({
    required this.icon,
    required this.accent,
    required this.container,
    required this.description,
  });

  final IconData icon;
  final Color accent;
  final Color container;
  final String description;

  static NavigationGroupVisual resolve(
    BuildContext context,
    MobileModuleGroup group,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return switch (group) {
      MobileModuleGroup.fieldWork => NavigationGroupVisual(
        icon: Icons.engineering_rounded,
        accent: scheme.primary,
        container: scheme.primaryContainer.withValues(alpha: 0.36),
        description: 'Задачи на объекте, смены и контроль выполнения',
      ),
      MobileModuleGroup.warehouseAndSupply => NavigationGroupVisual(
        icon: Icons.inventory_2_rounded,
        accent: scheme.secondary,
        container: scheme.secondaryContainer.withValues(alpha: 0.38),
        description: 'Материалы, складские операции и снабжение',
      ),
      MobileModuleGroup.approvalsAndDocs => NavigationGroupVisual(
        icon: Icons.fact_check_rounded,
        accent: scheme.tertiary,
        container: scheme.tertiaryContainer.withValues(alpha: 0.34),
        description: 'Согласования, журналы и документы',
      ),
      MobileModuleGroup.management => NavigationGroupVisual(
        icon: Icons.space_dashboard_rounded,
        accent: scheme.onSurfaceVariant,
        container: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
        description: 'Управление, справочники и профиль',
      ),
    };
  }
}

class NavigationActionVisual {
  const NavigationActionVisual({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static NavigationActionVisual resolve(MobileActionSource source) {
    return switch (source) {
      MobileActionSource.pinned => const NavigationActionVisual(
        label: 'Закреплено',
        icon: Icons.star_rounded,
      ),
      MobileActionSource.system => const NavigationActionVisual(
        label: 'Рекомендовано',
        icon: Icons.auto_awesome_rounded,
      ),
    };
  }
}
