class SafetyProblemFlagModel {
  const SafetyProblemFlagModel({
    required this.code,
    required this.severity,
    required this.message,
  });

  final String code;
  final String severity;
  final String message;

  factory SafetyProblemFlagModel.fromJson(Map<String, dynamic> json) {
    return SafetyProblemFlagModel(
      code: _requiredString(json, 'code'),
      severity: _requiredString(json, 'severity'),
      message: _requiredString(json, 'message'),
    );
  }
}

class SafetyWorkPermitModel {
  const SafetyWorkPermitModel({
    required this.id,
    required this.projectId,
    required this.permitNumber,
    required this.title,
    required this.permitType,
    required this.riskLevel,
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    required this.validFrom,
    required this.validUntil,
    required this.requiredControls,
    this.locationName,
    this.projectName,
    this.approvalComment,
    this.rejectionReason,
    this.suspensionReason,
    this.closeComment,
    this.problemFlags = const [],
    this.participants = const [],
    this.admissionSummary,
  });

  final int id;
  final int projectId;
  final String permitNumber;
  final String title;
  final String permitType;
  final String riskLevel;
  final String status;
  final String statusLabel;
  final List<String> availableActions;
  final String validFrom;
  final String validUntil;
  final List<String> requiredControls;
  final String? locationName;
  final String? projectName;
  final String? approvalComment;
  final String? rejectionReason;
  final String? suspensionReason;
  final String? closeComment;
  final List<SafetyProblemFlagModel> problemFlags;
  final List<SafetyPermitParticipantModel> participants;
  final SafetyAdmissionSummaryModel? admissionSummary;

