import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/pro_theme.dart';

class IndustrialCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final BoxBorder? border;

  const IndustrialCard({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(MostTheme.cardRadius);
    final decoration = BoxDecoration(
      color: backgroundColor ?? theme.cardTheme.color,
      borderRadius: radius,
      border:
          border ??
          Border.all(
            color: borderColor ?? theme.colorScheme.outline,
            width: MostTheme.borderWidth,
          ),
      boxShadow: [
        BoxShadow(
          color:
              theme.cardTheme.shadowColor ??
              Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.04,
              ),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    if (onTap == null) {
      return Container(
        height: height,
        width: width,
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: height,
          width: width,
          decoration: decoration,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.lightImpact();
              onTap!();
            },
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
