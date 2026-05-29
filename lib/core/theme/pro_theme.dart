import 'package:flutter/material.dart';
import 'app_colors.dart';

class ProHelperTheme {
  // Industrial properties
  static const double cardRadius = 8.0;
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
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      surfaceContainer: const Color(0xFF202124),
      surfaceContainerHigh: const Color(0xFF25262A),
      surfaceContainerHighest: const Color(0xFF2A2B30),
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: const Color(0xFFC2C4CC),
      outline: const Color(0xFF3A3C43),
      error: AppColors.error,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      textTheme: _buildTextTheme(base.textTheme, true),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _buildTextTheme(base.textTheme, true).titleLarge,
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.5),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      chipTheme: _chipTheme(scheme),
      filledButtonTheme: _filledButtonTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(scheme),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      surface: AppColors.surfaceLightMode,
      surfaceContainer: const Color(0xFFF7F8FA),
      surfaceContainerHigh: const Color(0xFFF1F3F6),
      surfaceContainerHighest: const Color(0xFFE8EBF0),
      onSurface: AppColors.textPrimaryLight,
      onSurfaceVariant: const Color(0xFF5D6470),
      outline: const Color(0xFFD8DDE6),
      error: AppColors.error,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      colorScheme: scheme,
      textTheme: _buildTextTheme(base.textTheme, false),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF4F6F9),
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _buildTextTheme(base.textTheme, false).titleLarge,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceLightMode,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.72),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      chipTheme: _chipTheme(scheme),
      filledButtonTheme: _filledButtonTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(scheme),
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
        letterSpacing: 0,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        color: isDark ? Colors.white60 : Colors.black45,
        letterSpacing: 0,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static ChipThemeData _chipTheme(ColorScheme scheme) {
    return ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    );
  }
}
