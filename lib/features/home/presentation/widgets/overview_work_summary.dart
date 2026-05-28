import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/widgets/pro_metric_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
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
    return ProSectionBlock(
      title: 'Рабочая сводка',
      subtitle: 'Ключевые зоны собраны в компактный обзор.',
      children: [
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.25,
          children: [
            _SummaryTile(
              label: 'В поле',
              group: MobileModuleGroup.fieldWork,
              icon: Icons.engineering_rounded,
              widgets: widgets,
              onOpen: onOpenGroup,
            ),
            _SummaryTile(
              label: 'Склад',
              group: MobileModuleGroup.warehouseAndSupply,
              icon: Icons.inventory_2_rounded,
              widgets: widgets,
              onOpen: onOpenGroup,
            ),
            _SummaryTile(
              label: 'Согласования',
              group: MobileModuleGroup.approvalsAndDocs,
              icon: Icons.fact_check_rounded,
              widgets: widgets,
              onOpen: onOpenGroup,
            ),
            _SummaryTile(
              label: 'Управление',
              group: MobileModuleGroup.management,
              icon: Icons.space_dashboard_rounded,
              widgets: widgets,
              onOpen: onOpenGroup,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
    final attentionCount =
        widgets
            .where(
              (widget) =>
                  widget.status == DashboardWidgetStatus.attention ||
                  widget.status == DashboardWidgetStatus.critical,
            )
            .length;

    return GestureDetector(
      onTap: () => onOpen(group),
      child: ProMetricTile(
        label:
            attentionCount > 0
                ? '$label · требуют внимания'
                : '$label · без критики',
        value: attentionCount > 0 ? attentionCount.toString() : 'OK',
        icon: icon,
        color:
            attentionCount > 0
                ? proStatusStyle(context, ProStatusTone.warning).foreground
                : proStatusStyle(context, ProStatusTone.success).foreground,
      ),
    );
  }
}
