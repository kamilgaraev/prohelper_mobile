import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_bottom_sheet.dart';
import 'package:prohelpers_mobile/core/widgets/industrial_card.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_metric_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

void main() {
  testWidgets('pro components render under light theme', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: ProPageScaffold(
          title: 'Сегодня на объекте',
          subtitle: 'Дом 300м Царево',
          body: Column(
            children: [
              const ProStatusBanner(
                title: 'Требует внимания',
                description: 'Есть задачи, которые ждут решения.',
                tone: ProStatusTone.warning,
              ),
              const SizedBox(height: 12),
              const ProMetricTile(
                label: 'Открыто',
                value: '4',
                icon: Icons.assignment_outlined,
              ),
              const SizedBox(height: 12),
              ProActionTile(
                title: 'Создать заявку',
                subtitle: 'Передать задачу снабжению или исполнителю',
                icon: Icons.add_task_rounded,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              ProSearchFilterBar<String>(
                controller: controller,
                hintText: 'Найти',
                options: const [
                  ProFilterOption(value: 'all', label: 'Все'),
                  ProFilterOption(value: 'urgent', label: 'Срочные'),
                ],
                selectedValue: 'all',
                onFilterChanged: (_) {},
                resultLabel: 'Найдено: 2',
              ),
              const SizedBox(height: 12),
              const ProSectionHeader(
                title: 'Рабочая сводка',
                subtitle: 'Коротко по ключевым зонам',
              ),
              const ProSurface(child: Text('Поверхность')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Сегодня на объекте'), findsOneWidget);
    expect(find.text('Требует внимания'), findsOneWidget);
    expect(find.text('Создать заявку'), findsOneWidget);
    expect(find.text('Найти'), findsOneWidget);
    expect(find.text('Рабочая сводка'), findsOneWidget);
  });

  testWidgets('search filter bar exposes search label to input semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: MostTheme.lightTheme,
          home: Scaffold(
            body: ProSearchFilterBar<String>(
              controller: controller,
              hintText: 'Найти раздел',
              options: const [],
              selectedValue: 'all',
              onFilterChanged: (_) {},
            ),
          ),
        ),
      );

      final searchField = tester.widget<TextField>(find.byType(TextField));
      final semanticsRoots = _collectSemanticsRoots(
        tester.binding.rootPipelineOwner,
      );

      expect(searchField.decoration?.labelText, 'Найти раздел');
      expect(
        find.bySemanticsLabel('Поле поиска: Найти раздел'),
        findsOneWidget,
      );
      expect(
        semanticsRoots.any(
          (root) => _hasSearchFieldSemantics(root, 'Поле поиска: Найти раздел'),
        ),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('search filter bar exposes clear search action semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final controller = TextEditingController(text: 'test');
    addTearDown(controller.dispose);

    var cleared = false;

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: MostTheme.lightTheme,
          home: Scaffold(
            body: ProSearchFilterBar<String>(
              controller: controller,
              hintText: 'Найти раздел',
              options: const [],
              selectedValue: 'all',
              onFilterChanged: (_) {},
              onClearSearch: () {
                cleared = true;
                controller.clear();
              },
            ),
          ),
        ),
      );

      final clearSearch = find.bySemanticsLabel('Очистить поиск');

      expect(clearSearch, findsOneWidget);
      expect(
        tester.getSemantics(clearSearch),
        matchesSemantics(
          label: 'Очистить поиск',
          hasEnabledState: true,
          isEnabled: true,
          isButton: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(clearSearch);
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      expect(controller.text, isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('compact search filter bar keeps metadata above input', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: Scaffold(
          body: ProSearchFilterBar<String>(
            controller: controller,
            hintText: 'Найти раздел',
            options: const [],
            selectedValue: 'all',
            onFilterChanged: (_) {},
            resultLabel: 'Доступно разделов: 2',
            density: ProSearchFilterDensity.compact,
          ),
        ),
      ),
    );

    final searchField = tester.widget<TextField>(find.byType(TextField));

    expect(searchField.decoration?.isDense, isTrue);
    expect(
      searchField.decoration?.prefixIconConstraints?.minHeight,
      ProTouchTarget.comfortable,
    );
    expect(
      tester.getTopLeft(find.text('Доступно разделов: 2')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    expect(
      find.ancestor(
        of: find.text('Доступно разделов: 2'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );

    final surface = tester.widget<ProSurface>(find.byType(ProSurface));

    expect(surface.tone, ProSurfaceTone.elevated);
  });

  testWidgets('pro page scaffold anchors content below a surface header', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: const ProPageScaffold(
          title: 'Действия',
          subtitle: 'Быстрый доступ',
          body: Text('Каталог разделов'),
        ),
      ),
    );

    final theme = MostTheme.lightTheme;
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final listView = tester.widget<ListView>(find.byType(ListView));

    expect(appBar.backgroundColor, theme.colorScheme.surface);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(appBar.shape, isA<Border>());
    expect(
      listView.padding,
      const EdgeInsets.fromLTRB(
        ProSpacing.pageHorizontal,
        ProSpacing.md,
        ProSpacing.pageHorizontal,
        ProSpacing.bottomNavSafe,
      ),
    );
  });

  testWidgets('pro page scaffold keeps header readable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.6),
          ),
          child: const ProPageScaffold(
            title: 'Согласования',
            subtitle: 'Строительство склада Литер А',
            body: Text('Список согласований'),
          ),
        ),
      ),
    );

    final exception = tester.takeException();
    if (exception is FlutterError) {
      debugPrint(exception.toStringDeep());
    }

    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(exception, isNull);
    expect(appBar.toolbarHeight, greaterThan(kToolbarHeight));
    expect(find.text('Согласования'), findsOneWidget);
    expect(find.text('Строительство склада Литер А'), findsOneWidget);
  });

  testWidgets('pro bottom sheet renders title content and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.darkTheme,
        home: Scaffold(
          body: ProBottomSheet(
            title: 'Новое замечание',
            description: 'Заполните основные поля.',
            actions: [
              FilledButton(onPressed: () {}, child: const Text('Создать')),
            ],
            child: const Text('Форма'),
          ),
        ),
      ),
    );

    expect(find.text('Новое замечание'), findsOneWidget);
    expect(find.text('Форма'), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);
  });

  testWidgets('light elevated surfaces are visually separated from canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: const Scaffold(
          body: ProSurface(
            tone: ProSurfaceTone.elevated,
            child: Text('Операционный блок'),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(ProSurface),
        matching: find.byType(Material),
      ),
    );

    expect(material.color, MostTheme.lightTheme.colorScheme.surface);
    expect(material.elevation, greaterThanOrEqualTo(3));
  });

  testWidgets('light base surfaces keep cards separated from canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: const Scaffold(
          body: Center(child: ProSurface(child: Text('Surface block'))),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(ProSurface),
        matching: find.byType(Material),
      ),
    );

    expect(material.color, MostTheme.lightTheme.colorScheme.surface);
    expect(material.elevation, greaterThanOrEqualTo(1.5));
  });

  testWidgets('section headers stay compact inside cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MostTheme.lightTheme,
        home: const Scaffold(
          body: ProSectionHeader(
            title: 'Рабочая сводка',
            subtitle: 'Ключевые зоны объекта без лишних переходов.',
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Рабочая сводка'));

    expect(title.style?.fontSize, lessThanOrEqualTo(18));
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('industrial card exposes a semantic button when tappable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndustrialCard(
            onTap: () => tapped = true,
            child: const Text('Открыть заявку'),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Открыть заявку')),
      matchesSemantics(
        label: 'Открыть заявку',
        hasEnabledState: true,
        isEnabled: true,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.text('Открыть заявку'));

    expect(tapped, isTrue);
    semantics.dispose();
  });

  testWidgets('pro card exposes a semantic button when tappable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProCard(
            onTap: () => tapped = true,
            child: const Text('Открыть смену'),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Открыть смену')),
      matchesSemantics(
        label: 'Открыть смену',
        hasEnabledState: true,
        isEnabled: true,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.text('Открыть смену'));

    expect(tapped, isTrue);
    semantics.dispose();
  });

  testWidgets('pro surface exposes a semantic button when tappable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProSurface(
            onTap: () => tapped = true,
            child: const Text('Открыть раздел'),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Открыть раздел')),
      matchesSemantics(
        label: 'Открыть раздел',
        hasEnabledState: true,
        isEnabled: true,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.text('Открыть раздел'));

    expect(tapped, isTrue);
    semantics.dispose();
  });

  testWidgets(
    'pro surface can replace noisy child semantics with action label',
    (tester) async {
      final semantics = tester.ensureSemantics();

      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProSurface(
              semanticLabel: 'Открыть профиль: Иван Иванов, foreman@test.local',
              onTap: () => tapped = true,
              child: const Row(
                children: [
                  CircleAvatar(child: Text('ИИ')),
                  SizedBox(width: 12),
                  Text('Иван Иванов'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Открыть профиль: Иван Иванов, foreman@test.local',
          ),
        ),
        matchesSemantics(
          label: 'Открыть профиль: Иван Иванов, foreman@test.local',
          hasEnabledState: true,
          isEnabled: true,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('ИИ'), findsNothing);

      await tester.tap(find.text('Иван Иванов'));

      expect(tapped, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('mesh background keeps operational pages static', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeshBackground(child: Text('Контент'))),
    );

    await tester.pump();

    expect(find.text('Контент'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

List<SemanticsNode> _collectSemanticsRoots(PipelineOwner owner) {
  final roots = <SemanticsNode>[];
  final root = owner.semanticsOwner?.rootSemanticsNode;
  if (root != null) {
    roots.add(root);
  }
  owner.visitChildren((child) {
    roots.addAll(_collectSemanticsRoots(child));
  });
  return roots;
}

bool _hasSearchFieldSemantics(SemanticsNode node, String label) {
  final data = node.getSemanticsData();
  if (data.label == label &&
      node.hasFlag(SemanticsFlag.isTextField) &&
      node.hasFlag(SemanticsFlag.hasEnabledState) &&
      node.hasFlag(SemanticsFlag.isEnabled)) {
    return true;
  }

  var found = false;
  node.visitChildren((child) {
    found = _hasSearchFieldSemantics(child, label);
    return !found;
  });

  return found;
}
