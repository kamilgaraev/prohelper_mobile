import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/handover_acceptance_model.dart';
import '../data/handover_acceptance_repository.dart';

class HandoverAcceptanceState {
  const HandoverAcceptanceState({
    this.isLoading = false,
    this.isDetailLoading = false,
    this.scopes = const [],
    this.projectFilter,
    this.statusFilter,
    this.plannedFromFilter,
    this.plannedToFilter,
    this.selectedScope,
    this.permissionDenied = false,
    this.error,
    this.detailError,
  });

  final bool isLoading;
  final bool isDetailLoading;
  final List<AcceptanceScopeModel> scopes;
  final int? projectFilter;
  final String? statusFilter;
  final DateTime? plannedFromFilter;
  final DateTime? plannedToFilter;
  final AcceptanceScopeModel? selectedScope;
  final bool permissionDenied;
  final String? error;
  final String? detailError;

  HandoverAcceptanceState copyWith({
    bool? isLoading,
    bool? isDetailLoading,
    List<AcceptanceScopeModel>? scopes,
    Object? projectFilter = _stateSentinel,
    Object? statusFilter = _stateSentinel,
    Object? plannedFromFilter = _stateSentinel,
    Object? plannedToFilter = _stateSentinel,
    Object? selectedScope = _stateSentinel,
    bool? permissionDenied,
    Object? error = _errorSentinel,
    Object? detailError = _errorSentinel,
  }) {
    return HandoverAcceptanceState(
      isLoading: isLoading ?? this.isLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      scopes: scopes ?? this.scopes,
      projectFilter:
          identical(projectFilter, _stateSentinel)
              ? this.projectFilter
              : projectFilter as int?,
      statusFilter:
          identical(statusFilter, _stateSentinel)
              ? this.statusFilter
              : statusFilter as String?,
      plannedFromFilter:
          identical(plannedFromFilter, _stateSentinel)
              ? this.plannedFromFilter
              : plannedFromFilter as DateTime?,
      plannedToFilter:
          identical(plannedToFilter, _stateSentinel)
              ? this.plannedToFilter
              : plannedToFilter as DateTime?,
      selectedScope:
          identical(selectedScope, _stateSentinel)
              ? this.selectedScope
              : selectedScope as AcceptanceScopeModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      detailError:
          identical(detailError, _errorSentinel)
              ? this.detailError
              : detailError as String?,
    );
  }
}

const _errorSentinel = Object();
const _stateSentinel = Object();

class HandoverAcceptanceNotifier
    extends StateNotifier<HandoverAcceptanceState> {
  HandoverAcceptanceNotifier(this._repository)
    : super(const HandoverAcceptanceState());

  final HandoverAcceptanceRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(projectFilter: projectId, selectedScope: null);
  }

  Future<void> setStatusFilter(String? status) async {
    state = state.copyWith(statusFilter: status, selectedScope: null);
    await loadScopes();
  }

  Future<void> setPlannedFromFilter(DateTime? date) async {
    state = state.copyWith(plannedFromFilter: date, selectedScope: null);
    await loadScopes();
  }

  Future<void> setPlannedToFilter(DateTime? date) async {
    state = state.copyWith(plannedToFilter: date, selectedScope: null);
    await loadScopes();
  }

  Future<void> resetFilters() async {
    state = state.copyWith(
      statusFilter: null,
      plannedFromFilter: null,
      plannedToFilter: null,
      selectedScope: null,
    );
    await loadScopes();
  }

  Future<void> loadScopes() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final scopes = await _repository.fetchScopes(
        projectId: state.projectFilter,
        status: state.statusFilter,
        plannedFrom: _dateParam(state.plannedFromFilter),
        plannedTo: _dateParam(state.plannedToFilter),
      );
      state = state.copyWith(isLoading: false, scopes: scopes);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: error.toString(),
      );
    }
  }

  Future<void> loadScopeDetail(int scopeId) async {
    state = state.copyWith(isDetailLoading: true, detailError: null);

    try {
      final scope = await _repository.fetchScope(scopeId);
      state = state.copyWith(isDetailLoading: false, selectedScope: scope);
    } catch (error) {
      state = state.copyWith(
        isDetailLoading: false,
        selectedScope: null,
        detailError: error.toString(),
      );
    }
  }

  Future<void> reviewChecklistItem(
    int itemId, {
    required String status,
    String? comment,
  }) async {
    final selectedScopeId = state.selectedScope?.id;
    await _repository.reviewChecklistItem(
      itemId,
      status: status,
      comment: comment,
    );
    await loadScopes();
    if (selectedScopeId != null) {
      await loadScopeDetail(selectedScopeId);
    }
  }

  Future<void> uploadPackageDocument(
    int documentId, {
    required String filePath,
  }) async {
    final selectedScopeId = state.selectedScope?.id;
    await _repository.uploadPackageDocument(documentId, filePath: filePath);
    await loadScopes();
    if (selectedScopeId != null) {
      await loadScopeDetail(selectedScopeId);
    }
  }

  Future<void> createFinding(int sessionId, Map<String, dynamic> data) async {
    await _repository.createFinding(sessionId, data);
    await loadScopes();
  }

  Future<void> resolveFinding(
    int findingId, {
    required String resolutionComment,
  }) async {
    await _repository.resolveFinding(
      findingId,
      resolutionComment: resolutionComment,
    );
    await loadScopes();
  }

  Future<void> readyForReinspection(int scopeId) async {
    await _repository.readyForReinspection(scopeId);
    await loadScopes();
  }

  Future<void> startScope(int scopeId) async {
    await _repository.startScope(scopeId);
    await loadScopes();
  }

  Future<void> acceptScope(int scopeId, {String? comment}) async {
    await _repository.acceptScope(scopeId, comment: comment);
    await loadScopes();
  }

  Future<void> handoverScope(int scopeId) async {
    await _repository.handoverScope(scopeId);
    await loadScopes();
  }

  Future<void> rejectScope(int scopeId, {required String reason}) async {
    await _repository.rejectScope(scopeId, reason: reason);
    await loadScopes();
  }

  Future<void> reopenScope(int scopeId, {required String reason}) async {
    await _repository.reopenScope(scopeId, reason: reason);
    await loadScopes();
  }

  String? _dateParam(DateTime? value) {
    if (value == null) {
      return null;
    }

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final handoverAcceptanceProvider =
    StateNotifierProvider<HandoverAcceptanceNotifier, HandoverAcceptanceState>((
      ref,
    ) {
      return HandoverAcceptanceNotifier(
        ref.read(handoverAcceptanceRepositoryProvider),
      );
    });
