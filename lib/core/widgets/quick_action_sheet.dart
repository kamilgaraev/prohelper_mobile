import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';

class QuickActionSheet extends StatelessWidget {
  final PermissionService permissions;

  const QuickActionSheet({super.key, required this.permissions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Use theme surface
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'БЫСТРЫЕ ДЕЙСТВИЯ',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              if (permissions.canAccessModule(AppModule.siteRequests))
                _ActionItem(
                  icon: Icons.add_task_rounded,
                  label: 'Заявки',
                  color: AppColors.secondary,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SiteRequestsScreen()),
                    );
                  },
                ),
              if (permissions.canAccessModule(AppModule.basicWarehouse))
                _ActionItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Склад',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Перейти на сканер/склад
                  },
                ),
               _ActionItem(
                  icon: Icons.analytics_outlined,
                  label: 'Отчеты',
                  color: AppColors.success,
                  onTap: () => Navigator.pop(context),
                ),
                _ActionItem(
                  icon: Icons.people_outline_rounded,
                  label: 'Персонал',
                  color: Colors.purpleAccent,
                  onTap: () => Navigator.pop(context),
                ),
                _ActionItem(
                  icon: Icons.settings_outlined,
                  label: 'Настройки',
                  color: AppColors.textSecondary,
                  onTap: () => Navigator.pop(context),
                ),
                 _ActionItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Помощь',
                  color: Colors.cyan,
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
