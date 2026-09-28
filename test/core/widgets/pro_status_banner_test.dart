import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';

void main() {
  const title = 'Сохранённая заявка после длительного сбоя связи';
  const description =
      'Нет соединения с сервером. Показаны данные устройства; они могут быть '
      'неактуальны до восстановления связи и успешной синхронизации.';

  testWidgets('узкий баннер показывает полный русский текст при увеличении', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                child: ProStatusBanner(
                  title: title,
                  description: description,
                  fullText: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text(description), findsOneWidget);
    expect(tester.widget<Text>(find.text(title)).maxLines, isNull);
    expect(tester.widget<Text>(find.text(description)).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('обычная ширина сохраняет исходную компоновку', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: ProStatusBanner(
                title: 'Нет соединения',
                description: 'Проверьте связь и повторите попытку.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.widget<Text>(find.text('Нет соединения')).maxLines, 2);
    expect(
      tester.getSize(find.byKey(const ValueKey('pro-status-banner-icon'))),
      const Size(40, 40),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('узкий баннер сохраняет доступное действие повтора', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                child: ProStatusBanner(
                  title: 'Не удалось обновить данные',
                  description: 'Проверьте соединение и повторите попытку.',
                  action: TextButton(
                    onPressed: () => retryCount++,
                    child: const Text('Повторить'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Повторить'));
    await tester.tap(find.text('Повторить'));
    expect(retryCount, 1);
    expect(tester.takeException(), isNull);
  });
}
