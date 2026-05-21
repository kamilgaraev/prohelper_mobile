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
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      permitNumber: _requiredString(json, 'permit_number'),
      title: _requiredString(json, 'title'),
      permitType: _requiredString(json, 'permit_type'),
      riskLevel: _requiredString(json, 'risk_level'),
      status: _requiredString(json, 'status'),
      statusLabel: _requiredString(json, 'status_label'),
      validFrom: _requiredString(json, 'valid_from'),
      validUntil: _requiredString(json, 'valid_until'),
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

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}
