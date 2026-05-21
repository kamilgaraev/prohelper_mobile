import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/safety_model.dart';
import '../data/safety_repository.dart';

const _errorSentinel = Object();
const _projectFilterSentinel = Object();

class SafetyState {
  const SafetyState({
    this.isLoading = false,
    this.projectFilter,
    this.permits = const [],
    this.incidents = const [],
    this.violations = const [],
    this.error,
  });

  final bool isLoading;
  final int? projectFilter;
  final List<SafetyWorkPermitModel> permits;
  final List<SafetyIncidentModel> incidents;
  final List<SafetyViolationModel> violations;
  final String? error;

  SafetyState copyWith({
    bool? isLoading,
    Object? projectFilter = _projectFilterSentinel,
    List<SafetyWorkPermitModel>? permits,
    List<SafetyIncidentModel>? incidents,
    List<SafetyViolationModel>? violations,
    Object? error = _errorSentinel,
  }) {
    return SafetyState(
      isLoading: isLoading ?? this.isLoading,
      projectFilter:
          identical(projectFilter, _projectFilterSentinel)
              ? this.projectFilter
              : projectFilter as int?,
      permits: permits ?? this.permits,
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

    state = state.copyWith(
      projectFilter: projectId,
      permits: const [],
      incidents: const [],
      violations: const [],
      error: null,
    );
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await Future.wait<Object>([
        _repository.fetchPermits(projectId: state.projectFilter),
        _repository.fetchIncidents(projectId: state.projectFilter),
        _repository.fetchViolations(projectId: state.projectFilter),
      ]);

      state = state.copyWith(
        isLoading: false,
        permits: result[0] as List<SafetyWorkPermitModel>,
        incidents: result[1] as List<SafetyIncidentModel>,
        violations: result[2] as List<SafetyViolationModel>,
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

  Future<void> submitPermit(int id) async {
    await _repository.submitPermit(id);
    await load();
  }

  Future<void> approvePermit(int id, {String? approvalComment}) async {
    await _repository.approvePermit(id, approvalComment: approvalComment);
    await load();
  }

  Future<void> activatePermit(int id) async {
    await _repository.activatePermit(id);
    await load();
  }

  Future<void> suspendPermit(int id, {required String reason}) async {
    await _repository.suspendPermit(id, reason: reason);
    await load();
  }

  Future<void> resumePermit(int id) async {
    await _repository.resumePermit(id);
    await load();
  }

  Future<void> rejectPermit(int id, {required String reason}) async {
    await _repository.rejectPermit(id, reason: reason);
    await load();
  }

  Future<void> closePermit(int id, {required String closeComment}) async {
    await _repository.closePermit(id, closeComment: closeComment);
    await load();
  }
}

final safetyProvider = StateNotifierProvider<SafetyNotifier, SafetyState>((
  ref,
) {
  return SafetyNotifier(ref.read(safetyRepositoryProvider));
});
