import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

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
    final radius = BorderRadius.circular(MostTheme.cardRadius);
    final surface = ProSurface(
      width: width,
      height: height,
      onTap: onTap,
      onTapFeedback: onTap == null ? null : HapticFeedback.lightImpact,
      padding: padding,
      borderRadius: MostTheme.cardRadius,
      tone: ProSurfaceTone.base,
      bordered: border == null,
      backgroundColor: backgroundColor ?? Theme.of(context).cardTheme.color,
      borderColor: borderColor ?? Theme.of(context).colorScheme.outline,
      borderWidth: MostTheme.borderWidth,
      child: child,
    );

    if (border == null) {
      return surface;
    }

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: border, borderRadius: radius),
      child: surface,
    );
  }
}
