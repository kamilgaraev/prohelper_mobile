import 'package:flutter/material.dart';

class ProSpacing {
  const ProSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pageHorizontal = 16;
  static const double bottomNavSafe = 96;
}

class ProRadius {
  const ProRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double sheet = 22;
  static const double pill = 999;
}

class ProTouchTarget {
  const ProTouchTarget._();

  static const double min = 44;
  static const double comfortable = 52;
}

class ProMotion {
  const ProMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
}

class ProElevation {
  const ProElevation._();

  static List<BoxShadow> subtle(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: brightness == Brightness.dark ? 0.22 : 0.07,
        ),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
