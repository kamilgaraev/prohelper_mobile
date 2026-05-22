import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_entry_model.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_tracking_repository.dart';
import 'package:prohelpers_mobile/features/time_tracking/domain/time_tracking_provider.dart';
import 'package:prohelpers_mobile/features/time_tracking/presentation/time_tracking_screen.dart';

class _RecordingTimeTrackingRepository extends TimeTrackingRepository {
  _RecordingTimeTrackingRepository() : super(Dio());

  String? loadedDate;
  int? loadedProjectId;
  int? fetchedEntryId;
  String? startedTitle;
  String? startedTime;
  double? manualHours;
  int? submittedEntryId;
  int? correctedEntryId;
  double? correctedHours;
  String? correctionReason;

  @override
  Future<DailyTimeSummaryModel> fetchDailySummary({
    required String date,
    required int projectId,
  }) async {
    loadedDate = date;
    loadedProjectId = projectId;

    return DailyTimeSummaryModel(
      date: date,
      projectId: projectId,
      entries: const [_entry, _rejectedEntry],
      activeTimer: null,
      totals: const TimeTotalsModel(
        totalHours: 5.5,
        billableHours: 3.5,
        entriesCount: 2,
        byStatus: {'draft': 1, 'submitted': 0, 'approved': 0, 'rejected': 1},
      ),
      approvalStatus: const {
        'draft': 1,
        'submitted': 0,
        'approved': 0,
        'rejected': 1,
      },
    );
  }

  @override
  Future<TimeEntryModel> fetchEntry(int id) async {
    fetchedEntryId = id;
    return _rejectedEntry;
  }

  @override
  Future<TimeEntryModel> startTimer({
    required int projectId,
    required String workDate,
    required String startTime,
    required String title,
    required bool isBillable,
    String? description,
  }) async {
    startedTitle = title;
    startedTime = startTime;
    return _entry;
  }

  @override
  Future<TimeEntryModel> createManualEntry({
    required int projectId,
    required String workDate,
    required double hoursWorked,
    required String title,
    required bool isBillable,
    String? startTime,
    String? endTime,
    double? breakTime,
    String? description,
  }) async {
    manualHours = hoursWorked;
    return _entry;
  }

  @override
  Future<TimeEntryModel> submitEntry(int id) async {
    submittedEntryId = id;
    return _entry;
  }

  @override
  Future<TimeEntryModel> submitCorrection({
    required int id,
    required double hoursWorked,
    required String correctionReason,
  }) async {
    correctedEntryId = id;
    correctedHours = hoursWorked;
    this.correctionReason = correctionReason;
    return _entry;
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

const _approval = TimeEntryApprovalSummaryModel(
  status: 'draft',
  statusLabel: 'Черновик',
);

const _rejectedApproval = TimeEntryApprovalSummaryModel(
  status: 'rejected',
  statusLabel: 'Отклонено',
  rejectionReason: 'Не совпали часы',
);

const _entry = TimeEntryModel(
  id: 17,
  organizationId: 4,
  userId: 8,
  projectId: 9,
  projectLabel: 'Башня',
  workDate: '2026-05-22',
  startTime: '08:00',
  endTime: '12:00',
  hoursWorked: 3.5,
  breakTime: 0.5,
  title: 'Монтаж опалубки',
  description: 'Секция А',
  status: 'draft',
  statusLabel: 'Черновик',
  isActiveTimer: false,
  isBillable: true,
  corrections: [],
  availableActions: ['submit'],
  approvalSummary: _approval,
  createdAt: '2026-05-22T08:00:00Z',
  updatedAt: '2026-05-22T10:00:00Z',
);

const _rejectedEntry = TimeEntryModel(
  id: 18,
  organizationId: 4,
  userId: 8,
  projectId: 9,
  projectLabel: 'Башня',
  workDate: '2026-05-22',
  startTime: '13:00',
  endTime: '15:00',
  hoursWorked: 2,
  breakTime: 0,
  title: 'Проверка геометрии',
  status: 'rejected',
  statusLabel: 'Отклонено',
  isActiveTimer: false,
  isBillable: false,
  rejectionReason: 'Не совпали часы',
  corrections: [
    TimeEntryCorrectionModel(
      id: 'correction-1',
      reason: 'Добавлен демонтаж',
      previousHours: 1,
      newHours: 2,
      submittedByUserId: 8,
      createdAt: '2026-05-22T15:00:00Z',
    ),
  ],
  availableActions: ['submit', 'correction'],
  approvalSummary: _rejectedApproval,
  createdAt: '2026-05-22T13:00:00Z',
  updatedAt: '2026-05-22T15:00:00Z',
);

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildApp(Widget child, _RecordingTimeTrackingRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        timeTrackingProvider.overrideWith(
          (ref) => TimeTrackingNotifier(repository),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  void useLargeSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows daily time summary and entries', (tester) async {
    final repository = _RecordingTimeTrackingRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildApp(const TimeTrackingScreen(), repository));
    await pumpUi(tester);

    expect(repository.loadedProjectId, 9);
    expect(find.text('Учет времени'), findsOneWidget);
    expect(find.text('Монтаж опалубки'), findsOneWidget);
    expect(find.text('Проверка геометрии'), findsOneWidget);
    expect(find.text('5.50 ч'), findsOneWidget);
  });

  testWidgets('submits visible start timer and manual entry forms', (
    tester,
  ) async {
    final repository = _RecordingTimeTrackingRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildApp(const TimeTrackingScreen(), repository));
    await pumpUi(tester);

    await tester.tap(find.text('Запустить').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Армирование');
    await tester.enterText(find.byType(TextField).at(1), '13:00');
    await tester.tap(find.text('Запустить').last);
    await pumpUi(tester);

    expect(repository.startedTitle, 'Армирование');
    expect(repository.startedTime, '13:00');

    await tester.tap(find.text('Ручная запись').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Проверка отметок');
    await tester.enterText(find.byType(TextField).at(1), '2,5');
    await tester.tap(find.text('Сохранить').last);
    await pumpUi(tester);

    expect(repository.manualHours, 2.5);
  });

  testWidgets('opens detail and submits correction', (tester) async {
    final repository = _RecordingTimeTrackingRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(TimeEntryDetailScreen(entryId: 18), repository),
    );
    await pumpUi(tester);

    expect(repository.fetchedEntryId, 18);
    expect(find.text('Запись времени'), findsOneWidget);
    expect(find.text('Не совпали часы'), findsWidgets);

    await tester.tap(find.text('Корректировка').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).at(0), '2,5');
    await tester.enterText(find.byType(TextField).at(1), 'Добавлен демонтаж');
    await tester.tap(find.text('Отправить').last);
    await pumpUi(tester);

    expect(repository.correctedEntryId, 18);
    expect(repository.correctedHours, 2.5);
    expect(repository.correctionReason, 'Добавлен демонтаж');
  });
}
