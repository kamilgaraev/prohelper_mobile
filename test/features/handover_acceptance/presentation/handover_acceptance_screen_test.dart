import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_model.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/domain/handover_acceptance_provider.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _RecordingHandoverRepository extends HandoverAcceptanceRepository {
  _RecordingHandoverRepository() : super(Dio());

  Map<String, dynamic>? findingPayload;
  String? resolutionComment;
  String? rejectReason;
  int? rejectedScopeId;

  AcceptanceScopeModel get scope => const AcceptanceScopeModel(
    id: 5,
    projectId: 9,
    title: 'Секция А',
    status: 'findings_open',
    workflowSummary: HandoverWorkflowSummary(
      status: 'findings_open',
      availableActions: [
        'create_finding',
        'resolve_findings',
        'ready_for_reinspection',
        'reject',
      ],
      problemFlags: [],
    ),
    sessions: [
      AcceptanceSessionModel(
        id: 7,
        status: 'findings_open',
        findings: [
          AcceptanceFindingModel(
            id: 11,
            sessionId: 7,
            title: 'Скол плитки',
            severity: 'major',
            status: 'open',
          ),
        ],
      ),
    ],
    findings: [
      AcceptanceFindingModel(
        id: 11,
        sessionId: 7,
        title: 'Скол плитки',
        severity: 'major',
        status: 'open',
      ),
    ],
  );

  @override
  Future<List<AcceptanceScopeModel>> fetchScopes({int? projectId}) async {
    return [scope];
  }

  @override
  Future<AcceptanceFindingModel> createFinding(
    int sessionId,
    Map<String, dynamic> data,
  ) async {
    findingPayload = Map<String, dynamic>.from(data);

    return AcceptanceFindingModel(
      id: 12,
      sessionId: sessionId,
      title: data['title'].toString(),
      severity: data['severity'].toString(),
      status: 'open',
    );
  }

  @override
  Future<AcceptanceFindingModel> resolveFinding(
    int findingId, {
    required String resolutionComment,
  }) async {
    this.resolutionComment = resolutionComment;

    return AcceptanceFindingModel(
      id: findingId,
      sessionId: 7,
      title: 'Скол плитки',
      severity: 'major',
      status: 'resolved',
    );
  }

  @override
  Future<AcceptanceScopeModel> rejectScope(
    int scopeId, {
    required String reason,
  }) async {
    rejectedScopeId = scopeId;
    rejectReason = reason;
    return scope;
  }
}

class _TestHandoverNotifier extends HandoverAcceptanceNotifier {
  _TestHandoverNotifier(this.repository) : super(repository) {
    state = HandoverAcceptanceState(
      isLoading: false,
      projectFilter: 9,
      scopes: [repository.scope],
    );
  }

  final _RecordingHandoverRepository repository;

  @override
  Future<void> loadScopes() async {
    state = state.copyWith(isLoading: false, scopes: [repository.scope]);
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

  Widget buildScreen(_RecordingHandoverRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        handoverAcceptanceProvider.overrideWith(
          (ref) => _TestHandoverNotifier(repository),
        ),
      ],
      child: const MaterialApp(home: HandoverAcceptanceScreen()),
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

  testWidgets('submits explicit severity and quality-defect decision', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).first, 'Неровная плитка');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await pumpUi(tester);
    await tester.tap(find.text('Средняя').last);
    await pumpUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await pumpUi(tester);
    await tester.tap(find.text('Создать').last);
    await pumpUi(tester);
    await tester.tap(find.byType(DropdownButtonFormField<bool>).last);
    await pumpUi(tester);
    await tester.tap(find.text('Не требуется').last);
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.findingPayload?['title'], 'Неровная плитка');
    expect(repository.findingPayload?['severity'], 'major');
    expect(repository.findingPayload?['create_quality_defect'], isTrue);
    expect(
      repository.findingPayload?['quality_defect_inspection_required'],
      isFalse,
    );
  });

  testWidgets('requires resolution comment before resolving finding', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byIcon(Icons.task_alt_rounded));
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.resolutionComment, isNull);

    await tester.enterText(find.byType(TextField).first, 'Плитка заменена');
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.resolutionComment, 'Плитка заменена');
  });

  testWidgets('requires rejection reason before rejecting scope', (
    tester,
  ) async {
    final repository = _RecordingHandoverRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.byIcon(Icons.block_outlined));
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.rejectedScopeId, isNull);

    await tester.enterText(find.byType(TextField).first, 'Нужно переделать');
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.rejectedScopeId, 5);
    expect(repository.rejectReason, 'Нужно переделать');
  });
}
