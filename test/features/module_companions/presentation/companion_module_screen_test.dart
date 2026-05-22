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

class _FakeCompanionRepository extends CompanionModuleRepository {
  _FakeCompanionRepository() : super(Dio());
}

class _FakeCompanionNotifier extends CompanionModuleNotifier {
  _FakeCompanionNotifier()
    : super(_FakeCompanionRepository(), 'contract-management') {
    _setLoadedState();
  }

  String? query;
  String? status;
  String? action;

  @override
  void syncProject(int? projectId) {
    state = state.copyWith(projectId: projectId);
  }

  @override
  Future<void> load() async {
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
    return CompanionModuleDetailModel.fromJson(companionDetailJson());
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

  void _setLoadedState({int? projectId}) {
    state = CompanionModuleState(
      isLoading: false,
      projectId: projectId,
      list: CompanionModuleListModel.fromJson(companionListJson()),
    );
  }
}

void main() {
  Widget buildApp(Widget child, _FakeCompanionNotifier notifier) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith((ref) => _FakeProjectsNotifier()),
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

    await tester.enterText(find.byKey(const Key('companion-search')), 'Tower');
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.query, 'Tower');

    await tester.tap(find.text('Черновик'));
    await tester.pump();
    expect(notifier.status, 'draft');
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
    expect(find.text('Связанные записи'), findsOneWidget);
    expect(find.text('Отправить на оценку'), findsOneWidget);

    await tester.tap(find.text('Отправить на оценку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выполнить'));
    await tester.pumpAndSettle();

    expect(notifier.action, 'submit');
  });
}
