import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/widgets/pro_metric_tile.dart';

class ProSummaryMetric {
  const ProSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
}

class ProOperationalSummaryGrid extends StatelessWidget {
  const ProOperationalSummaryGrid({
    super.key,
    required this.metrics,
    this.crossAxisCount = 2,
  });

  final List<ProSummaryMetric> metrics;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        for (final metric in metrics)
          ProMetricTile(
            label: metric.label,
            value: metric.value,
            icon: metric.icon,
            color: metric.color,
          ),
      ],
    );
  }
}
