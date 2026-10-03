import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
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
  Object? startTimerError;
  final List<String> startIdempotencyKeys = [];
  final List<String?> approvalReasons = [];
  Object? approvalError;
  Completer<void>? approvalCompleter;
  int dailySummaryFetches = 0;

  @override
  Future<List<TimeEntryModel>> fetchPendingApprovals({
    required int projectId,
  }) async => [_pendingApprovalEntry];

  @override
  Future<TimeEntryModel> decideApproval({
    required int id,
    required String action,
    String? reason,
  }) async {
    approvalReasons.add(reason);
    await approvalCompleter?.future;
    final error = approvalError;
    approvalError = null;
    if (error != null) throw error;
    return _pendingApprovalEntry;
  }

  @override
  Future<DailyTimeSummaryModel> fetchDailySummary({
    required String date,
    required int projectId,
  }) async {
    loadedDate = date;
    loadedProjectId = projectId;
    dailySummaryFetches++;

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
    required String idempotencyKey,
    String? description,
  }) async {
    startIdempotencyKeys.add(idempotencyKey);
    final error = startTimerError;
    startTimerError = null;
    if (error != null) {
      throw error;
    }

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
    required String idempotencyKey,
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

class _RecordingTimeTrackingNotifier extends TimeTrackingNotifier {
  _RecordingTimeTrackingNotifier(super.repository);

  int loadCalls = 0;

  @override
  Future<void> loadDailySummary() {
    loadCalls++;
    return super.loadDailySummary();
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

const _pendingApprovalEntry = TimeEntryModel(
  id: 24,
  organizationId: 4,
  userId: 15,
  projectId: 9,
  projectLabel: 'Башня',
  workDate: '2026-05-22',
  startTime: '09:00',
  endTime: '11:00',
  hoursWorked: 2,
  breakTime: 0,
  title: 'Сверка арматуры',
  status: 'submitted',
  statusLabel: 'На проверке',
  isActiveTimer: false,
  isBillable: true,
  corrections: [],
  availableActions: ['approve', 'reject'],
  approvalSummary: _approval,
  createdAt: '2026-05-22T11:00:00Z',
  updatedAt: '2026-05-22T11:00:00Z',
);

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildApp(
    Widget child,
    _RecordingTimeTrackingRepository repository, {
    TimeTrackingNotifier? notifier,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        timeTrackingRepositoryProvider.overrideWithValue(repository),
        timeTrackingProvider.overrideWith(
          (ref) => notifier ?? TimeTrackingNotifier(repository),
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

  testWidgets('refreshes daily summary after approving an entry', (tester) async {
    final repository = _RecordingTimeTrackingRepository()
      ..approvalCompleter = Completer<void>();
    final notifier = _RecordingTimeTrackingNotifier(repository);
    useLargeSurface(tester);

    await tester.pumpWidget(
      buildApp(const TimeTrackingScreen(), repository, notifier: notifier),
    );
    await pumpUi(tester);
    final initialFetches = repository.dailySummaryFetches;
    final initialLoadCalls = notifier.loadCalls;

    await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
    await tester.pump();
    expect(repository.approvalReasons, [null]);
    repository.approvalCompleter!.complete();
    await pumpUi(tester);

    expect(notifier.loadCalls, greaterThan(initialLoadCalls));
    expect(repository.dailySummaryFetches, greaterThan(initialFetches));
  });

  testWidgets(
    'keeps rejection reason for retry and prevents duplicate submit on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(240, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository =
          _RecordingTimeTrackingRepository()
            ..approvalError = const ApiException(
              'Не удалось проверить причину. Повторите попытку.',
              statusCode: 422,
            );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith(
              (ref) => _TestProjectsNotifier(project()),
            ),
            timeTrackingRepositoryProvider.overrideWithValue(repository),
            timeTrackingProvider.overrideWith(
              (ref) => TimeTrackingNotifier(repository),
            ),
          ],
          child: MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
            home: const TimeTrackingScreen(),
          ),
        ),
      );
      await pumpUi(tester);
      final initialLayoutError = tester.takeException();
      expect(
        initialLayoutError,
        isNull,
        reason: initialLayoutError?.toString(),
      );

      await tester.ensureVisible(find.text('Отклонить').first);
      await tester.tap(find.text('Отклонить').first);
      await tester.pumpAndSettle();
      const reason =
          'Проверить журнал монтажа, сверить фактические часы и подтвердить запись у ответственного мастера. ';
      final longReason = List.filled(4, reason).join();
      final submittedReason = longReason.trim();
      await tester.enterText(find.byType(TextField).last, longReason);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Отклонить'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
      await tester.pumpAndSettle();

      expect(
        find.text('Не удалось проверить причину. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.text(longReason), findsOneWidget);
      final layoutError = tester.takeException();
      expect(layoutError, isNull, reason: layoutError?.toString());

      repository.approvalCompleter = Completer<void>();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Отклонить'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
      await tester.pump();
      final submit = find.widgetWithText(FilledButton, 'Отправка...');
      expect(submit, findsOneWidget);
      await tester.tap(submit);
      await tester.pump();
      expect(repository.approvalReasons, [submittedReason, submittedReason]);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Отправка...'), findsOneWidget);
      expect(repository.approvalReasons, hasLength(2));

      repository.approvalCompleter!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Отклонить трудозатраты'), findsNothing);
      expect(repository.approvalReasons, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling rejection does not send a decision', (tester) async {
    final repository = _RecordingTimeTrackingRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildApp(const TimeTrackingScreen(), repository));
    await pumpUi(tester);
    await tester.tap(find.text('Отклонить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(repository.approvalReasons, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending rejection completes safely after screen disposal', (
    tester,
  ) async {
    final repository =
        _RecordingTimeTrackingRepository()
          ..approvalCompleter = Completer<void>();
    useLargeSurface(tester);

    await tester.pumpWidget(buildApp(const TimeTrackingScreen(), repository));
    await pumpUi(tester);
    await tester.tap(find.text('Отклонить').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Повторно проверить');
    await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
    await tester.pump();
    expect(repository.approvalReasons, ['Повторно проверить']);

    await tester.pumpWidget(const SizedBox.shrink());
    repository.approvalCompleter!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps summary labels readable on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith(
            (ref) => _TestProjectsNotifier(
              Project()
                ..serverId = 9
                ..name = 'Башня'
                ..address = 'Площадка 1',
            ),
          ),
          timeTrackingProvider.overrideWith(
            (ref) => TimeTrackingNotifier(_RecordingTimeTrackingRepository()),
          ),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const TimeTrackingScreen(),
        ),
      ),
    );
    await pumpUi(tester);

    expect(find.text('На проверке'), findsOneWidget);
    expect(find.text('Согласовано'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('start timer shows inline errors for required fields', (
    tester,
  ) async {
    final repository = _RecordingTimeTrackingRepository();
    useLargeSurface(tester);

    await tester.pumpWidget(buildApp(const TimeTrackingScreen(), repository));
    await pumpUi(tester);

    await tester.tap(find.text('Запустить').first);
    await pumpUi(tester);
    await tester.tap(find.text('Запустить').last);
    await pumpUi(tester);

    expect(find.text('Укажите работу'), findsOneWidget);
    expect(find.text('Укажите время начала'), findsOneWidget);
    expect(find.text('Укажите работу и время начала'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('retries uncertain start with same key and preserves form', (
    tester,
  ) async {
    final repository =
        _RecordingTimeTrackingRepository()
          ..startTimerError = const TimeTrackingWriteUncertainException();
    useLargeSurface(tester);

    await tester.pumpWidget(buildApp(const TimeTrackingScreen(), repository));
    await pumpUi(tester);
    await tester.tap(find.text('Запустить').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Армирование');
    await tester.enterText(find.byType(TextField).at(1), '13:00');
    await tester.tap(find.text('Запустить').last);
    await pumpUi(tester);

    expect(find.textContaining('проверьте таймер'), findsOneWidget);
    expect(find.byType(TextField).at(0), findsOneWidget);
    expect(repository.startIdempotencyKeys, hasLength(1));

    await tester.tap(find.byTooltip('Закрыть сообщение'));
    await tester.pump();
    await tester.tap(find.text('Запустить').last);
    await pumpUi(tester);
    expect(repository.startIdempotencyKeys, hasLength(2));
    expect(
      repository.startIdempotencyKeys[1],
      repository.startIdempotencyKeys[0],
    );

    repository.startTimerError = const TimeTrackingWriteUncertainException();
    await tester.tap(find.text('Запустить').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Армирование');
    await tester.enterText(find.byType(TextField).at(1), '13:00');
    await tester.tap(find.text('Запустить').last);
    await pumpUi(tester);
    expect(repository.startIdempotencyKeys, hasLength(3));
    expect(
      repository.startIdempotencyKeys[2],
      isNot(repository.startIdempotencyKeys[1]),
    );
    await tester.tap(find.byTooltip('Закрыть сообщение'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), 'Новое описание');
    await tester.tap(find.text('Запустить').last);
    await pumpUi(tester);
    expect(repository.startIdempotencyKeys, hasLength(4));
    expect(
      repository.startIdempotencyKeys[3],
      isNot(repository.startIdempotencyKeys[2]),
    );
  });

  testWidgets('start timer cleans technical submit errors', (tester) async {
    final repository =
        _RecordingTimeTrackingRepository()
          ..startTimerError = const FormatException('payload missing start');
    useLargeSurface(tester);

    await tester.pumpWidget(buildApp(const TimeTrackingScreen(), repository));
    await pumpUi(tester);

    await tester.tap(find.text('Запустить').first);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Армирование');
    await tester.enterText(find.byType(TextField).at(1), '13:00');
    await tester.tap(find.text('Запустить').last);
    await pumpUi(tester);

    expect(
      find.text('Не удалось выполнить действие. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('payload'), findsNothing);
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
