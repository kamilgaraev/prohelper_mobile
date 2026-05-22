import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/safety_model.dart';
import '../data/safety_repository.dart';

const _errorSentinel = Object();
const _projectFilterSentinel = Object();
const _statusFilterSentinel = Object();

class SafetyState {
  const SafetyState({
    this.isLoading = false,
    this.projectFilter,
    this.permitStatusFilter,
    this.incidentStatusFilter,
    this.violationStatusFilter,
    this.permits = const [],
    this.incidents = const [],
    this.violations = const [],
    this.permissionDenied = false,
    this.error,
  });

  final bool isLoading;
  final int? projectFilter;
  final String? permitStatusFilter;
  final String? incidentStatusFilter;
  final String? violationStatusFilter;
  final List<SafetyWorkPermitModel> permits;
  final List<SafetyIncidentModel> incidents;
  final List<SafetyViolationModel> violations;
  final bool permissionDenied;
  final String? error;

  SafetyState copyWith({
    bool? isLoading,
    Object? projectFilter = _projectFilterSentinel,
    Object? permitStatusFilter = _statusFilterSentinel,
    Object? incidentStatusFilter = _statusFilterSentinel,
    Object? violationStatusFilter = _statusFilterSentinel,
    List<SafetyWorkPermitModel>? permits,
    List<SafetyIncidentModel>? incidents,
    List<SafetyViolationModel>? violations,
    bool? permissionDenied,
    Object? error = _errorSentinel,
  }) {
    return SafetyState(
      isLoading: isLoading ?? this.isLoading,
      projectFilter:
          identical(projectFilter, _projectFilterSentinel)
              ? this.projectFilter
              : projectFilter as int?,
      permitStatusFilter:
          identical(permitStatusFilter, _statusFilterSentinel)
              ? this.permitStatusFilter
              : permitStatusFilter as String?,
      incidentStatusFilter:
          identical(incidentStatusFilter, _statusFilterSentinel)
              ? this.incidentStatusFilter
              : incidentStatusFilter as String?,
      violationStatusFilter:
          identical(violationStatusFilter, _statusFilterSentinel)
              ? this.violationStatusFilter
              : violationStatusFilter as String?,
      permits: permits ?? this.permits,
      incidents: incidents ?? this.incidents,
      violations: violations ?? this.violations,
      permissionDenied: permissionDenied ?? this.permissionDenied,
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
      permissionDenied: false,
      error: null,
    );
  }

  Future<void> setPermitStatusFilter(String? status) async {
    if (state.permitStatusFilter == status) {
      return;
    }

    state = state.copyWith(permitStatusFilter: status, permits: const []);
    await load();
  }

  Future<void> setIncidentStatusFilter(String? status) async {
    if (state.incidentStatusFilter == status) {
      return;
    }

    state = state.copyWith(incidentStatusFilter: status, incidents: const []);
    await load();
  }

  Future<void> setViolationStatusFilter(String? status) async {
    if (state.violationStatusFilter == status) {
      return;
    }

    state = state.copyWith(violationStatusFilter: status, violations: const []);
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final result = await Future.wait<Object>([
        _repository.fetchPermits(
          projectId: state.projectFilter,
          status: state.permitStatusFilter,
        ),
        _repository.fetchIncidents(
          projectId: state.projectFilter,
          status: state.incidentStatusFilter,
        ),
        _repository.fetchViolations(
          projectId: state.projectFilter,
          status: state.violationStatusFilter,
        ),
      ]);

      state = state.copyWith(
        isLoading: false,
        permits: result[0] as List<SafetyWorkPermitModel>,
        incidents: result[1] as List<SafetyIncidentModel>,
        violations: result[2] as List<SafetyViolationModel>,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: error.toString(),
      );
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

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}
