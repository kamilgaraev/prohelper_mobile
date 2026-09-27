import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/pro_design_tokens.dart';
import 'most_color_tokens.dart';

class MostTheme {
  static const String fontFamily = 'IBM Plex Sans';
  static const double cardRadius = ProRadius.sm;
  static const double buttonRadius = ProRadius.sm;
  static const double borderWidth = 0.5;
  static const double glassBlurSigma = 20.0;
  static const double glassOpacity = 0.72;
  static const double glassBorderOpacity = 0.12;
  static final Color borderColor = MostColorTokens.dark.line;
  static final SystemUiOverlayStyle lightSystemOverlayStyle =
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      );
  static final SystemUiOverlayStyle darkSystemOverlayStyle =
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      );

  static SystemUiOverlayStyle systemUiOverlayStyleFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkSystemOverlayStyle
        : lightSystemOverlayStyle;
  }

  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get darkTheme => _build(MostColorTokens.dark);

  static ThemeData get lightTheme => _build(MostColorTokens.light);

  static ThemeData _build(MostColorTokens tokens) {
    final scheme = tokens.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final base =
        isDark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme, tokens);

    return base.copyWith(
      scaffoldBackgroundColor: tokens.paper,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.paper,
        foregroundColor: tokens.ink,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? darkSystemOverlayStyle : lightSystemOverlayStyle,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: tokens.card,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: tokens.action.withValues(alpha: isDark ? 0.28 : 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ProRadius.sheet),
          ),
        ),
      ),
      floatingActionButtonTheme: _floatingActionButtonTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme),
      chipTheme: _chipTheme(scheme),
      filledButtonTheme: _filledButtonTheme(scheme),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      outlinedButtonTheme: _outlinedButtonTheme(scheme),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, MostColorTokens tokens) {
    return base
        .apply(
          fontFamily: fontFamily,
          bodyColor: tokens.ink,
          displayColor: tokens.ink,
        )
        .copyWith(
          labelSmall: base.labelSmall?.copyWith(
            fontFamily: fontFamily,
            fontSize: 12,
            color: tokens.muted,
            letterSpacing: 0,
          ),
          bodySmall: base.bodySmall?.copyWith(
            fontFamily: fontFamily,
            fontSize: 12,
            color: tokens.muted,
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
        fontFamily: fontFamily,
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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(0, ProTouchTarget.comfortable),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme scheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(0, ProTouchTarget.comfortable),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    );
  }

  static FloatingActionButtonThemeData _floatingActionButtonTheme(
    ColorScheme scheme,
  ) {
    return FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      extendedTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: scheme.onPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(0, ProTouchTarget.comfortable),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    );
  }
}
