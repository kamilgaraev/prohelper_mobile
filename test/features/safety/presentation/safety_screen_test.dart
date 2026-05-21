import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_model.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';
import 'package:prohelpers_mobile/features/safety/domain/safety_provider.dart';
import 'package:prohelpers_mobile/features/safety/presentation/safety_screen.dart';

class _RecordingSafetyRepository extends SafetyRepository {
  _RecordingSafetyRepository() : super(Dio());

  Map<String, dynamic>? incidentPayload;

  @override
  Future<List<SafetyWorkPermitModel>> fetchActivePermits({
    int? projectId,
  }) async {
    return const [];
  }

  @override
  Future<List<SafetyIncidentModel>> fetchIncidents({int? projectId}) async {
    return const [];
  }

  @override
  Future<List<SafetyViolationModel>> fetchViolations({int? projectId}) async {
    return const [];
  }

  @override
  Future<SafetyIncidentModel> createIncident(Map<String, dynamic> data) async {
    incidentPayload = Map<String, dynamic>.from(data);

    return const SafetyIncidentModel(
      id: 1,
      projectId: 9,
      incidentNumber: 'HSE-I-1',
      title: 'Нет ограждения',
      incidentType: 'unsafe_condition',
      severity: 'major',
      status: 'reported',
      statusLabel: 'Зарегистрировано',
      occurredAt: '2026-05-21T09:00:00',
    );
  }
}

class _TestSafetyNotifier extends SafetyNotifier {
  _TestSafetyNotifier(super.repository) {
    state = const SafetyState(isLoading: false, projectFilter: 9);
  }

  @override
  Future<void> load() async {
    state = state.copyWith(
      isLoading: false,
      activePermits: const [],
      incidents: const [],
      violations: const [],
    );
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

  Widget buildScreen(_RecordingSafetyRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        safetyProvider.overrideWith((ref) => _TestSafetyNotifier(repository)),
      ],
      child: const MaterialApp(home: SafetyScreen()),
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('submits incident type and visible occurrence time', (
    tester,
  ) async {
    final repository = _RecordingSafetyRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).first, 'Нет ограждения');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await pumpUi(tester);
    await tester.tap(find.text('Серьезная').last);
    await pumpUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await pumpUi(tester);
    await tester.tap(find.text('Опасное условие').last);
    await pumpUi(tester);
    await tester.tap(find.text('Когда произошло'));
    await pumpUi(tester);
    await tester.tap(find.text('OK').last);
    await pumpUi(tester);
    await tester.tap(find.text('OK').last);
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.incidentPayload?['project_id'], 9);
    expect(repository.incidentPayload?['title'], 'Нет ограждения');
    expect(repository.incidentPayload?['severity'], 'major');
    expect(repository.incidentPayload?['incident_type'], 'unsafe_condition');
    expect(repository.incidentPayload?['occurred_at'], isA<String>());
    expect(repository.incidentPayload?.containsKey('metadata'), isFalse);
  });
}
