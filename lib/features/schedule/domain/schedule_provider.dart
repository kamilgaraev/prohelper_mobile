import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/schedule_model.dart';
import '../data/schedule_repository.dart';

const _scheduleSentinel = Object();

class ScheduleState {
  const ScheduleState({
    this.isLoading = false,
    this.overview,
    this.permissionDenied = false,
    this.error,
    this.projectId,
  });

  final bool isLoading;
  final ScheduleOverviewModel? overview;
  final bool permissionDenied;
  final String? error;
  final int? projectId;

  ScheduleState copyWith({
    bool? isLoading,
    Object? overview = _scheduleSentinel,
    bool? permissionDenied,
    Object? error = _scheduleSentinel,
    Object? projectId = _scheduleSentinel,
  }) {
    return ScheduleState(
      isLoading: isLoading ?? this.isLoading,
      overview:
          identical(overview, _scheduleSentinel)
              ? this.overview
              : overview as ScheduleOverviewModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
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
    state = state.copyWith(permissionDenied: false);

    try {
      final overview = await _repository.fetchSchedules(projectId: projectId);
      state = state.copyWith(isLoading: false, overview: overview);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: _errorMessage(error),
      );
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
  const ScheduleDetailState({
    this.isLoading = false,
    this.detail,
    this.permissionDenied = false,
    this.error,
  });

  final bool isLoading;
  final ScheduleDetailsModel? detail;
  final bool permissionDenied;
  final String? error;

  ScheduleDetailState copyWith({
    bool? isLoading,
    Object? detail = _scheduleDetailSentinel,
    bool? permissionDenied,
    Object? error = _scheduleDetailSentinel,
  }) {
    return ScheduleDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail:
          identical(detail, _scheduleDetailSentinel)
              ? this.detail
              : detail as ScheduleDetailsModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
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
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final detail = await _repository.fetchScheduleDetails(_scheduleId);
      state = state.copyWith(isLoading: false, detail: detail);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: _errorMessage(error),
      );
    }
  }
}

const _dailyPlansSentinel = Object();

class DailyWorkPlansState {
  const DailyWorkPlansState({
    this.isLoading = false,
    this.plans = const [],
    this.permissionDenied = false,
    this.error,
    this.projectId,
  });

  final bool isLoading;
  final List<DailyWorkPlanModel> plans;
  final bool permissionDenied;
  final String? error;
  final int? projectId;

  DailyWorkPlansState copyWith({
    bool? isLoading,
    List<DailyWorkPlanModel>? plans,
    bool? permissionDenied,
    Object? error = _dailyPlansSentinel,
    Object? projectId = _dailyPlansSentinel,
  }) {
    return DailyWorkPlansState(
      isLoading: isLoading ?? this.isLoading,
      plans: plans ?? this.plans,
      permissionDenied: permissionDenied ?? this.permissionDenied,
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

    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
      projectId: projectId,
    );

    try {
      final plans = await _repository.fetchDailyWorkPlans(projectId: projectId);
      state = state.copyWith(isLoading: false, plans: plans);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: _errorMessage(error),
      );
    }
  }

  Future<void> recordFact(
    DailyWorkPlanAssignmentModel assignment,
    DailyWorkFactInput input,
  ) async {
    final updatedAssignment = await _repository.recordDailyWorkFact(
      assignmentId: assignment.id,
      input: input,
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
    String? comment,
  ) async {
    await _repository.createLinkedConstraintAction(
      constraintId: constraint.id,
      comment: comment?.trim().isEmpty == true ? null : comment,
    );

    if (state.projectId != null) {
      await load(projectId: state.projectId);
    }
  }

  Future<void> submit(DailyWorkPlanModel plan, {String? summaryComment}) async {
    final updatedPlan = await _repository.submitDailyWorkPlan(
      dailyPlanId: plan.id,
      summaryComment:
          summaryComment?.trim().isEmpty == true ? null : summaryComment,
    );

    state = state.copyWith(
      plans:
          state.plans
              .map((item) => item.id == updatedPlan.id ? updatedPlan : item)
              .toList(),
    );
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

String _errorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  if (error is FormatException) {
    return 'Данные графика пришли неполными. Обновите экран и повторите попытку.';
  }

  return 'Не удалось обработать данные графика работ.';
}
