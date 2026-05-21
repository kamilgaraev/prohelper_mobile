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

  int? loadedProjectId;
  String? loadedStatus;
  String? loadedSeverity;
  bool? loadedOverdueOnly;
  int? fetchedDefectId;
  Map<String, dynamic>? createPayload;

  @override
  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async {
    loadedProjectId = projectId;
    loadedStatus = status;
    loadedSeverity = severity;
    loadedOverdueOnly = overdueOnly;

    return [_defect];
  }

  @override
  Future<QualityDefectModel> fetchDefect(int id) async {
    fetchedDefectId = id;
    return _detailDefect;
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

const _defect = QualityDefectModel(
  id: 3,
  defectNumber: 'QD-3',
  title: 'Скол плитки',
  severity: 'major',
  severityLabel: 'Существенный',
  status: 'open',
  statusLabel: 'Открыт',
  availableActions: ['start', 'resolve'],
  inspectionRequired: true,
);

const _detailDefect = QualityDefectModel(
  id: 3,
  defectNumber: 'QD-3',
  title: 'Скол плитки',
  description: 'Повреждение кромки плитки',
  severity: 'major',
  severityLabel: 'Существенный',
  status: 'ready_for_review',
  statusLabel: 'На проверке',
  locationName: 'Секция А',
  dueDate: '2026-05-22',
  availableActions: ['resolve'],
  inspectionRequired: true,
  photos: [
    QualityDefectPhotoModel(
      id: 8,
      type: 'after',
      url: 'https://cdn.example.test/qc-after.jpg',
      caption: 'Фото результата',
      createdAt: '2026-05-22T10:00:00Z',
    ),
  ],
  statusHistory: [
    QualityDefectHistoryModel(
      id: 9,
      fromStatus: 'in_progress',
      toStatus: 'ready_for_review',
      comment: 'Исправлено',
      changedAt: '2026-05-22T11:00:00Z',
    ),
  ],
);

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
          (ref) => QualityControlNotifier(repository),
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

  testWidgets('applies visible quality filters to defect query', (
    tester,
  ) async {
    final repository = _RecordingQualityRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    expect(repository.loadedProjectId, 9);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Проверка'));
    await pumpUi(tester);
    expect(repository.loadedStatus, 'ready_for_review');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Критичная'));
    await pumpUi(tester);
    expect(repository.loadedSeverity, 'critical');

    await tester.tap(find.widgetWithText(FilterChip, 'Просроченные'));
    await pumpUi(tester);
    expect(repository.loadedOverdueOnly, isTrue);
  });

  testWidgets('opens quality defect detail with photos and history', (
    tester,
  ) async {
    final repository = _RecordingQualityRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.text('Подробнее').first);
    await pumpUi(tester);

    expect(repository.fetchedDefectId, 3);
    expect(find.text('Замечание качества'), findsOneWidget);
    expect(find.text('Фото результата'), findsOneWidget);
    expect(find.text('https://cdn.example.test/qc-after.jpg'), findsOneWidget);
    expect(find.text('Исправлено'), findsOneWidget);
  });
}
