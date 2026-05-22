import 'package:flutter/material.dart';
import 'app_colors.dart';

class ProHelperTheme {
  // Industrial properties
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double borderWidth = 0.5;
  static const double glassBlurSigma = 20.0;
  static const double glassOpacity = 0.72;
  static const double glassBorderOpacity = 0.12;
  static final Color borderColor = const Color(0xFF2C2C2E);

  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        outline: AppColors.surfaceLight, // Border color for dark
      ),
      textTheme: _buildTextTheme(base.textTheme, true),
      cardTheme: CardTheme(
        color: AppColors.surface,
        shadowColor: Colors.black.withValues(alpha: 0.5),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        surface: AppColors.surfaceLightMode,
        onSurface: AppColors.textPrimaryLight,
        outline: AppColors.borderLight, // Border color for light
      ),
      textTheme: _buildTextTheme(base.textTheme, false),
      cardTheme: CardTheme(
        color: AppColors.surfaceLightMode,
        shadowColor: Colors.black.withValues(alpha: 0.1),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, bool isDark) {
    final textColor =
        isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: textColor),
      bodyLarge: base.bodyLarge?.copyWith(color: textColor),
      bodyMedium: base.bodyMedium?.copyWith(color: textColor),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        color: isDark ? Colors.white70 : Colors.black54,
        fontFamily: 'monospace',
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 10,
        color: isDark ? Colors.white60 : Colors.black45,
        fontFamily: 'monospace',
      ),
    );
  }
}
