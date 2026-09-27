import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';

void main() {
  test('light and dark themes use the saved МОСТ palette and font', () {
    final light = MostTheme.lightTheme;
    final dark = MostTheme.darkTheme;

    expect(light.colorScheme.primary, const Color(0xFFF16A28));
    expect(dark.colorScheme.primary, const Color(0xFFF16A28));
    expect(light.scaffoldBackgroundColor, const Color(0xFFF6F2F1));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF161513));
    expect(light.colorScheme.onSurface, const Color(0xFF080E14));
    expect(dark.colorScheme.onSurface, const Color(0xFFE8E4DC));
    expect(light.textTheme.bodyMedium?.fontFamily, 'IBM Plex Sans');
    expect(dark.textTheme.titleLarge?.fontFamily, 'IBM Plex Sans');
    expect(AppColors.primary, light.colorScheme.primary);
  });

  test('action text remains readable on the orange primary color', () {
    for (final theme in [MostTheme.lightTheme, MostTheme.darkTheme]) {
      final primary = theme.colorScheme.primary;
      final onPrimary = theme.colorScheme.onPrimary;
      final contrast = (primary.computeLuminance() + 0.05) /
          (onPrimary.computeLuminance() + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
  });
}
