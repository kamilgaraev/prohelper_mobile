import '../../../core/storage/cached_entity.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/entity_snapshot_store.dart';
import '../../../core/storage/list_snapshot.dart';
import '../../../core/storage/snapshot_read.dart';
import 'safety_model.dart';
import 'safety_repository.dart';

class SafetySnapshotData {
  const SafetySnapshotData({
    this.dashboard,
    this.admission,
    this.permits = const [],
    this.incidents = const [],
    this.violations = const [],
    this.briefings = const [],
    this.inspections = const [],
    this.inspectionFindings = const [],
  });

  final SafetyDashboardModel? dashboard;
  final SafetyAdmissionModel? admission;
  final List<SafetyWorkPermitModel> permits;
  final List<SafetyIncidentModel> incidents;
  final List<SafetyViolationModel> violations;
  final List<SafetyBriefingModel> briefings;
  final List<SafetyInspectionModel> inspections;
  final List<SafetyInspectionFindingModel> inspectionFindings;

  bool get isEmpty {
    return permits.isEmpty &&
        incidents.isEmpty &&
        violations.isEmpty &&
        briefings.isEmpty &&
        inspections.isEmpty &&
        inspectionFindings.isEmpty &&
        admission == null &&
        (dashboard == null || _dashboardEmpty(dashboard!));
  }
}

bool _dashboardEmpty(SafetyDashboardModel dashboard) {
  return dashboard.activePermits == 0 &&
      dashboard.openIncidents == 0 &&
      dashboard.openViolations == 0 &&
      dashboard.openCorrectiveActions == 0 &&
      dashboard.openInspections == 0 &&
      dashboard.openFindings == 0;
}

class SafetySnapshotAdapter {
  SafetySnapshotAdapter({
    required SafetyRepository repository,
    required Future<EntitySnapshotService> snapshots,
    Future<void> Function()? flushQueue,
  }) : _repository = repository,
       _snapshots = snapshots,
       _flushQueue = flushQueue;

  static const permitsType = 'safety_permit';
  static const incidentsType = 'safety_incident';
  static const violationsType = 'safety_violation';
  static const briefingsType = 'safety_briefing';
  static const inspectionsType = 'safety_inspection';
  static const findingsType = 'safety_inspection_finding';
  static const dashboardType = 'safety_dashboard';

  final SafetyRepository _repository;
  final Future<EntitySnapshotService> _snapshots;
  final Future<void> Function()? _flushQueue;

