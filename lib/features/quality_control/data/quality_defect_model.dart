class QualityDefectRef {
  const QualityDefectRef({required this.id, required this.name});

  final int id;
  final String name;

  factory QualityDefectRef.fromJson(Map<String, dynamic> json) {
    return QualityDefectRef(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
    );
  }
}

class QualityDefectProblemFlag {
  const QualityDefectProblemFlag({
    required this.code,
    required this.severity,
    required this.message,
  });

  final String code;
  final String severity;
  final String message;

  factory QualityDefectProblemFlag.fromJson(Map<String, dynamic> json) {
    return QualityDefectProblemFlag(
      code: _requiredString(json, 'code'),
      severity: _requiredStringIn(json, 'severity', _problemFlagSeverities),
      message: _requiredString(json, 'message'),
    );
  }
}

class QualityDefectWorkflowSummary {
  const QualityDefectWorkflowSummary({
    required this.status,
    required this.availableActions,
    required this.problemFlags,
    this.nextAction,
    this.nextActionLabel,
    this.overdue = false,
  });

  final String status;
  final List<String> availableActions;
  final List<QualityDefectProblemFlag> problemFlags;
  final String? nextAction;
  final String? nextActionLabel;
  final bool overdue;

  factory QualityDefectWorkflowSummary.fromJson(Map<String, dynamic> json) {
    final meta = _asMap(json['meta']);

    return QualityDefectWorkflowSummary(
      status: _requiredStringIn(json, 'status', _qualityStatuses),
      availableActions: _requiredStringList(json, 'available_actions'),
      problemFlags:
          _requiredMapList(
            json,
            'problem_flags',
          ).map(QualityDefectProblemFlag.fromJson).toList(),
      nextAction: json['next_action']?.toString(),
      nextActionLabel: json['next_action_label']?.toString(),
      overdue: meta['overdue'] == true,
    );
  }
}

class QualityDefectPhotoModel {
  const QualityDefectPhotoModel({
    required this.id,
    required this.type,
    required this.url,
    this.path,
    this.previewUrl,
    this.caption,
    this.createdAt,
  });

  final int id;
  final String type;
  final String url;
  final String? path;
  final String? previewUrl;
  final String? caption;
  final String? createdAt;

  String get displayUrl => previewUrl ?? url;

  factory QualityDefectPhotoModel.fromJson(Map<String, dynamic> json) {
    return QualityDefectPhotoModel(
      id: _requiredInt(json, 'id'),
      type: _requiredStringIn(json, 'type', _photoTypes),
      url: _requiredString(json, 'url'),
      path: _asNullableString(json['path']),
      previewUrl: _asNullableString(json['preview_url']),
      caption: _asNullableString(json['caption']),
      createdAt: _asNullableString(json['created_at']),
    );
  }
}

class QualityDefectHistoryModel {
  const QualityDefectHistoryModel({
    required this.id,
    required this.toStatus,
    this.fromStatus,
    this.comment,
    this.changedAt,
  });

  final int id;
  final String toStatus;
  final String? fromStatus;
  final String? comment;
  final String? changedAt;

  factory QualityDefectHistoryModel.fromJson(Map<String, dynamic> json) {
    return QualityDefectHistoryModel(
      id: _requiredInt(json, 'id'),
      fromStatus: _nullableStatus(json['from_status']),
      toStatus: _requiredStringIn(json, 'to_status', _qualityStatuses),
      comment: _asNullableString(json['comment']),
      changedAt: _asNullableString(json['changed_at']),
    );
  }
}

class QualityDefectModel {
  const QualityDefectModel({
    required this.id,
    required this.defectNumber,
    required this.title,
    required this.severity,
    required this.status,
    required this.availableActions,
    required this.inspectionRequired,
    this.description,
    this.severityLabel,
    this.statusLabel,
    this.locationName,
    this.dueDate,
    this.project,
    this.contractor,
    this.assignedUser,
    required this.workflowSummary,
    this.photos = const [],
    this.statusHistory = const [],
    this.problemFlags = const [],
  });

