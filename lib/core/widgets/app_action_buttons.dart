import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/theme/app_typography.dart';

class AppPrimaryActionButton extends StatelessWidget {
  const AppPrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isBusy = false,
    this.busyLabel,
    this.expanded = true,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool isBusy;
  final String? busyLabel;
  final bool expanded;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = backgroundColor ?? theme.colorScheme.primary;

    final button = FilledButton(
      onPressed: isBusy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: theme.colorScheme.onPrimary,
        disabledBackgroundColor: color.withValues(alpha: 0.55),
        disabledForegroundColor: theme.colorScheme.onPrimary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppTypography.button,
      ),
      child: _ActionButtonContent(
        label: isBusy ? busyLabel ?? label : label,
        leading: leading,
        isBusy: isBusy,
        progressColor: theme.colorScheme.onPrimary,
      ),
    );

    if (!expanded) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class AppSecondaryActionButton extends StatelessWidget {
  const AppSecondaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isBusy = false,
    this.busyLabel,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool isBusy;
  final String? busyLabel;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final button = OutlinedButton(
      onPressed: isBusy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: theme.colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppTypography.button.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      child: _ActionButtonContent(
        label: isBusy ? busyLabel ?? label : label,
        leading: leading,
        isBusy: isBusy,
        progressColor: theme.colorScheme.primary,
      ),
    );

    if (!expanded) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class _ActionButtonContent extends StatelessWidget {
  const _ActionButtonContent({
    required this.label,
    required this.leading,
    required this.isBusy,
    required this.progressColor,
  });

  final String label;
  final Widget? leading;
  final bool isBusy;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBusy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: progressColor,
              ),
            )
          else if (leading != null)
            leading!,
          if (isBusy || leading != null) const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
