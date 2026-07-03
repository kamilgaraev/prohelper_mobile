import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';

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
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(borderRadius);
    final decoration = BoxDecoration(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: radius,
      border: Border.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.14),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.04,
          ),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
    final content = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
      child: child,
    );

    if (onTap == null) {
      return Container(decoration: decoration, child: content);
    }

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: Container(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: ProTouchTarget.min),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
