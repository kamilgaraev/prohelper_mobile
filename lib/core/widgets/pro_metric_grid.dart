import 'package:flutter/material.dart';

class ProMetricGrid extends StatelessWidget {
  const ProMetricGrid({
    super.key,
    required this.children,
    this.maxColumns = 2,
    this.spacing = 12,
    this.runSpacing = 12,
  }) : assert(maxColumns > 0);

  final List<Widget> children;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final minColumnWidth = 144 * textScale;
        final columns = _columnCount(constraints.maxWidth, minColumnWidth);
        final columnSpacing = spacing * (columns - 1);
        final childWidth = (constraints.maxWidth - columnSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: childWidth, child: child),
          ],
        );
      },
    );
  }

  int _columnCount(double availableWidth, double minColumnWidth) {
    if (!availableWidth.isFinite) {
      return maxColumns;
    }

    var columns = maxColumns;
    while (columns > 1 &&
        (availableWidth - spacing * (columns - 1)) / columns < minColumnWidth) {
      columns--;
    }
    return columns;
  }
}
