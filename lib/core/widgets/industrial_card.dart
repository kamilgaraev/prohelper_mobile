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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          onTap != null
              ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
              : null,
      child: Container(
        height: height,
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.cardTheme.color,
          borderRadius: BorderRadius.circular(ProHelperTheme.cardRadius),
          border:
              border ??
              Border.all(
                color: borderColor ?? theme.colorScheme.outline,
                width: ProHelperTheme.borderWidth,
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
        ),
        child: child,
      ),
    );
  }
}
