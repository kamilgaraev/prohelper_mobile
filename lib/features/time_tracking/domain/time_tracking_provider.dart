import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/snapshot_read.dart';
import '../data/time_entry_model.dart';
import '../data/time_tracking_repository.dart';
import '../data/time_tracking_snapshot_adapter.dart';

class TimeTrackingState {
  const TimeTrackingState({
    this.isLoading = false,
    this.entries = const [],
    this.date,
    this.projectId,
    this.activeTimer,
    this.totals,
    this.permissionDenied = false,
    this.malformedContract = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  final bool isLoading;
  final List<TimeEntryModel> entries;
  final String? date;
  final int? projectId;
  final TimeEntryModel? activeTimer;
  final TimeTotalsModel? totals;
  final bool permissionDenied;
  final bool malformedContract;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  TimeTrackingState copyWith({
    bool? isLoading,
    List<TimeEntryModel>? entries,
    Object? date = _dateSentinel,
    Object? projectId = _projectSentinel,
    Object? activeTimer = _timerSentinel,
    Object? totals = _totalsSentinel,
    bool? permissionDenied,
    bool? malformedContract,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _errorSentinel,
  }) {
    return TimeTrackingState(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      date: identical(date, _dateSentinel) ? this.date : date as String?,
      projectId:
          identical(projectId, _projectSentinel)
              ? this.projectId
              : projectId as int?,
      activeTimer:
          identical(activeTimer, _timerSentinel)
              ? this.activeTimer
              : activeTimer as TimeEntryModel?,
      totals:
          identical(totals, _totalsSentinel)
              ? this.totals
              : totals as TimeTotalsModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      malformedContract: malformedContract ?? this.malformedContract,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _dateSentinel = Object();
const _projectSentinel = Object();
const _timerSentinel = Object();
const _totalsSentinel = Object();
const _errorSentinel = Object();

class TimeTrackingNotifier extends StateNotifier<TimeTrackingState> {
  TimeTrackingNotifier(
    this._repository, {
    TimeTrackingSnapshotAdapter? snapshotAdapter,
  }) : _snapshotAdapter = snapshotAdapter,
       super(const TimeTrackingState());

  final TimeTrackingRepository _repository;
  final TimeTrackingSnapshotAdapter? _snapshotAdapter;

  void syncScope({required String date, required int? projectId}) {
    if (state.date == date && state.projectId == projectId) {
      return;
    }

    state = state.copyWith(
      date: date,
      projectId: projectId,
      entries: const [],
      activeTimer: null,
      totals: null,
      error: null,
      fromCache: false,
      hasDirtyLocal: false,
    );
  }

  Future<void> loadDailySummary() async {
    final date = state.date;
    final projectId = state.projectId;

    if (date == null || projectId == null) {
      state = state.copyWith(
        isLoading: false,
        entries: const [],
        activeTimer: null,
        totals: null,
        error: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      malformedContract: false,
      error: null,
    );

    try {
      final adapter = _snapshotAdapter;
      if (adapter != null) {
        final read = await adapter.load(
          online: true,
          date: date,
          projectId: projectId,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        final summary = denied ? null : read.data;
        state = state.copyWith(
          isLoading: false,
          entries: summary?.entries ?? const [],
          activeTimer: summary?.activeTimer,
          totals: summary?.totals,
          permissionDenied: denied,
          malformedContract: false,
          fromCache: read.fromCache,
          hasDirtyLocal: read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final summary = await _repository.fetchDailySummary(
        date: date,
        projectId: projectId,
      );

      state = state.copyWith(
        isLoading: false,
        entries: summary.entries,
        activeTimer: summary.activeTimer,
        totals: summary.totals,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        entries: const [],
        activeTimer: null,
        totals: null,
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        fromCache: false,
        hasDirtyLocal: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<TimeEntryModel> fetchEntry(int id) {
    return _repository.fetchEntry(id);
  }

  Future<SnapshotRead<TimeEntryModel>> loadEntrySnapshot(int id) async {
    final adapter = _snapshotAdapter;
    if (adapter == null) {
      try {
        return SnapshotRead(
          presence: SnapshotPresence.ready,
          data: await _repository.fetchEntry(id),
        );
      } catch (error) {
        return SnapshotRead(
          presence: SnapshotPresence.error,
          error: UserMessage.fromError(error),
        );
      }
    }
    final read = await adapter.loadEntry(
      online: true,
      entryId: id,
      projectId: state.projectId,
    );
    if (read.presence == SnapshotPresence.permissionDenied) {
      return SnapshotRead(
        presence: read.presence,
        error: read.error,
        fromCache: false,
        hasDirtyLocal: read.hasDirtyLocal,
      );
    }
    return read;
  }

  Future<void> startTimer({
    required String startTime,
    required String title,
    required bool isBillable,
    String? description,
  }) async {
    final date = _requireDate();
    final projectId = _requireProject();

    await _repository.startTimer(
      projectId: projectId,
      workDate: date,
      startTime: startTime,
      title: title,
      isBillable: isBillable,
      description: description,
    );
    await loadDailySummary();
  }

  Future<void> createManualEntry({
    required double hoursWorked,
    required String title,
    required bool isBillable,
    String? startTime,
    String? endTime,
    double? breakTime,
    String? description,
  }) async {
    final date = _requireDate();
    final projectId = _requireProject();

    await _repository.createManualEntry(
      projectId: projectId,
      workDate: date,
      hoursWorked: hoursWorked,
      title: title,
      isBillable: isBillable,
      startTime: startTime,
      endTime: endTime,
      breakTime: breakTime,
      description: description,
    );
    await loadDailySummary();
  }

  Future<void> stopTimer({
    required int id,
    required String endTime,
    required double breakTime,
    String? notes,
  }) async {
    await _repository.stopTimer(
      id: id,
      endTime: endTime,
      breakTime: breakTime,
      notes: notes,
    );
    await loadDailySummary();
  }

  Future<void> submitEntry(int id) async {
    await _repository.submitEntry(id);
    await loadDailySummary();
  }

  Future<void> submitCorrection({
    required int id,
    required double hoursWorked,
    required String correctionReason,
  }) async {
    await _repository.submitCorrection(
      id: id,
      hoursWorked: hoursWorked,
      correctionReason: correctionReason,
    );
    await loadDailySummary();
  }

  String _requireDate() {
    final value = state.date;
    if (value == null) {
      throw StateError('Дата учета времени не выбрана');
    }

    return value;
  }

  int _requireProject() {
    final value = state.projectId;
    if (value == null) {
      throw StateError('Объект учета времени не выбран');
    }

    return value;
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final timeTrackingProvider =
    StateNotifierProvider<TimeTrackingNotifier, TimeTrackingState>((ref) {
      return TimeTrackingNotifier(
        ref.read(timeTrackingRepositoryProvider),
        snapshotAdapter: ref.read(timeTrackingSnapshotAdapterProvider),
      );
    });

final timeTrackingSnapshotAdapterProvider =
    Provider<TimeTrackingSnapshotAdapter>((ref) {
      return TimeTrackingSnapshotAdapter(
        repository: ref.read(timeTrackingRepositoryProvider),
        snapshots: ref.read(entitySnapshotServiceProvider.future),
      );
    });
