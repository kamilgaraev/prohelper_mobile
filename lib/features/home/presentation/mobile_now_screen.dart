import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation_provider.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';
import 'package:prohelpers_mobile/features/sync/domain/pending_sync_provider.dart';
import 'package:prohelpers_mobile/features/sync/presentation/pending_sync_screen.dart';

class MobileNowScreen extends ConsumerWidget {
  const MobileNowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(mobileRecommendedActionsProvider);
    final pending = ref.watch(pendingSyncProvider);
    final projects = ref.watch(projectsProvider);
    final visible = actions.take(7).toList(growable: false);
    final pendingCount = pending.operations.length;
    final reviewCount =
        pending.operations.where((operation) {
          return operation.status == SyncOperationStatuses.conflict ||
              operation.status == SyncOperationStatuses.needsEdit ||
              operation.status == SyncOperationStatuses.permissionDenied;
        }).length;

    return ProPageScaffold(
      title: 'Главная',
      subtitle: 'Ваши задачи и быстрые действия',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (projects.fromCache) ...[
            const ProStatusBanner(
              title: 'Объект сохранён на устройстве',
              description: 'Проверьте обновления при появлении связи.',
              compact: true,
              fullText: true,
            ),
            const SizedBox(height: 12),
          ],
          if (pendingCount > 0) ...[
            _NowIntentRow(
              title: 'Не отправлено',
              subtitle:
                  reviewCount > 0
                      ? 'Требуют проверки: $reviewCount'
                      : pendingCount == 1
                      ? '1 операция ждёт связи'
                      : '$pendingCount операций ждут связи',
              icon: Icons.cloud_off_outlined,
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PendingSyncScreen(),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
          ],
          if (visible.isEmpty && (!projects.hasLoaded || projects.isLoading))
            const AppEmptyState(
              icon: Icons.hourglass_top_rounded,
              title: 'Загружаем действия',
            )
          else if (visible.isEmpty && projects.selectedProject == null)
            AppEmptyState(
              icon: Icons.domain_outlined,
              title: 'Выберите объект',
              description: 'После выбора здесь появятся доступные действия.',
              action: FilledButton(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProjectSelectionScreen(),
                      ),
                    ),
                child: const Text('Выбрать объект'),
              ),
            )
          else if (visible.isEmpty)
            const AppEmptyState(
              icon: Icons.bolt_outlined,
              title: 'Пока нет доступных действий',
              description: 'Когда появятся права и задачи, они будут здесь.',
            )
          else
            ProSurface(
              tone: ProSurfaceTone.elevated,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      ProSpacing.md,
                      ProSpacing.md,
                      ProSpacing.md,
                      0,
                    ),
                    child: ProSectionHeader(
                      title: 'Быстрые действия',
                      subtitle: 'Откройте нужную форму одним нажатием.',
                    ),
                  ),
                  const ProSectionDivider(indent: ProSpacing.md),
                  for (var index = 0; index < visible.length; index++) ...[
                    _NowIntentRow(
                      title: visible[index].destination.shortTitle,
                      subtitle:
                          visible[index].source == MobileActionSource.pinned
                              ? 'Закреплено'
                              : visible[index].reason,
                      icon: visible[index].destination.icon,
                      onTap:
                          () =>
                              _openIntent(context, visible[index].destination),
                    ),
                    if (index != visible.length - 1)
                      const ProSectionDivider(indent: 72),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openIntent(BuildContext context, MobileModuleDestination destination) {
    HapticFeedback.selectionClick();
    final builder =
        destination.isPrimaryAction
            ? destination.openBuilder
            : destination.builder;
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

class _NowIntentRow extends StatelessWidget {
  const _NowIntentRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, ProStatusTone.info);
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ProSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(ProRadius.sm),
                ),
                child: Icon(icon, color: status.foreground, size: 22),
              ),
              const SizedBox(width: ProSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: ProSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ProSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
