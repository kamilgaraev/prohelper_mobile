import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_hierarchy_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_hierarchy_screen.dart';

class _Projects extends ProjectsNotifier {
  _Projects() : super(ProjectsRepository(Dio())) {
    select(52);
  }
  void select(int id) {
    state = state.copyWith(
      selectedProject:
          Project()
            ..serverId = id
            ..name = 'Проект',
    );
  }
}

class _Hierarchy extends ProjectHierarchyRepository {
  _Hierarchy({this.canManage = true}) : super(Dio());
  final bool canManage;
  int calls = 0;
  int? savedRoot;
  Map<int, int>? savedParents;
  @override
  Future<ProjectHierarchy> load(int projectId) async => ProjectHierarchy(
    configured: false,
    canManage: canManage,
    participants: const [
      HierarchyParticipant(id: 1, name: 'Генподрядчик'),
      HierarchyParticipant(id: 2, name: 'Подрядчик', parentId: 1),
    ],
  );
  @override
  Future<ProjectHierarchy> save(
    int projectId,
    int rootId,
    Map<int, int> parents,
  ) async {
    calls++;
    savedRoot = rootId;
    savedParents = Map.from(parents);
    return ProjectHierarchy(
      configured: true,
      canManage: true,
      rootId: rootId,
      participants: const [
        HierarchyParticipant(id: 1, name: 'Генподрядчик'),
        HierarchyParticipant(id: 2, name: 'Подрядчик', parentId: 1),
      ],
    );
  }
}

void main() {
  testWidgets('missing root is explained and valid hierarchy saves once', (
    tester,
  ) async {
    final repository = _Hierarchy();
    final projects = _Projects();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectHierarchyRepositoryProvider.overrideWithValue(repository),
          projectsProvider.overrideWith((ref) => projects),
        ],
        child: const MaterialApp(home: ProjectHierarchyScreen(projectId: 52)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить иерархию'));
    await tester.tap(find.text('Сохранить иерархию'));
    await tester.pumpAndSettle();
    expect(
      find.text('Выберите корневую компанию — верхнего участника проекта.'),
      findsOneWidget,
    );
    expect(repository.calls, 0);
    final root = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<int> &&
          widget.decoration.labelText == 'Корневая компания',
    );
    await tester.ensureVisible(root);
    await tester.tap(root);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Генподрядчик').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить иерархию'));
    await tester.tap(find.text('Сохранить иерархию'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(repository.savedRoot, 1);
    expect(repository.savedParents, {2: 1});
    expect(find.text('Иерархия проекта сохранена.'), findsOneWidget);
    projects.select(53);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Сохранить иерархию'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('viewer sees hierarchy without mutation controls', (
    tester,
  ) async {
    final repository = _Hierarchy(canManage: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectHierarchyRepositoryProvider.overrideWithValue(repository),
          projectsProvider.overrideWith((ref) => _Projects()),
        ],
        child: const MaterialApp(home: ProjectHierarchyScreen(projectId: 52)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Сохранить иерархию'), findsNothing);
    expect(
      find.textContaining('правом управления организациями'),
      findsOneWidget,
    );
    expect(repository.calls, 0);
  });
}