  Future<SnapshotRead<SafetySnapshotData>> load({
    required bool online,
    int? projectId,
    String? permitStatus,
    String? incidentStatus,
    String? violationStatus,
  }) async {
    final cached = await readCached(
      projectId: projectId,
      permitStatus: permitStatus,
      incidentStatus: incidentStatus,
      violationStatus: violationStatus,
    );
    if (!online) {
      return cached;
    }

    EntitySnapshotService? service;
    EntitySnapshotOwner? expectedOwner;
    try {
      await _flushQueue?.call();
      service = await _snapshots;
      final owner = service.currentOwner;
      if (owner == null) return cached;
      expectedOwner = owner;
      final pulledAt = DateTime.now().toUtc();
      final dashboard = await _repository.fetchDashboardPayload(
        projectId: projectId,
      );
      final admission = await _repository.fetchMyAdmissionPayload(
        projectId: projectId,
      );
      await _pullList(
        service,
        type: permitsType,
        projectId: projectId,
        pulledAt: pulledAt,
        expectedOwner: owner,
        replaceFullList: true,
        payloads: await _repository.fetchPermitPayloads(projectId: projectId),
      );
      await _pullList(
        service,
        type: incidentsType,
        projectId: projectId,
        pulledAt: pulledAt,
        expectedOwner: owner,
        replaceFullList: true,
        payloads: await _repository.fetchIncidentPayloads(projectId: projectId),
      );
      await _pullList(
        service,
        type: violationsType,
        projectId: projectId,
        pulledAt: pulledAt,
        expectedOwner: owner,
        replaceFullList: true,
        payloads: await _repository.fetchViolationPayloads(
          projectId: projectId,
        ),
      );
      await _pullList(
        service,
        type: briefingsType,
        projectId: projectId,
        pulledAt: pulledAt,
        expectedOwner: owner,
        replaceFullList: true,
        payloads: await _repository.fetchBriefingPayloads(projectId: projectId),
      );
      await _pullList(
        service,
        type: inspectionsType,
        projectId: projectId,
        pulledAt: pulledAt,
        expectedOwner: owner,
        replaceFullList: true,
        payloads: await _repository.fetchInspectionPayloads(
          projectId: projectId,
        ),
      );
      await _pullList(
        service,
        type: findingsType,
        projectId: projectId,
        pulledAt: pulledAt,
        expectedOwner: owner,
        replaceFullList: true,
        payloads: await _repository.fetchInspectionFindingPayloads(
          projectId: projectId,
          status: 'open',
        ),
      );
      await service.pullAndMerge(dashboardType, () async {
        return [
          cachedEntityFromPayload(
            type: dashboardType,
            remoteId: 'current',
            payload: {
              ...dashboard,
              if (admission != null) 'admission': admission,
            },
            projectId: projectId,
            updatedAt: pulledAt,
          ),
        ];
      }, expectedOwner: owner);
      await service.putSnapshot(
        snapshotCollectionMarker(
          type: dashboardType,
          projectId: projectId,
          at: pulledAt,
        ),
        expectedOwner: owner,
      );
      return readCached(
        projectId: projectId,
        permitStatus: permitStatus,
        incidentStatus: incidentStatus,
        violationStatus: violationStatus,
        fromNetwork: true,
      );
    } catch (error) {
      if (isSnapshotPermissionDenied(error)) {
        if (service != null && expectedOwner != null) {
          for (final type in const [
            permitsType,
            incidentsType,
            violationsType,
            briefingsType,
            inspectionsType,
            findingsType,
            dashboardType,
          ]) {
            await service.invalidateScope(
              type,
              projectId,
              expectedOwner: expectedOwner,
            );
          }
        }
        return SnapshotRead(
          presence: SnapshotPresence.permissionDenied,
          error: snapshotErrorMessage(
            error,
            'Недостаточно прав для просмотра охраны труда.',
          ),
        );
      }
      if (isSnapshotConflict(error)) {
        return SnapshotRead(
          presence: SnapshotPresence.conflict,
          data: cached.data,
          error: SnapshotUserMessages.conflict,
          fromCache: cached.hasData,
          hasDirtyLocal: true,
        );
      }
      if (isSnapshotOffline(error) || cached.hasData) {
        return cached;
      }
      return SnapshotRead(
        presence: SnapshotPresence.error,
        error: snapshotErrorMessage(
          error,
          'Данные охраны труда пришли неполными. Обновите экран и повторите попытку.',
        ),
      );
    }
  }

  Future<SnapshotRead<SafetySnapshotData>> readCached({
    int? projectId,
    String? permitStatus,
    String? incidentStatus,
    String? violationStatus,
    bool fromNetwork = false,
  }) async {
    final permits = await readListSnapshot<SafetyWorkPermitModel>(
      snapshots: _snapshots,
      type: permitsType,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openSafetyOnce,
      decode: _decodePermit,
      matches: (item) => permitStatus == null || item.status == permitStatus,
    );
    final incidents = await readListSnapshot<SafetyIncidentModel>(
      snapshots: _snapshots,
      type: incidentsType,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openSafetyOnce,
      decode: _decodeIncident,
      matches:
          (item) => incidentStatus == null || item.status == incidentStatus,
    );
    final violations = await readListSnapshot<SafetyViolationModel>(
      snapshots: _snapshots,
      type: violationsType,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openSafetyOnce,
      decode: _decodeViolation,
      matches:
          (item) => violationStatus == null || item.status == violationStatus,
    );
    final briefings = await readListSnapshot<SafetyBriefingModel>(
      snapshots: _snapshots,
      type: briefingsType,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openSafetyOnce,
      decode: _decodeBriefing,
    );
    final inspections = await readListSnapshot<SafetyInspectionModel>(
      snapshots: _snapshots,
      type: inspectionsType,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openSafetyOnce,
      decode: _decodeInspection,
    );
    final findings = await readListSnapshot<SafetyInspectionFindingModel>(
      snapshots: _snapshots,
      type: findingsType,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openSafetyOnce,
      decode: _decodeFinding,
    );
    final dashboardRead = await readListSnapshot<CachedEntity>(
      snapshots: _snapshots,
      type: dashboardType,
      projectId: projectId,
      fromNetwork: fromNetwork,
      missingMessage: SnapshotUserMessages.openSafetyOnce,
      decode: (entity) => entity,
    );

    final reads = [
      permits,
      incidents,
      violations,
      briefings,
      inspections,
      findings,
      dashboardRead,
    ];
    if (reads.any(
      (read) => read.presence == SnapshotPresence.permissionDenied,
    )) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    if (reads.every((read) => read.presence == SnapshotPresence.missing)) {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openSafetyOnce,
      );
    }

