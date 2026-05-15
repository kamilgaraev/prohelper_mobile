import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/handover_acceptance_model.dart';
import '../data/handover_acceptance_repository.dart';

class HandoverAcceptanceState {
  const HandoverAcceptanceState({
    this.isLoading = false,
    this.scopes = const [],
    this.projectFilter,
    this.error,
  });

  final bool isLoading;
  final List<AcceptanceScopeModel> scopes;
  final int? projectFilter;
  final String? error;

  HandoverAcceptanceState copyWith({
    bool? isLoading,
    List<AcceptanceScopeModel>? scopes,
    int? projectFilter,
    Object? error = _errorSentinel,
  }) {
    return HandoverAcceptanceState(
      isLoading: isLoading ?? this.isLoading,
      scopes: scopes ?? this.scopes,
      projectFilter: projectFilter ?? this.projectFilter,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _errorSentinel = Object();

class HandoverAcceptanceNotifier
    extends StateNotifier<HandoverAcceptanceState> {
  HandoverAcceptanceNotifier(this._repository)
    : super(const HandoverAcceptanceState());

  final HandoverAcceptanceRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(projectFilter: projectId);
  }

  Future<void> loadScopes() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final scopes = await _repository.fetchScopes(
        projectId: state.projectFilter,
      );
      state = state.copyWith(isLoading: false, scopes: scopes);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
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
}

final handoverAcceptanceProvider =
    StateNotifierProvider<HandoverAcceptanceNotifier, HandoverAcceptanceState>((
      ref,
    ) {
      return HandoverAcceptanceNotifier(
        ref.read(handoverAcceptanceRepositoryProvider),
      );
    });
