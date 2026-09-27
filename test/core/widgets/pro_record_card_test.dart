import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/widgets/pro_record_card.dart';

void main() {
  testWidgets('record card gives long text full width on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title = 'Материалы_для_северного_корпуса_секции_А';
    const subtitle = 'Поставка_бетона_по_заявке_2026_001';

    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
        home: Scaffold(
          body: ProRecordCard(
            title: title,
            subtitle: subtitle,
            icon: Icons.description_outlined,
          ),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text(subtitle), findsOneWidget);
    final titleRect = tester.getRect(find.text(title));
    final subtitleRect = tester.getRect(find.text(subtitle));
    expect(titleRect.width, greaterThan(250));
    expect(subtitleRect.width, greaterThan(250));
    expect(subtitleRect.top, greaterThanOrEqualTo(titleRect.bottom));
    expect(tester.widget<Text>(find.text(title)).maxLines, isNull);
    expect(tester.widget<Text>(find.text(subtitle)).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });
}
