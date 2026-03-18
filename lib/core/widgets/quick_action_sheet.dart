import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/modules/data/mobile_module_model.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/site_requests/presentation/screens/site_requests_screen.dart';
import '../../features/warehouse/presentation/warehouse_screen.dart';
import '../providers/module_provider.dart';
import '../theme/app_typography.dart';

class QuickActionSheet extends ConsumerWidget {
  const QuickActionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modulesState = ref.watch(modulesProvider);
    final modules = ref.watch(supportedMobileModulesProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            'Быстрые действия',
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (modulesState.isLoading && modules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            )
          else if (modulesState.error != null && modules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    'Не удалось загрузить модули',
                    style: AppTypography.bodyLarge(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    modulesState.error!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.read(modulesProvider.notifier).loadModules(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            )
          else if (modules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Для вашей роли пока нет мобильных модулей.',
                style: AppTypography.bodyMedium(context).copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              itemCount: modules.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.82,
              ),
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final module = modules[index];

                return _ActionItem(
                  icon: _iconFor(module.icon),
                  label: module.title,
                  color: _colorFor(module.route, theme),
                  onTap: () => _openModule(context, module),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openModule(BuildContext context, MobileModuleModel module) {
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    navigator.pop();

    switch (module.route) {
      case 'site_requests':
        navigator.push(
          MaterialPageRoute(builder: (_) => const SiteRequestsScreen()),
        );
        return;
      case 'warehouse':
        navigator.push(
          MaterialPageRoute(builder: (_) => const WarehouseScreen()),
        );
        return;
      case 'schedule':
        navigator.push(
          MaterialPageRoute(builder: (_) => const ScheduleScreen()),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Этот модуль пока недоступен в мобильном приложении.',
            ),
          ),
        );
        return;
    }
  }

  IconData _iconFor(String icon) {
    return switch (icon) {
      'clipboard' => Icons.add_task_rounded,
      'warehouse' => Icons.warehouse_outlined,
      'timeline' => Icons.timeline_rounded,
      'hub' => Icons.hub_outlined,
      'timer' => Icons.timer_outlined,
      'calculate' => Icons.calculate_outlined,
      _ => Icons.grid_view_rounded,
    };
  }

  Color _colorFor(String? route, ThemeData theme) {
    return switch (route) {
      'site_requests' => theme.colorScheme.secondary,
      'warehouse' => theme.colorScheme.primary,
      'schedule' => Colors.green,
      _ => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
