import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/schedule_model.dart';
import '../data/schedule_repository.dart';

const _scheduleSentinel = Object();

class ScheduleState {
  const ScheduleState({
    this.isLoading = false,
    this.overview,
    this.error,
    this.projectId,
  });

  final bool isLoading;
  final ScheduleOverviewModel? overview;
  final String? error;
  final int? projectId;

  ScheduleState copyWith({
    bool? isLoading,
    Object? overview = _scheduleSentinel,
    Object? error = _scheduleSentinel,
    Object? projectId = _scheduleSentinel,
  }) {
    return ScheduleState(
      isLoading: isLoading ?? this.isLoading,
      overview: identical(overview, _scheduleSentinel)
          ? this.overview
          : overview as ScheduleOverviewModel?,
      error: identical(error, _scheduleSentinel) ? this.error : error as String?,
      projectId: identical(projectId, _scheduleSentinel)
          ? this.projectId
          : projectId as int?,
    );
  }
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  ScheduleNotifier(this._repository) : super(const ScheduleState());

  final ScheduleRepository _repository;

  Future<void> load({int? projectId}) async {
    if (projectId == null) {
      state = state.copyWith(
        isLoading: false,
        overview: null,
        error: 'Сначала выберите объект.',
        projectId: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      projectId: projectId,
    );

    try {
      final overview = await _repository.fetchSchedules(projectId: projectId);
      state = state.copyWith(
        isLoading: false,
        overview: overview,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  return ScheduleNotifier(ref.read(scheduleRepositoryProvider));
});

const _scheduleDetailSentinel = Object();

class ScheduleDetailState {
  const ScheduleDetailState({
    this.isLoading = false,
    this.detail,
    this.error,
  });

  final bool isLoading;
  final ScheduleDetailsModel? detail;
  final String? error;

  ScheduleDetailState copyWith({
    bool? isLoading,
    Object? detail = _scheduleDetailSentinel,
    Object? error = _scheduleDetailSentinel,
  }) {
    return ScheduleDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail: identical(detail, _scheduleDetailSentinel)
          ? this.detail
          : detail as ScheduleDetailsModel?,
      error: identical(error, _scheduleDetailSentinel) ? this.error : error as String?,
    );
  }
}

final scheduleDetailProvider = StateNotifierProvider.family<
    ScheduleDetailNotifier, ScheduleDetailState, int>((ref, scheduleId) {
  return ScheduleDetailNotifier(
    ref.read(scheduleRepositoryProvider),
    scheduleId,
  );
});

class ScheduleDetailNotifier extends StateNotifier<ScheduleDetailState> {
  ScheduleDetailNotifier(this._repository, this._scheduleId)
      : super(const ScheduleDetailState()) {
    load();
  }

  final ScheduleRepository _repository;
  final int _scheduleId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final detail = await _repository.fetchScheduleDetails(_scheduleId);
      state = state.copyWith(
        isLoading: false,
        detail: detail,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }
}
