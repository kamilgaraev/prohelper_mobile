import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_visuals.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/mobile_navigation_components.dart';

void main() {
  testWidgets('navigation group visuals provide distinct readable accents', (
    tester,
  ) async {
    late Map<MobileModuleGroup, NavigationGroupVisual> visuals;

    await tester.pumpWidget(
      MaterialApp(
        theme: ProHelperTheme.lightTheme,
        home: Builder(
          builder: (context) {
            visuals = {
              for (final group in MobileModuleGroup.values)
                group: NavigationGroupVisual.resolve(context, group),
            };
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(visuals.length, MobileModuleGroup.values.length);
    expect(
      visuals.values.map((visual) => visual.icon).toSet().length,
      MobileModuleGroup.values.length,
    );
    expect(
      visuals.values.every((visual) => visual.description.isNotEmpty),
      isTrue,
    );
  });

  testWidgets('navigation components render action and module rows', (
    tester,
  ) async {
    final destination =
        MobileNavigationRegistry.destinationForRoute('warehouse')!;
    final action = MobileActionRecommendation(
      destination: destination,
      score: 200,
      reason: 'Приемка и складские операции',
      source: MobileActionSource.system,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ProHelperTheme.lightTheme,
          home: Scaffold(
            body: ListView(
              children: [
                const NavigationSectionHeader(
                  title: 'Рекомендуемые',
                  subtitle: '5 действий под текущую роль',
                  icon: Icons.auto_awesome_rounded,
                ),
                NavigationActionCard(action: action, onTap: () {}),
                NavigationGroupBlock(
                  group: MobileModuleGroup.warehouseAndSupply,
                  children: [
                    NavigationModuleRow(destination: destination, onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Рекомендуемые'), findsOneWidget);
    expect(find.text('5 действий под текущую роль'), findsOneWidget);
    expect(find.text('Склад'), findsWidgets);
    expect(find.text('Склад и снабжение'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
  });
}
