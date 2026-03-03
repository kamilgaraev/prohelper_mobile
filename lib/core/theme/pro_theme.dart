import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class ProHelperTheme {
  // Industrial properties
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double borderWidth = 0.5;
  static final Color borderColor = const Color(0xFF2C2C2E);
  
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      useMaterial3: true,
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
        shadowColor: Colors.black.withOpacity(0.5),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      useMaterial3: true,
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
        shadowColor: Colors.black.withOpacity(0.1),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, bool isDark) {
    return GoogleFonts.outfitTextTheme(base).copyWith(
      displayLarge: GoogleFonts.outfit(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
      bodyLarge: GoogleFonts.inter(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
      bodyMedium: GoogleFonts.inter(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
      bodySmall: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        color: isDark ? Colors.white60 : Colors.black45,
      ),
    );
  }
}
