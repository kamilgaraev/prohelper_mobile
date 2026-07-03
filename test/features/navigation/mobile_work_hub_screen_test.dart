import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';
import 'package:prohelpers_mobile/features/navigation/presentation/mobile_work_hub_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _FakeModulesRepository extends ModulesRepository {
  _FakeModulesRepository() : super(Dio());

  @override
  Future<List<MobileModuleModel>> fetchModules() async => const [];
}

class _FakeModulesNotifier extends ModulesNotifier {
  _FakeModulesNotifier(List<MobileModuleModel> modules)
    : super(_FakeModulesRepository(), canLoad: false) {
    state = ModulesState(isLoading: false, modules: modules, error: null);
  }
}

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier(Project project) : super(_FakeProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
      error: null,
    );
  }
}

void main() {
  testWidgets('показывает рабочие разделы внутри карточных групп', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Работа'), findsOneWidget);
    expect(find.text('Строительство склада Литер А'), findsOneWidget);
    expect(find.text('Найти раздел'), findsOneWidget);
    final searchBar = tester.widget<ProSearchFilterBar<String>>(
      find.byType(ProSearchFilterBar<String>),
    );

    expect(searchBar.density, ProSearchFilterDensity.compact);
    expect(find.text('Доступно разделов: 3'), findsOneWidget);

    for (final title in const [
      'Полевые работы',
      'Склад и снабжение',
      'Согласования и документы',
    ]) {
      expect(
        find.ancestor(of: find.text(title), matching: find.byType(ProSurface)),
        findsOneWidget,
      );
    }

    expect(find.text('Явка'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(find.text('Процессы'), findsOneWidget);
  });

  testWidgets('фильтрует рабочие разделы без потери карточной оболочки', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'склад');
    await tester.pumpAndSettle();

    expect(find.text('Найдено: 1'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(find.text('Явка'), findsNothing);
    expect(find.text('Процессы'), findsNothing);
    expect(
      find.ancestor(
        of: find.text('Склад и снабжение'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('показывает быстрый сброс, когда поиск рабочих разделов пустой', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pumpAndSettle();

    expect(find.text('Найдено: 0'), findsOneWidget);
    expect(find.text('Разделы не найдены'), findsOneWidget);
    expect(find.text('Сбросить поиск'), findsOneWidget);

    await tester.tap(find.text('Сбросить поиск'));
    await tester.pumpAndSettle();

    expect(find.text('Доступно разделов: 3'), findsOneWidget);
    expect(find.text('Разделы не найдены'), findsNothing);
    expect(find.text('Явка'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(find.text('Процессы'), findsOneWidget);
  });

  testWidgets('рабочий hub проходит базовые accessibility-гайдлайны', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}

Widget _buildScreen({List<MobileModuleModel> modules = _workModules}) {
  final project =
      Project()
        ..serverId = 15
        ..name = 'Строительство склада Литер А'
        ..address = 'Казань'
        ..myRole = 'Прораб';

  return ProviderScope(
    overrides: [
      modulesProvider.overrideWith((ref) => _FakeModulesNotifier(modules)),
      projectsProvider.overrideWith((ref) => _FakeProjectsNotifier(project)),
    ],
    child: MaterialApp(
      theme: MostTheme.lightTheme,
      home: const MobileWorkHubScreen(),
    ),
  );
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _workModules = [
  MobileModuleModel(
    slug: 'workforce-management',
    title: 'Явка сотрудников',
    description: 'Отметить или подтвердить явку',
    icon: 'badge',
    supportedOnMobile: true,
    order: 1,
    route: 'workforce_management',
  ),
  MobileModuleModel(
    slug: 'basic-warehouse',
    title: 'Склад',
    description: 'Остатки и движения',
    icon: 'warehouse',
    supportedOnMobile: true,
    order: 2,
    route: 'warehouse',
  ),
  MobileModuleModel(
    slug: 'workflow-management',
    title: 'Рабочие процессы',
    description: 'Проверить согласования',
    icon: 'hub',
    supportedOnMobile: true,
    order: 3,
    route: 'workflow_management',
  ),
];
