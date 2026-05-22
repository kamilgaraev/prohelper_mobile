import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_entry_model.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_tracking_repository.dart';
import 'package:prohelpers_mobile/features/time_tracking/domain/time_tracking_provider.dart';

class _FakeTimeTrackingRepository extends TimeTrackingRepository {
  _FakeTimeTrackingRepository({this.error}) : super(Dio());

  final Object? error;

  String? loadedDate;
  int? loadedProjectId;
  int? fetchedEntryId;
  int? stoppedEntryId;
  int? submittedEntryId;
  int? correctedEntryId;
  String? startedTitle;
  String? startedTime;
  double? manualHours;
  double? stoppedBreakTime;
  double? correctedHours;
  String? correctionReason;

  @override
  Future<DailyTimeSummaryModel> fetchDailySummary({
    required String date,
    required int projectId,
  }) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }

    loadedDate = date;
    loadedProjectId = projectId;

    return DailyTimeSummaryModel(
      date: date,
      projectId: projectId,
      entries: const [_entry],
      activeTimer: _activeTimer,
      totals: const TimeTotalsModel(
        totalHours: 3.5,
        billableHours: 3.5,
        entriesCount: 1,
        byStatus: {'draft': 1, 'submitted': 0, 'approved': 0, 'rejected': 0},
      ),
      approvalStatus: const {
        'draft': 1,
        'submitted': 0,
        'approved': 0,
        'rejected': 0,
      },
    );
  }

  @override
  Future<TimeEntryModel> fetchEntry(int id) async {
    fetchedEntryId = id;
    return _entry;
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
    return _activeTimer;
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
  Future<TimeEntryModel> stopTimer({
    required int id,
    required String endTime,
    required double breakTime,
    String? notes,
  }) async {
    stoppedEntryId = id;
    stoppedBreakTime = breakTime;
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

const _approval = TimeEntryApprovalSummaryModel(
  status: 'draft',
  statusLabel: 'Черновик',
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

const _activeTimer = TimeEntryModel(
  id: 18,
  organizationId: 4,
  userId: 8,
  projectId: 9,
  projectLabel: 'Башня',
  workDate: '2026-05-22',
  startTime: '13:00',
  title: 'Армирование',
  status: 'draft',
  statusLabel: 'Черновик',
  isActiveTimer: true,
  isBillable: true,
  corrections: [],
  availableActions: ['stop'],
  approvalSummary: _approval,
  createdAt: '2026-05-22T13:00:00Z',
  updatedAt: '2026-05-22T13:00:00Z',
);

void main() {
  test('loads daily summary for selected scope', () async {
    final repository = _FakeTimeTrackingRepository();
    final notifier = TimeTrackingNotifier(repository);

    notifier.syncScope(date: '2026-05-22', projectId: 9);
    await notifier.loadDailySummary();

    expect(repository.loadedDate, '2026-05-22');
    expect(repository.loadedProjectId, 9);
    expect(notifier.state.entries.single.id, 17);
    expect(notifier.state.activeTimer?.id, 18);
    expect(notifier.state.totals?.totalHours, 3.5);
  });

  test('runs mutations and refreshes summary', () async {
    final repository = _FakeTimeTrackingRepository();
    final notifier = TimeTrackingNotifier(repository)
      ..syncScope(date: '2026-05-22', projectId: 9);

    await notifier.startTimer(
      startTime: '08:00',
      title: 'Монтаж опалубки',
      isBillable: true,
    );
    await notifier.createManualEntry(
      hoursWorked: 2.5,
      title: 'Проверка геометрии',
      isBillable: false,
    );
    await notifier.stopTimer(id: 18, endTime: '12:00', breakTime: 0.5);
    await notifier.submitEntry(17);
    await notifier.submitCorrection(
      id: 17,
      hoursWorked: 4.5,
      correctionReason: 'Добавлен демонтаж',
    );

    expect(repository.startedTitle, 'Монтаж опалубки');
    expect(repository.startedTime, '08:00');
    expect(repository.manualHours, 2.5);
    expect(repository.stoppedEntryId, 18);
    expect(repository.stoppedBreakTime, 0.5);
    expect(repository.submittedEntryId, 17);
    expect(repository.correctedEntryId, 17);
    expect(repository.correctedHours, 4.5);
    expect(repository.correctionReason, 'Добавлен демонтаж');
    expect(notifier.state.entries.single.id, 17);
  });

  test('marks permission and malformed contract states', () async {
    final denied = TimeTrackingNotifier(
      _FakeTimeTrackingRepository(
        error: const ApiException('Нет доступа', statusCode: 403),
      ),
    )..syncScope(date: '2026-05-22', projectId: 9);
    await denied.loadDailySummary();

    expect(denied.state.permissionDenied, isTrue);
    expect(denied.state.error, 'Нет доступа');

    final malformed = TimeTrackingNotifier(
      _FakeTimeTrackingRepository(error: const FormatException('bad data')),
    )..syncScope(date: '2026-05-22', projectId: 9);
    await malformed.loadDailySummary();

    expect(malformed.state.malformedContract, isTrue);
    expect(malformed.state.entries, isEmpty);
  });

  test('loads entry detail by id', () async {
    final repository = _FakeTimeTrackingRepository();
    final notifier = TimeTrackingNotifier(repository);

    final entry = await notifier.fetchEntry(17);

    expect(repository.fetchedEntryId, 17);
    expect(entry.title, 'Монтаж опалубки');
  });
}
