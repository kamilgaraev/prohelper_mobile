import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../../core/widgets/action_hub.dart';
import './controllers/dashboard_controller.dart';
import 'material_detail_screen.dart';
import '../../auth/presentation/widgets/profile_pill.dart';
import '../../auth/presentation/widgets/user_profile_bottom_sheet.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';


class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final type = dashboardState.slots[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildWidgetByType(context, type),
                      );
                    },
                    childCount: dashboardState.slots.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ActionHub(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      floating: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: Consumer(
        builder: (context, ref, child) {
          final projectsState = ref.watch(projectsProvider);
          final projectName = projectsState.selectedProject?.name.toUpperCase() ?? 'PROHELPER';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (projectsState.selectedProject != null)
                Text(
                  'ВЫБРАННЫЙ ОБЪЕКТ',
                  style: AppTypography.caption(context).copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                projectName, 
                style: AppTypography.h2(context).copyWith(
                  letterSpacing: 0.5, 
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
      centerTitle: false,
      actions: [
        Consumer(
          builder: (context, ref, child) {
            final authState = ref.watch(authProvider);
            if (authState is AuthAuthenticated) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: ProfilePill(
                    user: authState.user,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => UserProfileBottomSheet(user: authState.user),
                      );
                    },
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildWidgetByType(BuildContext context, DashboardWidgetType type) {
    return switch (type) {
      DashboardWidgetType.primaryAction => _buildPrimaryAction(context),
      DashboardWidgetType.stats => _buildStats(context),
      DashboardWidgetType.urgentRequests => _buildUrgentRequests(context),
      DashboardWidgetType.approvalCounter => _buildApprovalCounter(context),
      DashboardWidgetType.timeline => _buildTimeline(context),
    };
  }

  Widget _buildPrimaryAction(BuildContext context) {
    final theme = Theme.of(context);
    return IndustrialCard(
      height: 120,
      onTap: () {},
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('ПРИНЯТЬ МАТЕРИАЛ', 
                          style: AppTypography.h2(context).copyWith(
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          )
                        ),
                        const SizedBox(height: 4),
                        Text('Отсканируйте QR или штрих-код', 
                          style: AppTypography.caption(context).copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      ],
                    ),
                  ),
                  Icon(Icons.qr_code_scanner_rounded, 
                    size: 40, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final theme = Theme.of(context);
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('КОНТРОЛЬ ОБЪЕКТА', 
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 0.5,
                  color: theme.colorScheme.onSurface,
                )
              ),
              Icon(Icons.analytics_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow(context, 'Бюджет', '84.2%', AppColors.success),
          _buildStatRow(context, 'Сроки', '-2 дня', AppColors.error),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium(context).copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6)
          )),
          Text(value, style: AppTypography.bodySmall(context).copyWith(
            color: color, 
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('БЛИЖАЙШИЕ ПОСТАВКИ', 
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w900, 
              letterSpacing: 1,
              color: theme.colorScheme.onSurface,
            )
          ),
        ),
        ...List.generate(3, (index) => _buildTimelineItem(context, '123')),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, String id) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IndustrialCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => MaterialDetailScreen(materialId: id)),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('БЕТОН М400', 
                    style: AppTypography.bodyLarge(context).copyWith(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('12.5 м³', style: AppTypography.bodySmall(context).copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                      Text(' • ', style: AppTypography.caption(context)),
                      Text('15:40', style: AppTypography.bodySmall(context).copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentRequests(BuildContext context) {
    return _buildModuleActionCard(
      context: context,
      title: 'ЗАЯВКИ С ОБЪЕКТА',
      subtitle: 'Заказать материалы или персонал',
      icon: Icons.add_task_rounded,
      color: AppColors.secondary,
      onTap: (context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SiteRequestsScreen()),
      ),
    );
  }

  Widget _buildApprovalCounter(BuildContext context) {
    return _buildModuleActionCard(
      context: context,
      title: 'СОГЛАСОВАНИЯ',
      subtitle: 'Ожидают вашего подтверждения',
      icon: Icons.fact_check_rounded,
      color: Theme.of(context).colorScheme.primary,
      onTap: (context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SiteRequestsScreen()),
      ),
    );
  }

  Widget _buildModuleActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Function(BuildContext) onTap,
  }) {
    final theme = Theme.of(context);
    return IndustrialCard(
      onTap: () => onTap(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodySmall(context).copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.onSurface,
                )),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.caption(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
        ],
      ),
    );
  }

}
