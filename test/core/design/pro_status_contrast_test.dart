import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';

void main() {
  group('pro status colors', () {
    for (final themeCase in [
      (name: 'light', theme: MostTheme.lightTheme),
      (name: 'dark', theme: MostTheme.darkTheme),
    ]) {
      testWidgets(
        '${themeCase.name} theme status foregrounds meet text contrast',
        (tester) async {
          final failures = <String>[];

          await tester.pumpWidget(
            MaterialApp(
              theme: themeCase.theme,
              home: Builder(
                builder: (context) {
                  final scheme = Theme.of(context).colorScheme;
                  final surfaces = {
                    'surface': scheme.surface,
                    'surfaceContainer': scheme.surfaceContainer,
                  };

                  for (final tone in ProStatusTone.values) {
                    final style = proStatusStyle(context, tone);

                    for (final surface in surfaces.entries) {
                      final contrast = _contrastRatio(
                        style.foreground,
                        surface.value,
                      );

                      if (contrast < 4.5) {
                        failures.add(
                          '${tone.name} on ${surface.key}: ${contrast.toStringAsFixed(2)}',
                        );
                      }
                    }
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          expect(failures, isEmpty, reason: failures.join('\n'));
        },
      );
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter =
      foregroundLuminance > backgroundLuminance
          ? foregroundLuminance
          : backgroundLuminance;
  final darker =
      foregroundLuminance > backgroundLuminance
          ? backgroundLuminance
          : foregroundLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}
