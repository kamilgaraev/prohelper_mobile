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
      overview:
          identical(overview, _scheduleSentinel)
              ? this.overview
              : overview as ScheduleOverviewModel?,
      error:
          identical(error, _scheduleSentinel) ? this.error : error as String?,
      projectId:
          identical(projectId, _scheduleSentinel)
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

    state = state.copyWith(isLoading: true, error: null, projectId: projectId);

    try {
      final overview = await _repository.fetchSchedules(projectId: projectId);
      state = state.copyWith(isLoading: false, overview: overview);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, ScheduleState>(
  (ref) {
    return ScheduleNotifier(ref.read(scheduleRepositoryProvider));
  },
);

const _scheduleDetailSentinel = Object();

class ScheduleDetailState {
  const ScheduleDetailState({this.isLoading = false, this.detail, this.error});

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
      detail:
          identical(detail, _scheduleDetailSentinel)
              ? this.detail
              : detail as ScheduleDetailsModel?,
      error:
          identical(error, _scheduleDetailSentinel)
              ? this.error
              : error as String?,
    );
  }
}

final scheduleDetailProvider = StateNotifierProvider.family<
  ScheduleDetailNotifier,
  ScheduleDetailState,
  int
>((ref, scheduleId) {
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
      state = state.copyWith(isLoading: false, detail: detail);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}

const _dailyPlansSentinel = Object();

class DailyWorkPlansState {
  const DailyWorkPlansState({
    this.isLoading = false,
    this.plans = const [],
    this.error,
    this.projectId,
  });

  final bool isLoading;
  final List<DailyWorkPlanModel> plans;
  final String? error;
  final int? projectId;

  DailyWorkPlansState copyWith({
    bool? isLoading,
    List<DailyWorkPlanModel>? plans,
    Object? error = _dailyPlansSentinel,
    Object? projectId = _dailyPlansSentinel,
  }) {
    return DailyWorkPlansState(
      isLoading: isLoading ?? this.isLoading,
      plans: plans ?? this.plans,
      error:
          identical(error, _dailyPlansSentinel) ? this.error : error as String?,
      projectId:
          identical(projectId, _dailyPlansSentinel)
              ? this.projectId
              : projectId as int?,
    );
  }
}

final dailyWorkPlansProvider =
    StateNotifierProvider<DailyWorkPlansNotifier, DailyWorkPlansState>((ref) {
      return DailyWorkPlansNotifier(ref.read(scheduleRepositoryProvider));
    });

class DailyWorkPlansNotifier extends StateNotifier<DailyWorkPlansState> {
  DailyWorkPlansNotifier(this._repository) : super(const DailyWorkPlansState());

  final ScheduleRepository _repository;

  Future<void> load({required int? projectId}) async {
    if (projectId == null) {
      state = const DailyWorkPlansState(error: 'Сначала выберите объект.');
      return;
    }

    state = state.copyWith(isLoading: true, error: null, projectId: projectId);

    try {
      final plans = await _repository.fetchDailyWorkPlans(projectId: projectId);
      state = state.copyWith(isLoading: false, plans: plans);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> recordFact(DailyWorkPlanAssignmentModel assignment) async {
    final updatedAssignment = await _repository.recordDailyWorkFact(
      assignmentId: assignment.id,
      status: 'done',
      completedQuantity: assignment.plannedQuantity ?? 0,
      actualWorkHours: assignment.plannedWorkHours ?? 0,
      factComment: 'Факт выполнен по дневному заданию',
    );

    state = state.copyWith(
      plans:
          state.plans
              .map(
                (plan) => DailyWorkPlanModel(
                  id: plan.id,
                  projectId: plan.projectId,
                  scheduleId: plan.scheduleId,
                  lookaheadPlanId: plan.lookaheadPlanId,
                  scheduleName: plan.scheduleName,
                  workDate: plan.workDate,
                  status: plan.status,
                  statusLabel: plan.statusLabel,
                  availableActions: plan.availableActions,
                  assignments:
                      plan.assignments
                          .map(
                            (item) =>
                                item.id == updatedAssignment.id
                                    ? updatedAssignment
                                    : item,
                          )
                          .toList(),
                ),
              )
              .toList(),
    );
  }

  Future<void> createLinkedConstraintAction(
    DailyWorkConstraintModel constraint,
  ) async {
    await _repository.createLinkedConstraintAction(
      constraintId: constraint.id,
      comment: constraint.title,
    );

    if (state.projectId != null) {
      await load(projectId: state.projectId);
    }
  }

  Future<void> submit(DailyWorkPlanModel plan) async {
    final updatedPlan = await _repository.submitDailyWorkPlan(
      dailyPlanId: plan.id,
      summaryComment: 'Дневной план выполнен и передан на приемку',
    );

    state = state.copyWith(
      plans:
          state.plans
              .map((item) => item.id == updatedPlan.id ? updatedPlan : item)
              .toList(),
    );
  }
}
