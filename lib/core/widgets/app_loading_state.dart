import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.message = 'Загружаем данные',
    this.minHeight = 220,
    this.compact = false,
  });

  final String message;
  final double minHeight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Semantics(
      container: true,
      label: message,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 24 : 34,
              height: compact ? 24 : 34,
              child: CircularProgressIndicator(
                strokeWidth: compact ? 2 : 3,
                color: theme.colorScheme.primary,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 14),
              Text(
                message,
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );

    if (compact) {
      return Center(child: content);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ProSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ProSurface(
            tone: ProSurfaceTone.elevated,
            child: SizedBox(
              key: const ValueKey('app-loading-state-layout'),
              height: minHeight,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
