import 'package:flutter/material.dart';

class AppTypography {
  static TextStyle h1(BuildContext context) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: Theme.of(context).colorScheme.onSurface,
    letterSpacing: 0,
  );

  static TextStyle h2(BuildContext context) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Theme.of(context).colorScheme.onSurface,
    letterSpacing: 0,
  );

  static TextStyle bodyLarge(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurface,
    letterSpacing: 0,
  );

  static TextStyle caption(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    letterSpacing: 0,
  );

  static TextStyle bodySmall(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    letterSpacing: 0,
  );

  static TextStyle get button => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle get mono => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace',
    letterSpacing: 0,
  );
}
