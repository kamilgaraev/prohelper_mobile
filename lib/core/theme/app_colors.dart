import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFF16A28);
  static const Color primaryDark = Color(0xFFE86020);
  static const Color secondary = Color(0xFFC4B08A);

  static const Color background = Color(0xFF161513);
  static const Color surface = Color(0xFF221F1C);
  static const Color surfaceLight = Color(0xFF332F2B);
  static const Color textPrimary = Color(0xFFE8E4DC);
  static const Color textSecondary = Color(0xFFA8A49A);

  static const Color backgroundLight = Color(0xFFF6F2F1);
  static const Color surfaceLightMode = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFDCDED5);
  static const Color textPrimaryLight = Color(0xFF080E14);

  static const Color success = Color(0xFF8FCB6A);
  static const Color error = Color(0xFFE07068);
  static const Color warning = Color(0xFFE0A24B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [surface, surfaceLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
