import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/schedule_model.dart';
import '../data/schedule_repository.dart';
import '../data/schedule_snapshot_adapter.dart';

const _scheduleSentinel = Object();

class ScheduleState {
  const ScheduleState({
    this.isLoading = false,
    this.overview,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
    this.projectId,
  });

  final bool isLoading;
  final ScheduleOverviewModel? overview;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;
  final int? projectId;

  ScheduleState copyWith({
    bool? isLoading,
    Object? overview = _scheduleSentinel,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
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
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
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
  ScheduleNotifier(this._repository, {ScheduleSnapshotAdapter? snapshotAdapter})
    : _snapshotAdapter = snapshotAdapter,
      super(const ScheduleState());

  final ScheduleRepository _repository;
  final ScheduleSnapshotAdapter? _snapshotAdapter;

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
      final adapter = _snapshotAdapter;
      if (adapter != null) {
        final read = await adapter.loadOverview(
          online: true,
          projectId: projectId,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          overview: denied ? null : read.data,
          permissionDenied: denied,
          fromCache: read.fromCache,
          hasDirtyLocal: read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final overview = await _repository.fetchSchedules(projectId: projectId);
      state = state.copyWith(
        isLoading: false,
        overview: overview,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        hasDirtyLocal: false,
        error: _errorMessage(error),
      );
    }
  }
}

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, ScheduleState>(
  (ref) {
    return ScheduleNotifier(
      ref.read(scheduleRepositoryProvider),
      snapshotAdapter: ref.read(scheduleSnapshotAdapterProvider),
    );
  },
);

final scheduleSnapshotAdapterProvider = Provider<ScheduleSnapshotAdapter>((
  ref,
) {
  return ScheduleSnapshotAdapter(
    repository: ref.read(scheduleRepositoryProvider),
    snapshots: ref.read(entitySnapshotServiceProvider.future),
    flushQueue: () async {
      await ref.read(syncQueueProvider.notifier).retryPending();
    },
  );
});

const _scheduleDetailSentinel = Object();

class ScheduleDetailState {
  const ScheduleDetailState({
    this.isLoading = false,
    this.detail,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  final bool isLoading;
  final ScheduleDetailsModel? detail;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  ScheduleDetailState copyWith({
    bool? isLoading,
    Object? detail = _scheduleDetailSentinel,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _scheduleDetailSentinel,
  }) {
    return ScheduleDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail:
          identical(detail, _scheduleDetailSentinel)
              ? this.detail
              : detail as ScheduleDetailsModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
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
    snapshotAdapter: ref.read(scheduleSnapshotAdapterProvider),
    projectId: ref.read(projectsProvider).selectedProject?.serverId,
  );
});

class ScheduleDetailNotifier extends StateNotifier<ScheduleDetailState> {
  ScheduleDetailNotifier(
    this._repository,
    this._scheduleId, {
    ScheduleSnapshotAdapter? snapshotAdapter,
    int? projectId,
  }) : _snapshotAdapter = snapshotAdapter,
       _projectId = projectId,
       super(const ScheduleDetailState()) {
    load();
  }

  final ScheduleRepository _repository;
  final int _scheduleId;
  final ScheduleSnapshotAdapter? _snapshotAdapter;
  final int? _projectId;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final adapter = _snapshotAdapter;
      if (adapter != null && _projectId != null) {
        final read = await adapter.loadDetail(
          online: true,
          scheduleId: _scheduleId,
          projectId: _projectId,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          detail: denied ? null : read.data,
          permissionDenied: denied,
          fromCache: read.fromCache,
          hasDirtyLocal: read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final detail = await _repository.fetchScheduleDetails(_scheduleId);
      state = state.copyWith(
        isLoading: false,
        detail: detail,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        hasDirtyLocal: false,
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
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
    this.projectId,
  });

  final bool isLoading;
  final List<DailyWorkPlanModel> plans;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;
  final int? projectId;

  DailyWorkPlansState copyWith({
    bool? isLoading,
    List<DailyWorkPlanModel>? plans,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _dailyPlansSentinel,
    Object? projectId = _dailyPlansSentinel,
  }) {
    return DailyWorkPlansState(
      isLoading: isLoading ?? this.isLoading,
      plans: plans ?? this.plans,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
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
      return DailyWorkPlansNotifier(
        ref.read(scheduleRepositoryProvider),
        snapshotAdapter: ref.read(scheduleSnapshotAdapterProvider),
      );
    });

class DailyWorkPlansNotifier extends StateNotifier<DailyWorkPlansState> {
  DailyWorkPlansNotifier(
    this._repository, {
    ScheduleSnapshotAdapter? snapshotAdapter,
  }) : _snapshotAdapter = snapshotAdapter,
       super(const DailyWorkPlansState());

  final ScheduleRepository _repository;
  final ScheduleSnapshotAdapter? _snapshotAdapter;

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
      final adapter = _snapshotAdapter;
      if (adapter != null) {
        final read = await adapter.loadDailyPlans(
          online: true,
          projectId: projectId,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          plans:
              denied ? const <DailyWorkPlanModel>[] : (read.data ?? const []),
          permissionDenied: denied,
          fromCache: read.fromCache,
          hasDirtyLocal: read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final plans = await _repository.fetchDailyWorkPlans(projectId: projectId);
      state = state.copyWith(
        isLoading: false,
        plans: plans,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        hasDirtyLocal: false,
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
