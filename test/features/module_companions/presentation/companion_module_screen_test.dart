import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_model.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_repository.dart';
import 'package:prohelpers_mobile/features/module_companions/domain/companion_module_provider.dart';
import 'package:prohelpers_mobile/features/module_companions/presentation/companion_module_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

import '../companion_module_test_data.dart';

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier({bool hasSelectedProject = true})
    : super(_FakeProjectsRepository()) {
    final project =
        Project()
          ..serverId = 9
          ..name = 'Tower A'
          ..address = 'Site';
    state = ProjectsState(
      isLoading: false,
      projects: hasSelectedProject ? [project] : const [],
      selectedProject: hasSelectedProject ? project : null,
    );
  }
}

class _FakeCompanionRepository extends CompanionModuleRepository {
  _FakeCompanionRepository() : super(Dio());
}

class _FakeCompanionNotifier extends CompanionModuleNotifier {
  _FakeCompanionNotifier({String moduleSlug = 'contract-management'})
    : _moduleSlug = moduleSlug,
      super(_FakeCompanionRepository(), moduleSlug) {
    _setLoadedState(moduleSlug: moduleSlug);
  }

  final String _moduleSlug;
  String? query;
  String? status;
  String? action;
  String? executiveAction;
  int? executiveDocumentId;
  int loadCalls = 0;

  @override
  void syncProject(int? projectId) {
    state = state.copyWith(projectId: projectId);
  }

  @override
  Future<void> load() async {
    loadCalls++;
    _setLoadedState(projectId: state.projectId);
  }

  @override
  Future<void> setQuery(String query) async {
    this.query = query;
  }

  @override
  Future<void> setStatus(String? status) async {
    this.status = status;
  }

  @override
  Future<CompanionModuleDetailModel> fetchDetail(int id) async {
    return CompanionModuleDetailModel.fromJson(
      companionDetailJson(slug: _moduleSlug),
    );
  }

  @override
  Future<CompanionModuleDetailModel> executeAction({
    required int id,
    required String action,
    String? comment,
  }) async {
    this.action = action;
    return CompanionModuleDetailModel.fromJson(companionDetailJson());
  }

  @override
  Future<CompanionModuleDetailModel> executeExecutiveDocumentAction({
    required int documentId,
    required String action,
    String? comment,
    int? versionId,
    String? severity,
  }) async {
    executiveAction = action;
    executiveDocumentId = documentId;
    return CompanionModuleDetailModel.fromJson(
      companionDetailJson(slug: _moduleSlug),
    );
  }

  void _setLoadedState({int? projectId, String? moduleSlug}) {
    state = CompanionModuleState(
      isLoading: false,
      projectId: projectId,
      list: CompanionModuleListModel.fromJson(
        companionListJson(slug: moduleSlug ?? _moduleSlug),
      ),
    );
  }
}

void main() {
  Widget buildApp(
    Widget child,
    _FakeCompanionNotifier notifier, {
    _FakeProjectsNotifier? projectsNotifier,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => projectsNotifier ?? _FakeProjectsNotifier(),
        ),
        companionModuleProvider.overrideWith((ref, moduleSlug) => notifier),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('shows companion list screen and runs filters', (tester) async {
    final notifier = _FakeCompanionNotifier();

    await tester.pumpWidget(
      buildApp(
        const CompanionModuleScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
        ),
        notifier,
      ),
    );
    await tester.pump();

    expect(find.text('Договоры'), findsWidgets);
    expect(find.text('C-001'), findsOneWidget);
    expect(find.text('Активно'), findsWidgets);
    expect(find.bySemanticsLabel('Обновить список'), findsOneWidget);
    expect(find.text('100 000,00'), findsOneWidget);
    expect(find.text('100000.00'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('companion-search')), 'Tower');
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.query, 'Tower');

    await tester.tap(find.text('Черновик'));
    await tester.pump();
    expect(notifier.status, 'draft');
  });

  testWidgets('requires a selected project for field workflow lists', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleScreen(
          moduleSlug: 'change-management',
          title: 'Изменения',
          icon: Icons.change_circle_outlined,
          requiresProject: true,
        ),
        notifier,
        projectsNotifier: _FakeProjectsNotifier(hasSelectedProject: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Выберите объект'), findsOneWidget);
    expect(find.text('C-001'), findsNothing);
    expect(notifier.loadCalls, 0);
  });

  testWidgets('shows detail screen and executes action', (tester) async {
    final notifier = _FakeCompanionNotifier();

    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'contract-management',
          title: 'Договоры',
          icon: Icons.assignment_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Основное'), findsOneWidget);
    expect(find.text('Отправить на оценку'), findsOneWidget);

    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(notifier.action, 'submit');
    await tester.scrollUntilVisible(
      find.text('Связанные записи'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Связанные записи'), findsOneWidget);
  });

  testWidgets('shows files, comments, result and permitted executive actions', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier(
      moduleSlug: 'executive-documentation',
    );

    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'executive-documentation',
          title: 'Исполнительная документация',
          icon: Icons.description_outlined,
          itemId: 42,
        ),
        notifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Исполнительная схема.pdf'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Файлы'), findsOneWidget);
    expect(find.text('Исполнительная схема.pdf'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Комментарии'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Комментарии'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Проверено'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Проверено'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Принято'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Принято'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Передано на проверку'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Передано на проверку'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Исполнительные документы'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Исполнительные документы'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Согласовать'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Согласовать'), findsOneWidget);

    await tester.tap(find.text('Согласовать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(notifier.executiveAction, 'approve');
    expect(notifier.executiveDocumentId, 7);
  });

  testWidgets('hides detail and actions after selected project changes', (
    tester,
  ) async {
    final notifier = _FakeCompanionNotifier();
    final projects = _FakeProjectsNotifier();
    await tester.pumpWidget(
      buildApp(
        const CompanionModuleDetailScreen(
          moduleSlug: 'change-management',
          title: 'Изменения',
          icon: Icons.change_circle_outlined,
          itemId: 42,
          requiresProject: true,
          projectId: 9,
        ),
        notifier,
        projectsNotifier: projects,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Основное'), findsOneWidget);

    final otherProject =
        Project()
          ..serverId = 10
          ..name = 'Tower B'
          ..address = 'Other site';
    projects.state = ProjectsState(
      isLoading: false,
      projects: [otherProject],
      selectedProject: otherProject,
    );
    await tester.pumpAndSettle();

    expect(find.text('Объект изменился'), findsOneWidget);
    expect(find.text('Отправить на оценку'), findsNothing);
    expect(find.text('Основное'), findsNothing);
    expect(find.text('Исполнительная схема.pdf'), findsNothing);
  });
}
