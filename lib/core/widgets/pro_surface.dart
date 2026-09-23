import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';

enum ProSurfaceTone { base, subtle, tinted, elevated }

class ProSurface extends StatelessWidget {
  const ProSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ProSpacing.md),
    this.tone = ProSurfaceTone.base,
    this.bordered = true,
    this.borderRadius = ProRadius.sm,
    this.semanticLabel,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.width,
    this.height,
    this.gradient,
    this.onTapFeedback,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final ProSurfaceTone tone;
  final bool bordered;
  final double borderRadius;
  final String? semanticLabel;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double? width;
  final double? height;
  final Gradient? gradient;
  final VoidCallback? onTapFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = switch (tone) {
      ProSurfaceTone.base => theme.colorScheme.surface,
      ProSurfaceTone.subtle => theme.colorScheme.surfaceContainer,
      ProSurfaceTone.tinted =>
        isDark
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.surface,
            ),
      ProSurfaceTone.elevated =>
        isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surface,
    };
    final surfaceColor = backgroundColor ?? color;
    final borderAlpha = switch (tone) {
      ProSurfaceTone.elevated => isDark ? 0.22 : 0.58,
      ProSurfaceTone.tinted => isDark ? 0.2 : 0.42,
      _ => isDark ? 0.18 : 0.42,
    };
    final elevation = switch (tone) {
      ProSurfaceTone.elevated => isDark ? 1.0 : 3.0,
      _ => isDark ? 0.0 : 1.5,
    };
    final shadowAlpha = switch (tone) {
      ProSurfaceTone.elevated => isDark ? 0.16 : 0.14,
      _ => isDark ? 0.12 : 0.1,
    };

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side:
          bordered
              ? BorderSide(
                color:
                    borderColor ??
                    theme.colorScheme.outline.withValues(alpha: borderAlpha),
                width: borderWidth,
              )
              : BorderSide.none,
    );

    final paddedContent = Padding(padding: padding, child: child);
    final content =
        gradient == null
            ? paddedContent
            : DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: paddedContent,
            );

    return Material(
      color: surfaceColor,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: shadowAlpha),
      shape: shape,
      child: SizedBox(
        width: width,
        height: height,
        child:
            onTap == null
                ? Semantics(container: true, child: content)
                : _buildInteractiveSurface(content),
      ),
    );
  }

  Widget _buildInteractiveSurface(Widget content) {
    void handleTap() {
      if (onTapFeedback == null) {
        HapticFeedback.selectionClick();
      } else {
        onTapFeedback!();
      }
      onTap!();
    }

    final tappableContent = InkWell(
      onTap: handleTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ProTouchTarget.min),
        child: content,
      ),
    );

    if (semanticLabel == null) {
      return Semantics(
        container: true,
        button: true,
        enabled: true,
        child: tappableContent,
      );
    }

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      focusable: true,
      label: semanticLabel,
      onTap: handleTap,
      child: ExcludeSemantics(child: tappableContent),
    );
  }
}
