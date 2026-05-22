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
  int? suspendedPermitId;
  String? permitStatus;
  String? incidentStatus;
  String? violationStatus;
  String? suspendReason;

  @override
  Future<List<SafetyWorkPermitModel>> fetchPermits({
    int? projectId,
    String? status,
  }) async {
    permitStatus = status;
    return _permits;
  }

  @override
  Future<List<SafetyIncidentModel>> fetchIncidents({
    int? projectId,
    String? status,
  }) async {
    incidentStatus = status;
    return const [];
  }

  @override
  Future<List<SafetyViolationModel>> fetchViolations({
    int? projectId,
    String? status,
  }) async {
    violationStatus = status;
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

  @override
  Future<SafetyWorkPermitModel> suspendPermit(
    int id, {
    required String reason,
  }) async {
    suspendedPermitId = id;
    suspendReason = reason;

    return _permits.first;
  }
}

class _TestSafetyNotifier extends SafetyNotifier {
  _TestSafetyNotifier(this.repository) : super(repository) {
    state = const SafetyState(
      isLoading: false,
      projectFilter: 9,
      permits: _permits,
    );
  }

  final _RecordingSafetyRepository repository;

  @override
  Future<void> load() async {
    repository.permitStatus = state.permitStatusFilter;
    repository.incidentStatus = state.incidentStatusFilter;
    repository.violationStatus = state.violationStatusFilter;
    state = state.copyWith(
      isLoading: false,
      permits: _permits,
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

const _permits = [
  SafetyWorkPermitModel(
    id: 11,
    projectId: 9,
    permitNumber: 'HSE-P-11',
    title: 'Высотные работы',
    permitType: 'height_work',
    riskLevel: 'high',
    status: 'active',
    statusLabel: 'Активен',
    availableActions: ['suspend', 'close'],
    validFrom: '2026-05-21T09:00:00',
    validUntil: '2026-05-21T18:00:00',
    requiredControls: ['Ограждение', 'Страховка'],
    projectName: 'Башня',
  ),
];

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

  void useLargeSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('submits incident type and visible occurrence time', (
    tester,
  ) async {
    final repository = _RecordingSafetyRepository();
    useLargeSurface(tester);

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

  testWidgets('opens permit detail and submits suspension reason', (
    tester,
  ) async {
    final repository = _RecordingSafetyRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.text('Подробнее').first);
    await pumpUi(tester);
    expect(find.text('Наряд-допуск'), findsOneWidget);
    expect(find.text('Ограждение'), findsOneWidget);

    final detailSuspendButton =
        find.text('Приостановить', skipOffstage: false).last;
    await tester.ensureVisible(detailSuspendButton);
    await tester.pump();
    await tester.tap(detailSuspendButton);
    await pumpUi(tester);
    final sheetSuspendButton =
        find.text('Приостановить', skipOffstage: false).last;
    await tester.tap(sheetSuspendButton);
    await pumpUi(tester);
    expect(repository.suspendedPermitId, isNull);

    await tester.enterText(find.byType(TextField).last, 'Сильный ветер');
    await tester.tap(sheetSuspendButton);
    await pumpUi(tester);

    expect(repository.suspendedPermitId, 11);
    expect(repository.suspendReason, 'Сильный ветер');
  });

  testWidgets('applies visible safety status filters', (tester) async {
    final repository = _RecordingSafetyRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.text('Активные').first);
    await pumpUi(tester);
    await tester.tap(find.text('Зарегистрированы').first);
    await pumpUi(tester);
    await tester.tap(find.text('Открытые').last);
    await pumpUi(tester);

    expect(repository.permitStatus, 'active');
    expect(repository.incidentStatus, 'reported');
    expect(repository.violationStatus, 'open');
  });
}