  final int id;
  final String defectNumber;
  final String title;
  final String? description;
  final String severity;
  final String? severityLabel;
  final String status;
  final String? statusLabel;
  final List<String> availableActions;
  final String? locationName;
  final String? dueDate;
  final bool inspectionRequired;
  final QualityDefectRef? project;
  final QualityDefectRef? contractor;
  final QualityDefectRef? assignedUser;
  final QualityDefectWorkflowSummary workflowSummary;
  final List<QualityDefectPhotoModel> photos;
  final List<QualityDefectHistoryModel> statusHistory;
  final List<QualityDefectProblemFlag> problemFlags;

  int get serverId => id;
  String get projectName => project?.name ?? '';
  String get assignedUserName => assignedUser?.name ?? '';

  bool get isOverdue =>
      workflowSummary.overdue ||
      problemFlags.any((flag) => flag.code == 'quality_defect_overdue');

  bool get canStart =>
      status == 'open' || status == 'assigned' || status == 'rejected';

  bool get canResolve =>
      status == 'open' ||
      status == 'assigned' ||
      status == 'in_progress' ||
      status == 'rejected';

  factory QualityDefectModel.fromJson(Map<String, dynamic> json) {
    final project = _asMap(json['project']);
    final contractor = _asMap(json['contractor']);
    final assignedUser = _asMap(json['assigned_user']);

    return QualityDefectModel(
      id: _requiredInt(json, 'id'),
      defectNumber: _requiredString(json, 'defect_number'),
      title: _requiredString(json, 'title'),
      description: json['description']?.toString(),
      severity: _requiredStringIn(json, 'severity', _qualitySeverities),
      severityLabel: json['severity_label']?.toString(),
      status: _requiredStringIn(json, 'status', _qualityStatuses),
      statusLabel: json['status_label']?.toString(),
      availableActions: _requiredStringList(json, 'available_actions'),
      locationName: json['location_name']?.toString(),
      dueDate: json['due_date']?.toString(),
      inspectionRequired: _requiredBool(json, 'inspection_required'),
      project: project.isEmpty ? null : QualityDefectRef.fromJson(project),
      contractor:
          contractor.isEmpty ? null : QualityDefectRef.fromJson(contractor),
      assignedUser:
          assignedUser.isEmpty ? null : QualityDefectRef.fromJson(assignedUser),
      workflowSummary: QualityDefectWorkflowSummary.fromJson(
        _requiredMap(json, 'workflow_summary'),
      ),
      photos:
          _requiredMapList(
            json,
            'photos',
          ).map(QualityDefectPhotoModel.fromJson).toList(),
      statusHistory:
          _requiredMapList(
            json,
            'status_history',
          ).map(QualityDefectHistoryModel.fromJson).toList(),
      problemFlags:
          _requiredMapList(
            json,
            'problem_flags',
          ).map(QualityDefectProblemFlag.fromJson).toList(),
    );
  }
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

String _requiredStringIn(
  Map<String, dynamic> json,
  String key,
  Set<String> allowed,
) {
  final value = _requiredString(json, key);
  if (!allowed.contains(value)) {
    throw FormatException('Invalid string field: $key');
  }

  return value;
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}

String? _nullableStatus(dynamic value) {
  final text = _asNullableString(value);
  if (text == null) {
    return null;
  }

  if (!_qualityStatuses.contains(text)) {
    throw const FormatException('Invalid nullable status field');
  }

  return text;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing boolean field: $key');
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const {};
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = _asMap(json[key]);
  if (value.isEmpty) {
    throw FormatException('Missing map field: $key');
  }

  return value;
}

List<Map<String, dynamic>> _requiredMapList(
  Map<String, dynamic> json,
  String key,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing list field: $key');
  }

  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }

  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing list field: $key');
  }

  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }

  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}

const _qualityStatuses = {
  'draft',
  'open',
  'assigned',
  'in_progress',
  'ready_for_review',
  'resolved',
  'rejected',
  'cancelled',
};

const _qualitySeverities = {'minor', 'major', 'critical'};

const _photoTypes = {'before', 'after', 'evidence', 'other'};

const _problemFlagSeverities = {'blocker', 'warning'};
