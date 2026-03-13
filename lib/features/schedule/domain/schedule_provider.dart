import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/schedule_repository.dart';
import '../data/schedule_summary_model.dart';

const _scheduleSentinel = Object();

class ScheduleState {
  const ScheduleState({
    this.isLoading = false,
    this.data,
    this.error,
    this.projectId,
  });

  final bool isLoading;
  final ScheduleSummaryModel? data;
  final String? error;
  final int? projectId;

  ScheduleState copyWith({
    bool? isLoading,
    Object? data = _scheduleSentinel,
    Object? error = _scheduleSentinel,
    Object? projectId = _scheduleSentinel,
  }) {
    return ScheduleState(
      isLoading: isLoading ?? this.isLoading,
      data: identical(data, _scheduleSentinel) ? this.data : data as ScheduleSummaryModel?,
      error: identical(error, _scheduleSentinel) ? this.error : error as String?,
      projectId: identical(projectId, _scheduleSentinel) ? this.projectId : projectId as int?,
    );
  }
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  ScheduleNotifier(this._repository) : super(const ScheduleState());

  final ScheduleRepository _repository;

  Future<void> load({int? projectId}) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      projectId: projectId,
    );

    try {
      final data = await _repository.fetchSchedule(projectId: projectId);
      state = state.copyWith(
        isLoading: false,
        data: data,
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
