import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class ProCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final double borderRadius;

  const ProCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.gradient,
    this.borderRadius = ProRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ProSurface(
      onTap: onTap,
      padding: padding ?? const EdgeInsets.all(20),
      borderRadius: borderRadius,
      tone: ProSurfaceTone.base,
      borderColor: scheme.outline.withValues(alpha: 0.14),
      gradient: gradient,
      child: child,
    );
  }
}
