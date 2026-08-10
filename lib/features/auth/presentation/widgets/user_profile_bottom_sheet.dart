import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_error_notice.dart';
import '../../../../core/widgets/industrial_card.dart';
import '../../../projects/presentation/project_selection_screen.dart';
import '../../data/user_model.dart';
import '../../domain/auth_provider.dart';
import 'logout_confirmation_dialog.dart';

class UserProfileBottomSheet extends ConsumerWidget {
  const UserProfileBottomSheet({super.key, required this.user});

  final User user;

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
              _ProfileAvatar(user: user),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AppTypography.h2(context).copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        user.displayRoles.isEmpty
                            ? 'Без роли'
                            : user.displayRoles.join(', ').toUpperCase(),
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
          Text('Организация', style: AppTypography.caption(context)),
          const SizedBox(height: 12),
          ...organizations.map((org) {
            final orgId = org['id'] as int;
            final isSelected = user.currentOrganizationId == orgId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IndustrialCard(
                onTap: () async {
                  if (isSelected) {
                    Navigator.pop(context);
                    return;
                  }

                  try {
                    await ref
                        .read(authProvider.notifier)
                        .switchOrganization(orgId);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }

                    AppErrorNotice.show(context, error);
                  }
                },
                padding: const EdgeInsets.all(16),
                backgroundColor:
                    isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.05)
                        : theme.cardTheme.color,
                border:
                    isSelected
                        ? Border.all(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        )
                        : null,
                child: Row(
                  children: [
                    Icon(
                      Icons.business_rounded,
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        org['name'] as String,
                        style: AppTypography.bodyMedium(context).copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                      ),
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
                final navigator = Navigator.of(context);
                navigator.pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!navigator.mounted) {
                    return;
                  }

                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProjectSelectionScreen(),
                    ),
                  );
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: theme.dividerColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                Icons.swap_horiz_rounded,
                color: theme.colorScheme.onSurface,
              ),
              label: Text(
                'Сменить объект',
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
              onPressed: () async {
                final confirmed = await showLogoutConfirmationDialog(context);
                if (!confirmed || !context.mounted) {
                  return;
                }

                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: AppColors.error.withValues(alpha: 0.05),
              ),
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: Text(
                'Выйти',
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

class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar({required this.user});

  final User user;

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _imageFailed = false;

  @override
  void didUpdateWidget(covariant _ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.avatarUrl != widget.user.avatarUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = _profileAvatarUrl(widget.user.avatarUrl);
    final avatarImage =
        avatarUrl != null && !_imageFailed ? NetworkImage(avatarUrl) : null;

    return CircleAvatar(
      radius: 32,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      backgroundImage: avatarImage,
      onBackgroundImageError:
          avatarImage == null
              ? null
              : (_, _) {
                if (mounted) {
                  setState(() => _imageFailed = true);
                }
              },
      child:
          avatarImage == null
              ? Text(
                _profileInitials(widget.user.name),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
              : null,
    );
  }
}

String? _profileAvatarUrl(String? avatarUrl) {
  final normalized = avatarUrl?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  if (normalized.toLowerCase().contains('/images/default-avatar')) {
    return null;
  }

  return normalized;
}

String _profileInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) {
    return 'P';
  }

  return parts.take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
}
