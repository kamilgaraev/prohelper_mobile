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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);

    return Scaffold(
      // backgroundColor is handled by Theme
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
    return SliverAppBar(
      floating: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                projectName, 
                style: AppTypography.h2.copyWith(
                  letterSpacing: 0.5, 
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
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
      DashboardWidgetType.urgentRequests => _buildUrgentRequests(),
      DashboardWidgetType.approvalCounter => _buildApprovalCounter(),
      DashboardWidgetType.timeline => _buildTimeline(context),
    };
  }

  Widget _buildPrimaryAction(BuildContext context) {
    return IndustrialCard(
      height: 120,
      onTap: () {},
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
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
                          style: AppTypography.h2.copyWith(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          )
                        ),
                        const SizedBox(height: 4),
                        Text('Отсканируйте QR или штрих-код', 
                          style: AppTypography.caption.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code_scanner_rounded, 
                    size: 40, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('КОНТРОЛЬ ОБЪЕКТА', 
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.onSurface,
                )
              ),
              const Icon(Icons.analytics_outlined, size: 16, color: AppColors.textSecondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
          )),
          Text(value, style: AppTypography.bodySmall.copyWith(
            color: color, 
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('БЛИЖАЙШИЕ ПОСТАВКИ', 
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w900, 
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurface,
            )
          ),
        ),
        ...List.generate(3, (index) => _buildTimelineItem(context, '123')),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, String id) {
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
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('БЕТОН М400', 
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('12.5 м³', style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                      Text(' • ', style: AppTypography.caption),
                      Text('15:40', style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.surfaceLight),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentRequests() => const SizedBox.shrink();
  Widget _buildApprovalCounter() => const SizedBox.shrink();
}
