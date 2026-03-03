import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/industrial_card.dart';
import '../../domain/auth_provider.dart';
import '../../data/user_model.dart';
import '../../../projects/domain/projects_provider.dart';

class UserProfileBottomSheet extends ConsumerWidget {
  final User user;

  const UserProfileBottomSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organizations = user.organizations;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.primary,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name, 
                      style: AppTypography.h2(context).copyWith(
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        user.roles.isEmpty ? 'БЕЗ РОЛИ' : user.roles.join(', ').toUpperCase(),
                        style: AppTypography.caption(context).copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          Text(
            'ОРГАНИЗАЦИЯ', 
            style: AppTypography.caption(context),
          ),
          const SizedBox(height: 12),
          
          ...organizations.map((org) {
            final orgId = org['id'] as int;
            final isSelected = user.currentOrganizationId == orgId;
                             
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IndustrialCard(
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).switchOrganization(org['id'] as int);
                },
                padding: const EdgeInsets.all(16),
                backgroundColor: isSelected 
                    ? theme.colorScheme.primary.withOpacity(0.05)
                    : theme.cardTheme.color,
                border: isSelected 
                    ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                    : null,
                child: Row(
                  children: [
                    Icon(
                      Icons.business_rounded,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        org['name'] as String,
                        style: AppTypography.bodyMedium(context).copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            );
          }),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(projectsProvider.notifier).clearSelection();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: theme.dividerColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.onSurface),
              label: Text(
                'СМЕНИТЬ ОБЪЕКТ', 
                style: AppTypography.button.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: theme.dividerColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurface),
              label: Text(
                'НАСТРОЙКИ', 
                style: AppTypography.button.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: AppColors.error.withOpacity(0.05),
              ),
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: Text(
                'ВЫЙТИ', 
                style: AppTypography.button.copyWith(
                  color: AppColors.error,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
