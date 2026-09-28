import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_notice.dart';

void main() {
  testWidgets('announces one error and keeps the close action accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => AppErrorNotice.showMessage(
                        context,
                        'Нет соединения.',
                      ),
                  child: const Text('Показать ошибку'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Показать ошибку'));
    await tester.pump();

    expect(find.text('Нет соединения.'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('app-error-notice-message')))
          .label,
      'Ошибка: Нет соединения.',
    );
    final closeButton =
        tester
            .getSemantics(find.byTooltip('Закрыть сообщение'))
            .getSemanticsData();
    expect(closeButton.flagsCollection.isButton, isTrue);
    expect(closeButton.hasAction(ui.SemanticsAction.tap), isTrue);

    await tester.tap(find.byTooltip('Закрыть сообщение'));
    await tester.pump();
    expect(find.byKey(const Key('app-error-notice')), findsNothing);
    semantics.dispose();
  });

  testWidgets('shows an error above an open modal bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) {
                      return SizedBox(
                        height: 400,
                        child: Center(
                          child: FilledButton(
                            onPressed:
                                () => AppErrorNotice.showMessage(
                                  sheetContext,
                                  'Проверьте показатели смены.',
                                ),
                            child: const Text('Показать ошибку'),
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Text('Открыть форму'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Открыть форму'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать ошибку'));
    await tester.pump();

    expect(
      find.text('Проверьте показатели смены.').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Показать ошибку'), findsOneWidget);

    await tester.tap(find.byTooltip('Закрыть сообщение'));
    await tester.pump();
  });
}
