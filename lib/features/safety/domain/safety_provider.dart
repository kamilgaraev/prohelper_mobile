import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/safety_model.dart';
import '../data/safety_repository.dart';

const _errorSentinel = Object();

class SafetyState {
  const SafetyState({
    this.isLoading = false,
    this.projectFilter,
    this.activePermits = const [],
    this.incidents = const [],
    this.violations = const [],
    this.error,
  });

  final bool isLoading;
  final int? projectFilter;
  final List<SafetyWorkPermitModel> activePermits;
  final List<SafetyIncidentModel> incidents;
  final List<SafetyViolationModel> violations;
  final String? error;

  SafetyState copyWith({
    bool? isLoading,
    int? projectFilter,
    List<SafetyWorkPermitModel>? activePermits,
    List<SafetyIncidentModel>? incidents,
    List<SafetyViolationModel>? violations,
    Object? error = _errorSentinel,
  }) {
    return SafetyState(
      isLoading: isLoading ?? this.isLoading,
      projectFilter: projectFilter ?? this.projectFilter,
      activePermits: activePermits ?? this.activePermits,
      incidents: incidents ?? this.incidents,
      violations: violations ?? this.violations,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class SafetyNotifier extends StateNotifier<SafetyState> {
  SafetyNotifier(this._repository) : super(const SafetyState());

  final SafetyRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(projectFilter: projectId);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final permits = await _repository.fetchActivePermits(
        projectId: state.projectFilter,
      );
      final incidents = await _repository.fetchIncidents(
        projectId: state.projectFilter,
      );
      final violations = await _repository.fetchViolations(
        projectId: state.projectFilter,
      );

      state = state.copyWith(
        isLoading: false,
        activePermits: permits,
        incidents: incidents,
        violations: violations,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> createIncident(Map<String, dynamic> data) async {
    await _repository.createIncident(data);
    await load();
  }

  Future<void> createViolation(Map<String, dynamic> data) async {
    await _repository.createViolation(data);
    await load();
  }

  Future<void> resolveViolation(int id, String comment) async {
    await _repository.resolveViolation(id, comment);
    await load();
  }
}

final safetyProvider = StateNotifierProvider<SafetyNotifier, SafetyState>((
  ref,
) {
  return SafetyNotifier(ref.read(safetyRepositoryProvider));
});