    final dirty = reads.any((read) => read.hasDirtyLocal);
    final dashboardEntity = (dashboardRead.data ?? const <CachedEntity>[])
        .where((entity) => !isSnapshotCollectionMarker(entity))
        .cast<CachedEntity?>()
        .firstWhere(
          (entity) => entity?.remoteId == 'current',
          orElse: () => null,
        );
    SafetyDashboardModel? dashboard;
    SafetyAdmissionModel? admission;
    if (dashboardEntity != null) {
      final payload = decodeSnapshotPayload(dashboardEntity);
      dashboard = SafetyDashboardModel.fromJson(payload);
      final admissionPayload = payload['admission'];
      if (admissionPayload is Map) {
        admission = SafetyAdmissionModel.fromJson(
          admissionPayload.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }

    final data = SafetySnapshotData(
      dashboard: dashboard,
      admission: admission,
      permits: permits.data ?? const [],
      incidents: incidents.data ?? const [],
      violations: violations.data ?? const [],
      briefings: briefings.data ?? const [],
      inspections: inspections.data ?? const [],
      inspectionFindings: findings.data ?? const [],
    );

    if (dirty) {
      return SnapshotRead(
        presence: SnapshotPresence.conflict,
        data: data,
        error: SnapshotUserMessages.conflict,
        fromCache: !fromNetwork,
        hasDirtyLocal: true,
      );
    }

    if (data.isEmpty) {
      return SnapshotRead(
        presence: SnapshotPresence.empty,
        data: data,
        fromCache: !fromNetwork,
      );
    }

    return SnapshotRead(
      presence: SnapshotPresence.ready,
      data: data,
      fromCache: !fromNetwork,
    );
  }

  Future<void> _pullList(
    EntitySnapshotService service, {
    required String type,
    required int? projectId,
    required DateTime pulledAt,
    required List<Map<String, dynamic>> payloads,
    required EntitySnapshotOwner expectedOwner,
    required bool replaceFullList,
  }) async {
    await service.pullAndMerge(type, () async {
      return [
        for (final payload in payloads)
          cachedEntityFromPayload(
            type: type,
            remoteId: '${payload['id']}',
            payload: payload,
            projectId: projectId ?? snapshotProjectIdOf(payload),
            updatedAt:
                DateTime.tryParse(payload['updated_at']?.toString() ?? '') ??
                pulledAt,
          ),
      ];
    }, expectedOwner: expectedOwner);
    if (replaceFullList) {
      await service.replaceFullList(
        type: type,
        projectId: projectId,
        remoteIds: payloads.map((payload) => '${payload['id']}').toSet(),
        expectedOwner: expectedOwner,
      );
    }
    await service.putSnapshot(
      snapshotCollectionMarker(type: type, projectId: projectId, at: pulledAt),
      expectedOwner: expectedOwner,
    );
  }

  SafetyWorkPermitModel? _decodePermit(CachedEntity entity) {
    try {
      return SafetyWorkPermitModel.fromJson(decodeSnapshotPayload(entity));
    } on FormatException {
      return null;
    }
  }

  SafetyIncidentModel? _decodeIncident(CachedEntity entity) {
    try {
      return SafetyIncidentModel.fromJson(decodeSnapshotPayload(entity));
    } on FormatException {
      return null;
    }
  }

  SafetyViolationModel? _decodeViolation(CachedEntity entity) {
    try {
      return SafetyViolationModel.fromJson(decodeSnapshotPayload(entity));
    } on FormatException {
      return null;
    }
  }

  SafetyBriefingModel? _decodeBriefing(CachedEntity entity) {
    try {
      return SafetyBriefingModel.fromJson(decodeSnapshotPayload(entity));
    } on FormatException {
      return null;
    }
  }

  SafetyInspectionModel? _decodeInspection(CachedEntity entity) {
    try {
      return SafetyInspectionModel.fromJson(decodeSnapshotPayload(entity));
    } on FormatException {
      return null;
    }
  }

  SafetyInspectionFindingModel? _decodeFinding(CachedEntity entity) {
    try {
      return SafetyInspectionFindingModel.fromJson(
        decodeSnapshotPayload(entity),
      );
    } on FormatException {
      return null;
    }
  }
}
