import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/quality_control_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';

class _RecordingQualityRepository extends QualityControlRepository {
  _RecordingQualityRepository() : super(Dio());

  Map<String, dynamic>? createPayload;

  @override
  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
  }) async {
    return const [];
  }

  @override
  Future<QualityDefectModel> createDefect(Map<String, dynamic> data) async {
    createPayload = Map<String, dynamic>.from(data);

    return const QualityDefectModel(
      id: 1,
      defectNumber: 'QD-1',
      title: 'Скол плитки',
      severity: 'major',
      status: 'open',
      availableActions: ['start'],
      inspectionRequired: false,
    );
  }
}

class _TestQualityNotifier extends QualityControlNotifier {
  _TestQualityNotifier(super.repository) {
    state = const QualityControlState(isLoading: false, projectFilter: 9);
  }

  @override
  Future<void> loadDefects() async {
    state = state.copyWith(isLoading: false, defects: const []);
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project project) : super(_TestProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
    );
  }
}

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildScreen(_RecordingQualityRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        qualityControlProvider.overrideWith(
          (ref) => _TestQualityNotifier(repository),
        ),
      ],
      child: const MaterialApp(home: QualityControlScreen()),
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('submits explicit inspection requirement from create form', (
    tester,
  ) async {
    final repository = _RecordingQualityRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).first, 'Скол плитки');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await pumpUi(tester);
    await tester.tap(find.text('Средняя').last);
    await pumpUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await pumpUi(tester);
    await tester.tap(find.text('Не требуется').last);
    await pumpUi(tester);
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.createPayload?['project_id'], 9);
    expect(repository.createPayload?['title'], 'Скол плитки');
    expect(repository.createPayload?['severity'], 'major');
    expect(repository.createPayload?['inspection_required'], isFalse);
  });
}
