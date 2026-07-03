import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';

class OverviewWorkSummary extends StatelessWidget {
  const OverviewWorkSummary({
    super.key,
    required this.widgets,
    required this.onOpenGroup,
  });

  final List<DashboardWidgetModel> widgets;
  final ValueChanged<MobileModuleGroup> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    return ProSurface(
      padding: EdgeInsets.zero,
      tone: ProSurfaceTone.elevated,
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
              title: 'Рабочая сводка',
              subtitle: 'Ключевые зоны объекта без лишних переходов.',
            ),
          ),
          const ProSectionDivider(indent: ProSpacing.md),
          _SummaryRow(
            label: 'В поле',
            group: MobileModuleGroup.fieldWork,
            icon: Icons.engineering_rounded,
            widgets: widgets,
            onOpen: onOpenGroup,
          ),
          const _SummaryDivider(),
          _SummaryRow(
            label: 'Склад',
            group: MobileModuleGroup.warehouseAndSupply,
            icon: Icons.inventory_2_rounded,
            widgets: widgets,
            onOpen: onOpenGroup,
          ),
          const _SummaryDivider(),
          _SummaryRow(
            label: 'Согласования',
            group: MobileModuleGroup.approvalsAndDocs,
            icon: Icons.fact_check_rounded,
            widgets: widgets,
            onOpen: onOpenGroup,
          ),
          const _SummaryDivider(),
          _SummaryRow(
            label: 'Управление',
            group: MobileModuleGroup.management,
            icon: Icons.space_dashboard_rounded,
            widgets: widgets,
            onOpen: onOpenGroup,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.group,
    required this.icon,
    required this.widgets,
    required this.onOpen,
  });

  final String label;
  final MobileModuleGroup group;
  final IconData icon;
  final List<DashboardWidgetModel> widgets;
  final ValueChanged<MobileModuleGroup> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupWidgets = widgets
        .where((widget) {
          final destination =
              MobileNavigationRegistry.destinationForRoute(widget.route) ??
              MobileNavigationRegistry.destinationForRoute(widget.slug);

          return destination?.group == group;
        })
        .toList(growable: false);

    final criticalCount =
        groupWidgets
            .where((widget) => widget.status == DashboardWidgetStatus.critical)
            .length;
    final attentionCount =
        groupWidgets
            .where((widget) => widget.status == DashboardWidgetStatus.attention)
            .length;
    final totalAttention = criticalCount + attentionCount;
    final hasAttention = totalAttention > 0;
    final tone =
        criticalCount > 0 ? ProStatusTone.danger : ProStatusTone.warning;
    final statusStyle = proStatusStyle(
      context,
      hasAttention ? tone : ProStatusTone.success,
    );
    final statusText = hasAttention ? totalAttention.toString() : 'Без критики';
    final title = hasAttention ? '$label · требуют внимания' : label;
    final details =
        criticalCount > 0
            ? 'Критично: $criticalCount'
            : attentionCount > 0
            ? 'Внимание: $attentionCount'
            : 'Сигналов нет';

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onOpen(group),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ProTouchTarget.comfortable,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ProSpacing.md,
                vertical: ProSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(ProRadius.sm),
                    ),
                    child: Icon(icon, color: statusStyle.foreground, size: 20),
                  ),
                  const SizedBox(width: ProSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(
                            context,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: ProSpacing.xxs),
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ProSpacing.sm),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: ProSpacing.xs,
                      vertical: ProSpacing.xxs,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(ProRadius.pill),
                      border: Border.all(color: statusStyle.border),
                    ),
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        context,
                      ).copyWith(color: statusStyle.foreground),
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
        ),
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: ProSpacing.md,
      endIndent: ProSpacing.md,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
    );
  }
}