  factory SafetyWorkPermitModel.fromJson(Map<String, dynamic> json) {
    return SafetyWorkPermitModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      permitNumber: _requiredString(json, 'permit_number'),
      title: _requiredString(json, 'title'),
      permitType: _requiredString(json, 'permit_type'),
      riskLevel: _requiredString(json, 'risk_level'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      availableActions: _requiredStringList(
        json,
        'available_actions',
        allowedValues: _knownPermitActions,
      ),
      validFrom: _requiredString(json, 'valid_from'),
      validUntil: _requiredString(json, 'valid_until'),
      requiredControls: _requiredStringList(json, 'required_controls'),
      locationName: _asNullableString(json['location_name']),
      projectName: _nestedName(json['project']),
      approvalComment: _asNullableString(json['approval_comment']),
      rejectionReason: _asNullableString(json['rejection_reason']),
      suspensionReason: _asNullableString(json['suspension_reason']),
      closeComment: _asNullableString(json['close_comment']),
      problemFlags: _flags(json['problem_flags']),
      participants:
          (json['participants'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (participant) => SafetyPermitParticipantModel.fromJson(
                  participant.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(),
      admissionSummary:
          json['admission_summary'] is Map
              ? SafetyAdmissionSummaryModel.fromJson(
                (json['admission_summary'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              : null,
    );
  }
}

class SafetyPermitParticipantModel {
  const SafetyPermitParticipantModel({
    required this.admissionStatus,
    this.employeeId,
    this.externalName,
    this.employeeName,
    this.roleName,
    this.positionName,
    this.workCategory,
    this.blockers = const [],
    this.warnings = const [],
  });

  final int? employeeId;
  final String? externalName;
  final String? employeeName;
  final String? roleName;
  final String? positionName;
  final String? workCategory;
  final String admissionStatus;
  final List<SafetyProblemFlagModel> blockers;
  final List<SafetyProblemFlagModel> warnings;

  factory SafetyPermitParticipantModel.fromJson(Map<String, dynamic> json) {
    return SafetyPermitParticipantModel(
      employeeId: _asNullableInt(json['employee_id']),
      externalName: _asNullableString(json['external_name']),
      employeeName: _nestedFullName(json['employee']),
      roleName: _asNullableString(json['role_name']),
      positionName: _asNullableString(json['position_name']),
      workCategory: _asNullableString(json['work_category']),
      admissionStatus: json['admission_status']?.toString() ?? 'pending',
      blockers: _flags(json['admission_blockers']),
      warnings: _flags(json['admission_warnings']),
    );
  }
}

class SafetyBriefingSignatureSummaryModel {
  const SafetyBriefingSignatureSummaryModel({
    required this.total,
    required this.signed,
    required this.pending,
    required this.absent,
    required this.refused,
    required this.resolved,
    required this.completionPercent,
    required this.allResolved,
  });

  final int total;
  final int signed;
  final int pending;
  final int absent;
  final int refused;
  final int resolved;
  final double completionPercent;
  final bool allResolved;

  factory SafetyBriefingSignatureSummaryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return SafetyBriefingSignatureSummaryModel(
      total: _asInt(json['total']),
      signed: _asInt(json['signed']),
      pending: _asInt(json['pending']),
      absent: _asInt(json['absent']),
      refused: _asInt(json['refused']),
      resolved: _asInt(json['resolved']),
      completionPercent: _asDouble(json['completion_percent']),
      allResolved: json['all_resolved'] == true,
    );
  }
}

class SafetyBriefingParticipantModel {
  const SafetyBriefingParticipantModel({
    required this.id,
    required this.signatureStatus,
    required this.signatureStatusLabel,
    required this.canSign,
    this.employeeId,
    this.userId,
    this.externalName,
    this.companyName,
    this.roleName,
    this.employeeName,
    this.signedAt,
    this.signatureMethod,
    this.refusalReason,
    this.absenceReason,
  });

  final int id;
  final int? employeeId;
  final int? userId;
  final String? externalName;
  final String? companyName;
  final String? roleName;
  final String? employeeName;
  final String signatureStatus;
  final String signatureStatusLabel;
  final String? signedAt;
  final String? signatureMethod;
  final String? refusalReason;
  final String? absenceReason;
  final bool canSign;

  String get displayName =>
      employeeName ?? externalName ?? companyName ?? 'Участник инструктажа';

  factory SafetyBriefingParticipantModel.fromJson(Map<String, dynamic> json) {
    return SafetyBriefingParticipantModel(
      id: _requiredInt(json, 'id'),
      employeeId: _asNullableInt(json['employee_id']),
      userId: _asNullableInt(json['user_id']),
      externalName: _asNullableString(json['external_name']),
      companyName: _asNullableString(json['company_name']),
      roleName: _asNullableString(json['role_name']),
      employeeName: _nestedFullName(json['employee']),
      signatureStatus: json['signature_status']?.toString() ?? 'pending',
      signatureStatusLabel:
          json['signature_status_label']?.toString() ?? 'Ожидает подписи',
      signedAt: _asNullableString(json['signed_at']),
      signatureMethod: _asNullableString(json['signature_method']),
      refusalReason: _asNullableString(json['refusal_reason']),
      absenceReason: _asNullableString(json['absence_reason']),
      canSign: json['can_sign'] == true,
    );
  }
}

class SafetyBriefingModel {
  const SafetyBriefingModel({
    required this.id,
    required this.projectId,
    required this.briefingNumber,
    required this.title,
    required this.briefingType,
    required this.status,
    required this.statusLabel,
    required this.conductedAt,
    required this.signatureSummary,
    required this.availableActions,
    this.locationName,
    this.projectName,
    this.signatureDeadlineAt,
    this.completedAt,
    this.topics = const [],
    this.participants = const [],
    this.problemFlags = const [],
  });

  final int id;
  final int projectId;
  final String briefingNumber;
  final String title;
  final String briefingType;
  final String status;
  final String statusLabel;
  final String conductedAt;
  final SafetyBriefingSignatureSummaryModel signatureSummary;
  final List<String> availableActions;
  final String? locationName;
  final String? projectName;
  final String? signatureDeadlineAt;
  final String? completedAt;
  final List<String> topics;
  final List<SafetyBriefingParticipantModel> participants;
  final List<SafetyProblemFlagModel> problemFlags;

  List<SafetyBriefingParticipantModel> get signableParticipants =>
      participants.where((participant) => participant.canSign).toList();

  bool get needsMySignature => signableParticipants.isNotEmpty;

  factory SafetyBriefingModel.fromJson(Map<String, dynamic> json) {
    return SafetyBriefingModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      briefingNumber: _requiredString(json, 'briefing_number'),
      title: _requiredString(json, 'title'),
      briefingType: _requiredString(json, 'briefing_type'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      conductedAt: _requiredString(json, 'conducted_at'),
      locationName: _asNullableString(json['location_name']),
      projectName: _nestedName(json['project']),
      signatureDeadlineAt: _asNullableString(json['signature_deadline_at']),
      completedAt: _asNullableString(json['completed_at']),
      signatureSummary: SafetyBriefingSignatureSummaryModel.fromJson(
        _map(json['signature_summary']),
      ),
      availableActions: (json['available_actions'] as List<dynamic>? ??
              const [])
          .map((item) => item.toString())
          .toList(growable: false),
      topics: (json['topics'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      participants:
          (json['participants'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (participant) => SafetyBriefingParticipantModel.fromJson(
                  participant.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(),
      problemFlags: _flags(json['problem_flags']),
    );
  }
}

class SafetyAdmissionSummaryModel {
  const SafetyAdmissionSummaryModel({
    required this.total,
    required this.admitted,
    required this.notAdmitted,
    required this.pending,
    required this.warnings,
  });

  final int total;
  final int admitted;
  final int notAdmitted;
  final int pending;
  final int warnings;

  factory SafetyAdmissionSummaryModel.fromJson(Map<String, dynamic> json) {
    return SafetyAdmissionSummaryModel(
      total: _asInt(json['total']),
      admitted: _asInt(json['admitted']),
      notAdmitted: _asInt(json['not_admitted']),
      pending: _asInt(json['pending']),
      warnings: _asInt(json['warnings']),
    );
  }
}

class SafetyDashboardModel {
  const SafetyDashboardModel({
    required this.activePermits,
    required this.openIncidents,
    required this.openViolations,
    required this.openCorrectiveActions,
    required this.openInspections,
    required this.openFindings,
    required this.myOpenPermits,
    required this.myOpenViolations,
    required this.myOpenFindings,
    required this.myBriefingsToSign,
    this.employeeId,
  });

  final int activePermits;
  final int openIncidents;
  final int openViolations;
  final int openCorrectiveActions;
  final int openInspections;
  final int openFindings;
  final int myOpenPermits;
  final int myOpenViolations;
  final int myOpenFindings;
  final int myBriefingsToSign;
  final int? employeeId;

  factory SafetyDashboardModel.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);
    final mine = _map(json['mine']);

    return SafetyDashboardModel(
      activePermits: _asInt(summary['active_permits']),
      openIncidents: _asInt(summary['open_incidents']),
      openViolations: _asInt(summary['open_violations']),
      openCorrectiveActions: _asInt(summary['open_corrective_actions']),
      openInspections: _asInt(summary['open_inspections']),
      openFindings: _asInt(summary['open_findings']),
      myOpenPermits: _asInt(mine['open_permits']),
      myOpenViolations: _asInt(mine['open_violations']),
      myOpenFindings: _asInt(mine['open_findings']),
      myBriefingsToSign: _asInt(mine['briefings_to_sign']),
      employeeId: _asNullableInt(mine['employee_id']),
    );
  }
}

class SafetyAdmissionModel {
  const SafetyAdmissionModel({
    required this.employeeId,
    required this.status,
    required this.statusLabel,
    required this.blocked,
    required this.expiresSoon,
    this.requirements = const [],
    this.blockers = const [],
    this.warnings = const [],
  });

  final int employeeId;
  final String status;
  final String statusLabel;
  final bool blocked;
  final bool expiresSoon;
  final List<SafetyAdmissionRequirementModel> requirements;
  final List<SafetyProblemFlagModel> blockers;
  final List<SafetyProblemFlagModel> warnings;

  factory SafetyAdmissionModel.fromJson(Map<String, dynamic> json) {
    return SafetyAdmissionModel(
      employeeId: _requiredInt(json, 'employee_id'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      blocked: json['blocked'] == true,
      expiresSoon: json['expires_soon'] == true,
      requirements:
          _list(
            json['requirements'],
          ).map(SafetyAdmissionRequirementModel.fromJson).toList(),
      blockers: _flags(json['blockers']),
      warnings: _flags(json['warnings']),
    );
  }
}

class SafetyAdmissionRequirementModel {
  const SafetyAdmissionRequirementModel({
    required this.code,
    required this.type,
    required this.label,
    required this.status,
    this.message,
    this.validUntil,
  });

  final String code;
  final String type;
  final String label;
  final String status;
  final String? message;
  final String? validUntil;

  factory SafetyAdmissionRequirementModel.fromJson(Map<String, dynamic> json) {
    return SafetyAdmissionRequirementModel(
      code: _requiredString(json, 'code'),
      type: _requiredString(json, 'type'),
      label: _requiredString(json, 'label'),
      status: _requiredString(json, 'status'),
      message: _asNullableString(json['message']),
      validUntil: _asNullableString(json['valid_until']),
    );
  }
}

class SafetyIncidentModel {
  const SafetyIncidentModel({
    required this.id,
    required this.projectId,
    required this.incidentNumber,
    required this.title,
    required this.incidentType,
    required this.severity,
    required this.status,
    required this.statusLabel,
    required this.occurredAt,
    this.locationName,
    this.description,
    this.immediateActions,
    this.problemFlags = const [],
  });

  final int id;
  final int projectId;
  final String incidentNumber;
  final String title;
  final String incidentType;
  final String severity;
  final String status;
  final String statusLabel;
  final String occurredAt;
  final String? locationName;
  final String? description;
  final String? immediateActions;
  final List<SafetyProblemFlagModel> problemFlags;

  factory SafetyIncidentModel.fromJson(Map<String, dynamic> json) {
    return SafetyIncidentModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      incidentNumber: _requiredString(json, 'incident_number'),
      title: _requiredString(json, 'title'),
      incidentType: _requiredString(json, 'incident_type'),
      severity: _requiredString(json, 'severity'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      occurredAt: _requiredString(json, 'occurred_at'),
      locationName: _asNullableString(json['location_name']),
      description: _asNullableString(json['description']),
      immediateActions: _asNullableString(json['immediate_actions']),
      problemFlags: _flags(json['problem_flags']),
    );
  }
}

class SafetyViolationModel {
  const SafetyViolationModel({
    required this.id,
    required this.projectId,
    required this.violationNumber,
    required this.title,
    required this.severity,
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    this.locationName,
    this.description,
    this.correctiveAction,
    this.dueDate,
    this.problemFlags = const [],
  });

  final int id;
  final int projectId;
  final String violationNumber;
  final String title;
  final String severity;
  final String status;
  final String statusLabel;
  final List<String> availableActions;
  final String? locationName;
  final String? description;
  final String? correctiveAction;
  final String? dueDate;
  final List<SafetyProblemFlagModel> problemFlags;

  factory SafetyViolationModel.fromJson(Map<String, dynamic> json) {
    return SafetyViolationModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      violationNumber: _requiredString(json, 'violation_number'),
      title: _requiredString(json, 'title'),
      severity: _requiredString(json, 'severity'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      availableActions:
          (json['available_actions'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      locationName: _asNullableString(json['location_name']),
      description: _asNullableString(json['description']),
      correctiveAction: _asNullableString(json['corrective_action']),
      dueDate: _asNullableString(json['due_date']),
      problemFlags: _flags(json['problem_flags']),
    );
  }
}

class SafetyInspectionModel {
  const SafetyInspectionModel({
    required this.id,
    required this.projectId,
    required this.inspectionNumber,
    required this.title,
    required this.inspectionType,
    required this.status,
    required this.statusLabel,
    this.locationName,
    this.result,
    this.resultLabel,
    this.plannedAt,
    this.conductedAt,
    this.itemsCount = 0,
    this.findingsCount = 0,
  });

  final int id;
  final int projectId;
  final String inspectionNumber;
  final String title;
  final String inspectionType;
  final String status;
  final String statusLabel;
  final String? locationName;
  final String? result;
  final String? resultLabel;
  final String? plannedAt;
  final String? conductedAt;
  final int itemsCount;
  final int findingsCount;

  factory SafetyInspectionModel.fromJson(Map<String, dynamic> json) {
    return SafetyInspectionModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      inspectionNumber: _requiredString(json, 'inspection_number'),
      title: _requiredString(json, 'title'),
      inspectionType: _requiredString(json, 'inspection_type'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      locationName: _asNullableString(json['location_name']),
      result: _asNullableString(json['result']),
      resultLabel: _asNullableString(json['result_label']),
      plannedAt: _asNullableString(json['planned_at']),
      conductedAt: _asNullableString(json['conducted_at']),
      itemsCount: (json['items'] as List<dynamic>? ?? const []).length,
      findingsCount: (json['findings'] as List<dynamic>? ?? const []).length,
    );
  }
}

class SafetyInspectionFindingModel {
  const SafetyInspectionFindingModel({
    required this.id,
    required this.projectId,
    required this.findingNumber,
    required this.title,
    required this.severity,
    required this.status,
    required this.statusLabel,
    this.description,
    this.dueDate,
    this.problemFlags = const [],
  });

  final int id;
  final int projectId;
  final String findingNumber;
  final String title;
  final String severity;
  final String status;
  final String statusLabel;
  final String? description;
  final String? dueDate;
  final List<SafetyProblemFlagModel> problemFlags;

  factory SafetyInspectionFindingModel.fromJson(Map<String, dynamic> json) {
    return SafetyInspectionFindingModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      findingNumber: _requiredString(json, 'finding_number'),
      title: _requiredString(json, 'title'),
      severity: _requiredString(json, 'severity'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      description: _asNullableString(json['description']),
      dueDate: _asNullableString(json['due_date']),
      problemFlags: _flags(json['problem_flags']),
    );
  }
}

const _knownPermitActions = {
  'submit',
  'approve',
  'reject',
  'activate',
  'suspend',
  'resume',
  'close',
};

List<SafetyProblemFlagModel> _flags(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map(
        (flag) => SafetyProblemFlagModel.fromJson(
          flag.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList();
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

String? _nestedName(dynamic value) {
  if (value is Map) {
    return _asNullableString(value['name']);
  }

  return null;
}

String? _nestedFullName(dynamic value) {
  if (value is Map) {
    return _asNullableString(value['full_name']) ??
        _asNullableString(value['name']);
  }

  return null;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  return _asInt(value);
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Missing integer field: $key');
  }

  return parsed;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing string field: $key');
  }

  return value;
}

List<String> _requiredStringList(
  Map<String, dynamic> json,
  String key, {
  Set<String>? allowedValues,
}) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Missing list field: $key');
  }

  return value
      .map((item) {
        final text = item?.toString().trim() ?? '';
        if (text.isEmpty) {
          throw FormatException('Invalid list item field: $key');
        }
        if (allowedValues != null && !allowedValues.contains(text)) {
          throw FormatException('Unknown list item field: $key');
        }

        return text;
      })
      .toList(growable: false);
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}
