import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/safety_model.dart';
import '../data/safety_repository.dart';
import '../data/safety_snapshot_adapter.dart';

const _errorSentinel = Object();
const _projectFilterSentinel = Object();
const _statusFilterSentinel = Object();
const _dashboardSentinel = Object();
const _admissionSentinel = Object();

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
    this.briefings = const [],
    this.inspections = const [],
    this.inspectionFindings = const [],
    this.dashboard,
    this.myAdmission,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
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
  final List<SafetyBriefingModel> briefings;
  final List<SafetyInspectionModel> inspections;
  final List<SafetyInspectionFindingModel> inspectionFindings;
  final SafetyDashboardModel? dashboard;
  final SafetyAdmissionModel? myAdmission;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
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
    List<SafetyBriefingModel>? briefings,
    List<SafetyInspectionModel>? inspections,
    List<SafetyInspectionFindingModel>? inspectionFindings,
    Object? dashboard = _dashboardSentinel,
    Object? myAdmission = _admissionSentinel,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
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
      briefings: briefings ?? this.briefings,
      inspections: inspections ?? this.inspections,
      inspectionFindings: inspectionFindings ?? this.inspectionFindings,
      dashboard:
          identical(dashboard, _dashboardSentinel)
              ? this.dashboard
              : dashboard as SafetyDashboardModel?,
      myAdmission:
          identical(myAdmission, _admissionSentinel)
              ? this.myAdmission
              : myAdmission as SafetyAdmissionModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class SafetyNotifier extends StateNotifier<SafetyState> {
  SafetyNotifier(
    this._repository, {
    SafetySnapshotAdapter? snapshotAdapter,
    bool Function()? isOnline,
  }) : _snapshotAdapter = snapshotAdapter,
       _isOnline = isOnline,
       super(const SafetyState());

  final SafetyRepository _repository;
  final SafetySnapshotAdapter? _snapshotAdapter;
  final bool Function()? _isOnline;

  bool get isLoading => state.isLoading;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(
      projectFilter: projectId,
      permits: const [],
      incidents: const [],
      violations: const [],
      briefings: const [],
      inspections: const [],
      inspectionFindings: const [],
      dashboard: null,
      myAdmission: null,
      permissionDenied: false,
      fromCache: false,
      hasDirtyLocal: false,
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
      final snapshotAdapter = _snapshotAdapter;
      if (snapshotAdapter != null) {
        final read = await snapshotAdapter.load(
          online: _isOnline?.call() ?? false,
          projectId: state.projectFilter,
          permitStatus: state.permitStatusFilter,
          incidentStatus: state.incidentStatusFilter,
          violationStatus: state.violationStatusFilter,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        final data = denied ? null : read.data;
        state = state.copyWith(
          isLoading: false,
          dashboard: data?.dashboard,
          myAdmission: data?.admission,
          permits: data?.permits ?? const [],
          incidents: data?.incidents ?? const [],
          violations: data?.violations ?? const [],
          briefings: data?.briefings ?? const [],
          inspections: data?.inspections ?? const [],
          inspectionFindings: data?.inspectionFindings ?? const [],
          permissionDenied: denied,
          fromCache: !denied && read.fromCache,
          hasDirtyLocal: !denied && read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final result = await Future.wait<Object?>([
        _repository.fetchDashboard(projectId: state.projectFilter),
        _repository.fetchMyAdmission(projectId: state.projectFilter),
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
        _repository.fetchBriefings(projectId: state.projectFilter),
        _repository.fetchInspections(projectId: state.projectFilter),
        _repository.fetchInspectionFindings(
          projectId: state.projectFilter,
          status: 'open',
        ),
      ]);

      state = state.copyWith(
        isLoading: false,
        dashboard: result[0] as SafetyDashboardModel,
        myAdmission: result[1] as SafetyAdmissionModel?,
        permits: result[2] as List<SafetyWorkPermitModel>,
        incidents: result[3] as List<SafetyIncidentModel>,
        violations: result[4] as List<SafetyViolationModel>,
        briefings: result[5] as List<SafetyBriefingModel>,
        inspections: result[6] as List<SafetyInspectionModel>,
        inspectionFindings: result[7] as List<SafetyInspectionFindingModel>,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> createIncident(Map<String, dynamic> data) async {
    await _repository.createIncident(data);
    await load();
  }

  Future<void> createViolation(
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    await _repository.createViolation(data, photoPaths: photoPaths);
    await load();
  }

  Future<void> createInspectionFinding(Map<String, dynamic> data) async {
    await _repository.createInspectionFinding(data);
    await load();
  }

  Future<void> resolveViolation(
    int id,
    String comment, {
    List<String> photoPaths = const [],
  }) async {
    await _repository.resolveViolation(id, comment, photoPaths: photoPaths);
    await load();
  }

  Future<void> signBriefingParticipant({
    required int briefingId,
    required int participantId,
  }) async {
    await _repository.signBriefingParticipant(
      briefingId: briefingId,
      participantId: participantId,
    );
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

final safetySnapshotAdapterProvider = Provider<SafetySnapshotAdapter>((ref) {
  return SafetySnapshotAdapter(
    repository: ref.read(safetyRepositoryProvider),
    snapshots: ref.read(entitySnapshotServiceProvider.future),
    flushQueue: () async {
      await ref.read(syncQueueProvider.notifier).retryPending();
    },
  );
});

final safetyProvider = StateNotifierProvider<SafetyNotifier, SafetyState>((
  ref,
) {
  final notifier = SafetyNotifier(
    ref.read(safetyRepositoryProvider),
    snapshotAdapter: ref.read(safetySnapshotAdapterProvider),
    isOnline: () {
      final auth = ref.read(authProvider);
      return auth is AuthAuthenticated && auth.isOnlineVerified;
    },
  );
  ref.listen<AuthState>(authProvider, (previous, next) {
    final wasOnline =
        previous is AuthAuthenticated && previous.isOnlineVerified;
    final isOnline = next is AuthAuthenticated && next.isOnlineVerified;
    if (!wasOnline && isOnline && !notifier.isLoading) {
      unawaited(notifier.load());
    }
  });
  ref.listen(syncQueueProvider, (previous, next) {
    if (next != null && !notifier.isLoading) unawaited(notifier.load());
  });
  return notifier;
});

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}
