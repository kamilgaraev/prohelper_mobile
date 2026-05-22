import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/workflow_repository.dart';
import '../data/workflow_task_model.dart';

class WorkflowState {
  const WorkflowState({
    this.isLoading = false,
    this.tasks = const [],
    this.projectFilter,
    this.statusFilter,
    this.assignedToMe = true,
    this.search,
    this.summary,
    this.permissionDenied = false,
    this.malformedContract = false,
    this.error,
  });

  final bool isLoading;
  final List<WorkflowTaskModel> tasks;
  final int? projectFilter;
  final String? statusFilter;
  final bool assignedToMe;
  final String? search;
  final WorkflowTaskListSummary? summary;
  final bool permissionDenied;
  final bool malformedContract;
  final String? error;

  WorkflowState copyWith({
    bool? isLoading,
    List<WorkflowTaskModel>? tasks,
    Object? projectFilter = _projectSentinel,
    Object? statusFilter = _statusSentinel,
    bool? assignedToMe,
    Object? search = _searchSentinel,
    Object? summary = _summarySentinel,
    bool? permissionDenied,
    bool? malformedContract,
    Object? error = _errorSentinel,
  }) {
    return WorkflowState(
      isLoading: isLoading ?? this.isLoading,
      tasks: tasks ?? this.tasks,
      projectFilter:
          identical(projectFilter, _projectSentinel)
              ? this.projectFilter
              : projectFilter as int?,
      statusFilter:
          identical(statusFilter, _statusSentinel)
              ? this.statusFilter
              : statusFilter as String?,
      assignedToMe: assignedToMe ?? this.assignedToMe,
      search:
          identical(search, _searchSentinel) ? this.search : search as String?,
      summary:
          identical(summary, _summarySentinel)
              ? this.summary
              : summary as WorkflowTaskListSummary?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      malformedContract: malformedContract ?? this.malformedContract,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _projectSentinel = Object();
const _statusSentinel = Object();
const _searchSentinel = Object();
const _summarySentinel = Object();
const _errorSentinel = Object();

class WorkflowNotifier extends StateNotifier<WorkflowState> {
  WorkflowNotifier(this._repository) : super(const WorkflowState());

  final WorkflowRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(projectFilter: projectId, tasks: const []);
  }

  void setAssignedToMe(bool value) {
    if (state.assignedToMe == value) {
      return;
    }

    state = state.copyWith(assignedToMe: value, tasks: const []);
  }

  void setStatusFilter(String? status) {
    if (state.statusFilter == status) {
      return;
    }

    state = state.copyWith(statusFilter: status, tasks: const []);
  }

  void setSearch(String? value) {
    final normalized = value?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (state.search == next) {
      return;
    }

    state = state.copyWith(search: next, tasks: const []);
  }

  Future<void> loadTasks() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      malformedContract: false,
      error: null,
    );

    try {
      final result = await _repository.fetchTasks(
        projectId: state.projectFilter,
        status: state.statusFilter,
        assignedToMe: state.assignedToMe,
        search: state.search,
      );

      state = state.copyWith(
        isLoading: false,
        tasks: result.items,
        summary: result.summary,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        tasks: const [],
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        error: error.toString(),
      );
    }
  }

  Future<WorkflowTaskModel> fetchTask(int id) {
    return _repository.fetchTask(id);
  }

  Future<WorkflowTaskModel> approveTask(int id, {String? comment}) async {
    final updated = await _repository.approveTask(id, comment: comment);
    await loadTasks();
    return updated;
  }

  Future<WorkflowTaskModel> rejectTask({
    required int id,
    required String reason,
  }) async {
    final updated = await _repository.rejectTask(id: id, reason: reason);
    await loadTasks();
    return updated;
  }

  Future<WorkflowTaskModel> requestChanges({
    required int id,
    required String comment,
  }) async {
    final updated = await _repository.requestChanges(id: id, comment: comment);
    await loadTasks();
    return updated;
  }

  Future<WorkflowTaskModel> addComment({
    required int id,
    required String comment,
  }) async {
    final updated = await _repository.addComment(id: id, comment: comment);
    await loadTasks();
    return updated;
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final workflowProvider = StateNotifierProvider<WorkflowNotifier, WorkflowState>(
  (ref) {
    return WorkflowNotifier(ref.read(workflowRepositoryProvider));
  },
);
