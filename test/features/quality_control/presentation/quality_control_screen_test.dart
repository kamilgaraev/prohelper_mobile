import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_photo_picker.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/quality_control_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';

class _RecordingQualityRepository extends QualityControlRepository {
  _RecordingQualityRepository({this.listDefect = _defect}) : super(Dio());

  final QualityDefectModel listDefect;

  int? loadedProjectId;
  String? loadedStatus;
  String? loadedSeverity;
  bool? loadedOverdueOnly;
  int? fetchedDefectId;
  int? startedDefectId;
  int? resolvedDefectId;
  int? verifiedDefectId;
  int? rejectedDefectId;
  String? rejectedComment;
  Map<String, dynamic>? createPayload;
  String? createPhotoPath;
  String? resolvedPhotoPath;

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

    return [listDefect];
  }

  @override
  Future<QualityDefectModel> fetchDefect(int id) async {
    fetchedDefectId = id;
    return _detailDefect;
  }

  @override
  Future<QualityDefectModel> createDefect(
    Map<String, dynamic> data, {
    String? photoPath,
  }) async {
    createPayload = Map<String, dynamic>.from(data);
    createPhotoPath = photoPath;

    return const QualityDefectModel(
      id: 1,
      defectNumber: 'QD-1',
      title: 'Скол плитки',
      severity: 'major',
      status: 'open',
      availableActions: ['start'],
      inspectionRequired: false,
      workflowSummary: QualityDefectWorkflowSummary(
        status: 'open',
        availableActions: ['start'],
        problemFlags: [],
      ),
    );
  }

  @override
  Future<QualityDefectModel> startDefect(int id, {String? comment}) async {
    startedDefectId = id;
    return listDefect;
  }

  @override
  Future<QualityDefectModel> resolveDefect(
    int id, {
    String? comment,
    String? photoPath,
  }) async {
    resolvedDefectId = id;
    resolvedPhotoPath = photoPath;
    return listDefect;
  }

  @override
  Future<QualityDefectModel> verifyDefect(int id, {String? comment}) async {
    verifiedDefectId = id;
    return listDefect;
  }

  @override
  Future<QualityDefectModel> rejectDefect(
    int id, {
    required String comment,
  }) async {
    rejectedDefectId = id;
    rejectedComment = comment;
    return listDefect;
  }
}

class _FakeQualityPhotoPicker extends QualityPhotoPicker {
  _FakeQualityPhotoPicker(this.path);

  final String? path;

  @override
  Future<String?> pickInitialPhoto() async => path;

  @override
  Future<String?> pickResultPhoto() async => path;
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
  workflowSummary: QualityDefectWorkflowSummary(
    status: 'open',
    availableActions: ['start', 'resolve'],
    problemFlags: [],
  ),
);

const _reviewDefect = QualityDefectModel(
  id: 4,
  defectNumber: 'QD-4',
  title: 'Повторная проверка',
  severity: 'critical',
  severityLabel: 'Критический',
  status: 'ready_for_review',
  statusLabel: 'На проверке',
  availableActions: ['verify', 'reject'],
  inspectionRequired: true,
  workflowSummary: QualityDefectWorkflowSummary(
    status: 'ready_for_review',
    availableActions: ['verify', 'reject'],
    problemFlags: [],
  ),
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
  availableActions: ['verify', 'reject'],
  inspectionRequired: true,
  workflowSummary: QualityDefectWorkflowSummary(
    status: 'ready_for_review',
    availableActions: ['verify', 'reject'],
    problemFlags: [],
  ),
  photos: [
    QualityDefectPhotoModel(
      id: 8,
      type: 'after',
      url: 'https://cdn.example.test/qc-after.jpg',
      previewUrl: 'https://cdn.example.test/qc-after-preview.jpg',
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

  Widget buildScreen(
    _RecordingQualityRepository repository, {
    QualityPhotoPicker? photoPicker,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        qualityControlProvider.overrideWith(
          (ref) => QualityControlNotifier(repository),
        ),
        if (photoPicker != null)
          qualityPhotoPickerProvider.overrideWith((ref) => photoPicker),
      ],
      child: const MaterialApp(home: QualityControlScreen()),
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
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.createPayload?['project_id'], 9);
    expect(repository.createPayload?['title'], 'Скол плитки');
    expect(repository.createPayload?['severity'], 'major');
    expect(repository.createPayload?['inspection_required'], isFalse);
  });

  testWidgets('attaches before photo when creating quality defect', (
    tester,
  ) async {
    final repository = _RecordingQualityRepository();

    await tester.pumpWidget(
      buildScreen(
        repository,
        photoPicker: _FakeQualityPhotoPicker('/tmp/before-quality.jpg'),
      ),
    );
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
    await tester.ensureVisible(find.text('Добавить фото до исправления'));
    await tester.pump();
    await tester.tap(find.text('Добавить фото до исправления'));
    await pumpUi(tester);
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await pumpUi(tester);

    expect(repository.createPayload?['title'], 'Скол плитки');
    expect(repository.createPhotoPath, '/tmp/before-quality.jpg');
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
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Исправлено'), findsOneWidget);
  });

  testWidgets('verifies and rejects quality review with visible decision', (
    tester,
  ) async {
    final repository = _RecordingQualityRepository(listDefect: _reviewDefect);
    useLargeSurface(tester);

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    await tester.tap(find.text('Подтвердить').first);
    await pumpUi(tester);
    await tester.tap(find.text('Подтвердить').last);
    await pumpUi(tester);

    expect(repository.verifiedDefectId, 4);

    await tester.ensureVisible(find.text('Вернуть').first);
    await tester.pump();
    await tester.tap(find.text('Вернуть').first);
    await pumpUi(tester);
    await tester.ensureVisible(find.text('Вернуть').last);
    await tester.pump();
    await tester.tap(find.text('Вернуть').last);
    await pumpUi(tester);

    expect(repository.rejectedDefectId, isNull);

    await tester.enterText(find.byType(TextField).last, 'Нужно переделать');
    await tester.ensureVisible(find.text('Вернуть').last);
    await tester.pump();
    await tester.tap(find.text('Вернуть').last);
    await pumpUi(tester);

    expect(repository.rejectedDefectId, 4);
    expect(repository.rejectedComment, 'Нужно переделать');
  });
}
