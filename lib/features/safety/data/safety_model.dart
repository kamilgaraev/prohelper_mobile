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
      code: _asString(json['code']),
      severity: _asString(json['severity']),
      message: _asString(json['message']),
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
    required this.validFrom,
    required this.validUntil,
    this.locationName,
    this.projectName,
    this.problemFlags = const [],
  });

  final int id;
  final int projectId;
  final String permitNumber;
  final String title;
  final String permitType;
  final String riskLevel;
  final String status;
  final String statusLabel;
  final String validFrom;
  final String validUntil;
  final String? locationName;
  final String? projectName;
  final List<SafetyProblemFlagModel> problemFlags;

  factory SafetyWorkPermitModel.fromJson(Map<String, dynamic> json) {
    return SafetyWorkPermitModel(
      id: _asInt(json['id']),
      projectId: _asInt(json['project_id']),
      permitNumber: _asString(json['permit_number']),
      title: _asString(json['title']),
      permitType: _asString(json['permit_type']),
      riskLevel: _asString(json['risk_level']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
      validFrom: _asString(json['valid_from']),
      validUntil: _asString(json['valid_until']),
      locationName: _asNullableString(json['location_name']),
      projectName: _nestedName(json['project']),
      problemFlags: _flags(json['problem_flags']),
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
  final List<SafetyProblemFlagModel> problemFlags;

  factory SafetyIncidentModel.fromJson(Map<String, dynamic> json) {
    return SafetyIncidentModel(
      id: _asInt(json['id']),
      projectId: _asInt(json['project_id']),
      incidentNumber: _asString(json['incident_number']),
      title: _asString(json['title']),
      incidentType: _asString(json['incident_type']),
      severity: _asString(json['severity']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
      occurredAt: _asString(json['occurred_at']),
      locationName: _asNullableString(json['location_name']),
      description: _asNullableString(json['description']),
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
      id: _asInt(json['id']),
      projectId: _asInt(json['project_id']),
      violationNumber: _asString(json['violation_number']),
      title: _asString(json['title']),
      severity: _asString(json['severity']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
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

String? _nestedName(dynamic value) {
  if (value is Map) {
    return _asNullableString(value['name']);
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

String _asString(dynamic value) => value?.toString() ?? '';

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}
