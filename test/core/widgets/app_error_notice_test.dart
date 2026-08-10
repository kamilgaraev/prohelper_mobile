import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_notice.dart';

void main() {
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
