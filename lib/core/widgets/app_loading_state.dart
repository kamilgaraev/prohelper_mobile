import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/theme/app_typography.dart';

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
      label: message,
      liveRegion: true,
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
    );

    if (compact) {
      return Center(child: content);
    }

    return Center(
      child: SizedBox(
        key: const ValueKey('app-loading-state-layout'),
        height: minHeight,
        child: Center(child: content),
      ),
    );
  }
}
