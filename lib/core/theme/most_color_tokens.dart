import 'package:flutter/material.dart';

class MostColorTokens {
  const MostColorTokens({
    required this.action,
    required this.onAction,
    required this.actionHover,
    required this.paper,
    required this.ink,
    required this.muted,
    required this.line,
    required this.card,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color action;
  final Color onAction;
  final Color actionHover;
  final Color paper;
  final Color ink;
  final Color muted;
  final Color line;
  final Color card;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  static const light = MostColorTokens(
    action: Color(0xFFF16A28),
    onAction: Color(0xFF191F19),
    actionHover: Color(0xFFE86020),
    paper: Color(0xFFF6F2F1),
    ink: Color(0xFF080E14),
    muted: Color(0xFF60645D),
    line: Color(0xFFDCDED5),
    card: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF1ECEA),
    surfaceContainerHigh: Color(0xFFEBE6E4),
    surfaceContainerHighest: Color(0xFFE4DEDC),
    success: Color(0xFF2F6B3C),
    warning: Color(0xFF8A5200),
    danger: Color(0xFFA02222),
    info: Color(0xFF4A5340),
  );

  static const dark = MostColorTokens(
    action: Color(0xFFF16A28),
    onAction: Color(0xFF191F19),
    actionHover: Color(0xFFFF7A3A),
    paper: Color(0xFF161513),
    ink: Color(0xFFE8E4DC),
    muted: Color(0xFFA8A49A),
    line: Color(0xFF3F3C37),
    card: Color(0xFF221F1C),
    surfaceContainer: Color(0xFF1C1A18),
    surfaceContainerHigh: Color(0xFF2A2723),
    surfaceContainerHighest: Color(0xFF332F2B),
    success: Color(0xFF8FCB6A),
    warning: Color(0xFFE0A24B),
    danger: Color(0xFFE07068),
    info: Color(0xFFC4B08A),
  );

  ColorScheme get colorScheme {
    final brightness =
        paper.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;
    final onAccent =
        brightness == Brightness.light ? const Color(0xFFFFFFFF) : paper;

    return ColorScheme(
      brightness: brightness,
      primary: action,
      onPrimary: onAction,
      primaryContainer: actionHover,
      onPrimaryContainer: onAction,
      secondary: info,
      onSecondary: onAccent,
      secondaryContainer: surfaceContainerHigh,
      onSecondaryContainer: ink,
      tertiary: warning,
      onTertiary: onAction,
      error: danger,
      onError: onAccent,
      surface: card,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: line,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      inverseSurface: ink,
      onInverseSurface: paper,
      inversePrimary: actionHover,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }
}
