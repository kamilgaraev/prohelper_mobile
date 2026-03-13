import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/user_context.dart';
import '../providers/context_provider.dart';
import '../providers/module_provider.dart';
import '../services/permission_service.dart';
import '../theme/app_typography.dart';
import '../theme/pro_theme.dart';
import 'quick_action_sheet.dart';

class ActionHub extends ConsumerWidget {
  const ActionHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(userContextProvider);
    final permissions = ref.watch(permissionServiceProvider);
    final theme = Theme.of(context);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: ProHelperTheme.borderWidth,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.cardTheme.shadowColor ?? Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildNavItem(
              context,
              icon: Icons.dashboard_rounded,
              label: 'Дашборд',
              isActive: true,
            ),
          ),
          _buildPrimaryButton(context, userContext, permissions),
          Expanded(
            child: _buildNavItem(
              context,
              icon: Icons.history_rounded,
              label: 'История',
              isActive: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: HapticFeedback.selectionClick,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.4),
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(
              color: isActive
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withOpacity(0.4),
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context,
    UserContext userContext,
    PermissionService permissions,
  ) {
    final theme = Theme.of(context);
    var icon = Icons.grid_view_rounded;

    if (userContext == UserContext.field) {
      if (permissions.canAccessModule(AppModule.basicWarehouse)) {
        icon = Icons.qr_code_scanner_rounded;
      } else if (permissions.canAccessModule(AppModule.siteRequests)) {
        icon = Icons.add_task_rounded;
      }
    } else if (permissions.canAccessModule(AppModule.siteRequests)) {
      icon = Icons.fact_check_rounded;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const QuickActionSheet(),
        );
      },
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
