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
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final ProSurfaceTone tone;
  final bool bordered;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      ProSurfaceTone.base => theme.colorScheme.surface,
      ProSurfaceTone.subtle => theme.colorScheme.surfaceContainer,
      ProSurfaceTone.tinted => theme.colorScheme.primaryContainer.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.2 : 0.32,
      ),
      ProSurfaceTone.elevated => theme.colorScheme.surfaceContainerHigh,
    };

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side:
          bordered
              ? BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.16),
              )
              : BorderSide.none,
    );

    final content = Padding(padding: padding, child: child);

    return Material(
      color: color,
      elevation: tone == ProSurfaceTone.elevated ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child:
          onTap == null
              ? content
              : InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: ProTouchTarget.min,
                  ),
                  child: content,
                ),
              ),
    );
  }
}
