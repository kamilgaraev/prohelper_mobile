import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_model.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_repository.dart';
import 'package:prohelpers_mobile/features/design_management/domain/design_package_provider.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/design_management_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier() : super(_FakeProjectsRepository()) {
    final project =
        Project()
          ..serverId = 9
          ..name = 'Tower A'
          ..address = 'Site';
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

class _FakeDesignPackageRepository extends DesignPackageRepository {
  _FakeDesignPackageRepository() : super(Dio());
}

class _FakeDesignPackageNotifier extends DesignPackageNotifier {
  _FakeDesignPackageNotifier() : super(_FakeDesignPackageRepository()) {
    state = DesignPackageState(
      projectId: 9,
      page: DesignPackagePage(
        items: [
          DesignPackageModel(
            id: 42,
            projectId: 9,
            title: 'Рабочая документация',
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      ),
    );
  }

  String? action;
  String? comment;

  @override
  void syncProject(int? projectId) {
    state = state.copyWith(projectId: projectId);
  }

  @override
  Future<void> load() async {}

  @override
  Future<DesignPackageModel> fetchDetail(int id) async => _detail();

  @override
  Future<DesignPackageModel> executeAction({
    required int id,
    required DesignPackageAction action,
    String? comment,
  }) async {
    this.action = action.key;
    this.comment = comment;
    return _detail();
  }
}

void main() {
  testWidgets('shows selected project packages and runs an allowed action', (
    tester,
  ) async {
    final notifier = _FakeDesignPackageNotifier();
    final projects = _FakeProjectsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => projects),
          designPackageProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: DesignManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ПИР'), findsOneWidget);
    expect(find.text('Рабочая документация'), findsOneWidget);
    await tester.tap(find.text('Рабочая документация'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Исполнительная схема.pdf'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Исполнительная схема.pdf'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Комментарии'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Комментарии'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Результат'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Результат'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Согласовать'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Согласовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Проверено');
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(notifier.action, 'approve');
    expect(notifier.comment, 'Проверено');

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
    expect(find.text('Согласовать'), findsNothing);
    expect(find.text('Исполнительная схема.pdf'), findsNothing);
  });
}

DesignPackageModel _detail() => DesignPackageModel(
  id: 42,
  projectId: 9,
  title: 'Рабочая документация',
  stage: 'РД',
  status: 'review',
  result: const [DesignPackageValue(label: 'Проверка', value: 'Принято')],
  files: const [
    DesignPackageFile(
      id: 11,
      name: 'Исполнительная схема.pdf',
      previewUrl: 'https://files.example.test/preview',
    ),
  ],
  comments: const [DesignPackageComment(author: 'Инженер', body: 'Проверено')],
  availableActions: const [
    DesignPackageAction(
      key: 'approve',
      title: 'Согласовать',
      requiresComment: true,
    ),
  ],
);
