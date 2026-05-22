import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/budget_estimate_model.dart';
import '../data/budget_estimates_repository.dart';

class BudgetEstimatesState {
  const BudgetEstimatesState({
    this.isLoading = false,
    this.projectId,
    this.summary,
    this.permissionDenied = false,
    this.malformedContract = false,
    this.error,
  });

  final bool isLoading;
  final int? projectId;
  final BudgetEstimateSummaryModel? summary;
  final bool permissionDenied;
  final bool malformedContract;
  final String? error;

  BudgetEstimatesState copyWith({
    bool? isLoading,
    Object? projectId = _projectSentinel,
    Object? summary = _summarySentinel,
    bool? permissionDenied,
    bool? malformedContract,
    Object? error = _errorSentinel,
  }) {
    return BudgetEstimatesState(
      isLoading: isLoading ?? this.isLoading,
      projectId:
          identical(projectId, _projectSentinel)
              ? this.projectId
              : projectId as int?,
      summary:
          identical(summary, _summarySentinel)
              ? this.summary
              : summary as BudgetEstimateSummaryModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      malformedContract: malformedContract ?? this.malformedContract,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _projectSentinel = Object();
const _summarySentinel = Object();
const _errorSentinel = Object();

class BudgetEstimatesNotifier extends StateNotifier<BudgetEstimatesState> {
  BudgetEstimatesNotifier(this._repository)
    : super(const BudgetEstimatesState());

  final BudgetEstimatesRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectId == projectId) {
      return;
    }

    state = state.copyWith(projectId: projectId, summary: null, error: null);
  }

  Future<void> loadSummary() async {
    final projectId = state.projectId;

    if (projectId == null) {
      state = state.copyWith(
        isLoading: false,
        summary: null,
        error: null,
        permissionDenied: false,
        malformedContract: false,
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
      final summary = await _repository.fetchSummary(projectId: projectId);
      state = state.copyWith(isLoading: false, summary: summary);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        summary: null,
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        error: error.toString(),
      );
    }
  }

  Future<BudgetEstimateDetailModel> fetchEstimate(int id) {
    return _repository.fetchEstimate(id);
  }

  Future<BudgetEstimateModel> approveEstimate({
    required int id,
    String? comment,
  }) async {
    final updated = await _repository.approveEstimate(id: id, comment: comment);
    await loadSummary();
    return updated;
  }

  Future<BudgetEstimateModel> requestChanges({
    required int id,
    required String comment,
  }) async {
    final updated = await _repository.requestChanges(id: id, comment: comment);
    await loadSummary();
    return updated;
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final budgetEstimatesProvider =
    StateNotifierProvider<BudgetEstimatesNotifier, BudgetEstimatesState>((ref) {
      return BudgetEstimatesNotifier(
        ref.read(budgetEstimatesRepositoryProvider),
      );
    });
