import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/app_action_buttons.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_form_section.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_permission_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_success_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

void main() {
  Widget buildWidget(Widget child) {
    return MaterialApp(
      theme: MostTheme.lightTheme,
      darkTheme: MostTheme.darkTheme,
      home: Scaffold(body: child),
    );
  }

  testWidgets('empty state uses business copy', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        const AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Нет заявок',
          description: 'Создайте первую заявку для выбранного объекта.',
        ),
      ),
    );

    expect(find.text('Нет заявок'), findsOneWidget);
    expect(
      find.text('Создайте первую заявку для выбранного объекта.'),
      findsOneWidget,
    );
    expect(find.textContaining('fallback'), findsNothing);
  });

  testWidgets('error state exposes retry action', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      buildWidget(
        AppErrorState(
          title: 'Не удалось загрузить заявки',
          description: 'Проверьте подключение и повторите попытку.',
          onRetry: () => retryCount++,
        ),
      ),
    );

    await tester.tap(find.text('Повторить'));
    await tester.pump();

    expect(retryCount, 1);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('loading state does not shift layout', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        const SizedBox(
          width: 360,
          child: AppLoadingState(message: 'Загружаем заявки', minHeight: 240),
        ),
      ),
    );

    final initialSize = tester.getSize(
      find.byKey(const ValueKey('app-loading-state-layout')),
    );
    final initialSurfaceSize = tester.getSize(
      find.descendant(
        of: find.byType(ProSurface),
        matching: find.byType(Material),
      ),
    );

    await tester.pumpWidget(
      buildWidget(
        const SizedBox(
          width: 360,
          child: AppLoadingState(
            message: 'Загружаем данные по выбранному объекту',
            minHeight: 240,
          ),
        ),
      ),
    );

    final updatedSize = tester.getSize(
      find.byKey(const ValueKey('app-loading-state-layout')),
    );
    final updatedSurfaceSize = tester.getSize(
      find.descendant(
        of: find.byType(ProSurface),
        matching: find.byType(Material),
      ),
    );

    expect(initialSize.height, 240);
    expect(updatedSize.height, initialSize.height);
    expect(updatedSize.width, initialSize.width);
    expect(initialSurfaceSize.width, lessThanOrEqualTo(328));
    expect(updatedSurfaceSize.width, initialSurfaceSize.width);
  });

  testWidgets('loading state exposes message once to accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        buildWidget(
          const SizedBox(
            width: 360,
            child: AppLoadingState(message: 'Загружаем заявки', minHeight: 240),
          ),
        ),
      );

      final labels = _collectSemanticsLabels(tester.binding.rootPipelineOwner);

      expect(labels.any((label) => label.contains('Загружаем заявки')), isTrue);
      expect(
        labels.where(
          (label) => _countOccurrences(label, 'Загружаем заявки') > 1,
        ),
        isEmpty,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('loading and error states are anchored in card surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildWidget(
        Column(
          children: [
            const AppLoadingState(message: 'Загружаем разделы', minHeight: 180),
            AppErrorState(
              title: 'Не удалось загрузить разделы',
              description: 'Сервер не ответил вовремя.',
              onRetry: () {},
              minHeight: 180,
            ),
          ],
        ),
      ),
    );

    expect(
      find.ancestor(
        of: find.text('Загружаем разделы'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Не удалось загрузить разделы'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('primary button shows busy state', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      buildWidget(
        AppPrimaryActionButton(
          label: 'Сохранить',
          onPressed: () => pressed = true,
          isBusy: true,
        ),
      ),
    );

    await tester.tap(find.text('Сохранить'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(pressed, isFalse);
  });

  testWidgets('supporting states render expected content', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        const SingleChildScrollView(
          child: Column(
            children: [
              AppPermissionState(),
              AppSuccessBanner(message: 'Заявка отправлена в работу.'),
              AppFormSection(
                title: 'Материалы',
                description: 'Добавьте позиции для заявки.',
                children: [Text('Позиция 1')],
              ),
              AppSecondaryActionButton(label: 'Отменить', onPressed: null),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Раздел недоступен'), findsOneWidget);
    expect(find.text('Заявка отправлена в работу.'), findsOneWidget);
    expect(find.text('Материалы'), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);
  });
}

List<String> _collectSemanticsLabels(PipelineOwner owner) {
  final labels = <String>[];
  final root = owner.semanticsOwner?.rootSemanticsNode;

  if (root != null) {
    _visitSemanticsNode(root, labels);
  }

  owner.visitChildren((child) {
    labels.addAll(_collectSemanticsLabels(child));
  });

  return labels.where((label) => label.isNotEmpty).toList(growable: false);
}

void _visitSemanticsNode(SemanticsNode node, List<String> labels) {
  labels.add(node.getSemanticsData().label);
  node.visitChildren((child) {
    _visitSemanticsNode(child, labels);
    return true;
  });
}

int _countOccurrences(String source, String pattern) {
  var count = 0;
  var start = 0;

  while (true) {
    final index = source.indexOf(pattern, start);
    if (index == -1) {
      return count;
    }

    count += 1;
    start = index + pattern.length;
  }
}
