import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';

void main() {
  test('design tokens keep stable touch and spacing values', () {
    expect(ProTouchTarget.min, greaterThanOrEqualTo(44));
    expect(ProSpacing.pageHorizontal, 16);
    expect(ProRadius.sm, lessThanOrEqualTo(8));
  });

  testWidgets('theme exposes Material 3 surface roles and status styles', (
    tester,
  ) async {
    late ProStatusStyle status;

    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: Builder(
          builder: (context) {
            status = proStatusStyle(context, ProStatusTone.warning);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(MostTheme.lightTheme.useMaterial3, isTrue);
    expect(MostTheme.darkTheme.useMaterial3, isTrue);
    expect(
      MostTheme.lightTheme.colorScheme.surfaceContainerHighest,
      isA<Color>(),
    );
    expect(status.icon, Icons.warning_amber_rounded);
  });

  test('app bars keep system status icons readable in both themes', () {
    final lightOverlay =
        MostTheme.lightTheme.appBarTheme.systemOverlayStyle;
    final darkOverlay = MostTheme.darkTheme.appBarTheme.systemOverlayStyle;

    expect(lightOverlay, isNotNull);
    expect(lightOverlay!.statusBarIconBrightness, Brightness.dark);
    expect(lightOverlay.statusBarBrightness, Brightness.light);
    expect(darkOverlay, isNotNull);
    expect(darkOverlay!.statusBarIconBrightness, Brightness.light);
    expect(darkOverlay.statusBarBrightness, Brightness.dark);
  });
}
