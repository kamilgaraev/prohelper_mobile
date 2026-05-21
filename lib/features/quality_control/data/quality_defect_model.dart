class QualityDefectRef {
  const QualityDefectRef({required this.id, required this.name});

  final int id;
  final String name;

  factory QualityDefectRef.fromJson(Map<String, dynamic> json) {
    return QualityDefectRef(
      id: _asInt(json['id']),
      name:
          json['name']?.toString() ??
          json['full_name']?.toString() ??
          json['title']?.toString() ??
          '',
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
      code: json['code']?.toString() ?? json['key']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      message: json['message']?.toString() ?? json['label']?.toString() ?? '',
    );
  }
}

class QualityDefectWorkflowSummary {
  const QualityDefectWorkflowSummary({
    this.nextAction,
    this.nextActionLabel,
    this.overdue = false,
  });

  final String? nextAction;
  final String? nextActionLabel;
  final bool overdue;

  factory QualityDefectWorkflowSummary.fromJson(Map<String, dynamic> json) {
    final meta = _asMap(json['meta']);

    return QualityDefectWorkflowSummary(
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
    this.caption,
    this.createdAt,
  });

  final int id;
  final String type;
  final String url;
  final String? caption;
  final String? createdAt;

  factory QualityDefectPhotoModel.fromJson(Map<String, dynamic> json) {
    return QualityDefectPhotoModel(
      id: _requiredInt(json, 'id'),
      type: _requiredString(json, 'type'),
      url: _requiredString(json, 'url'),
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
      fromStatus: _asNullableString(json['from_status']),
      toStatus: _requiredString(json, 'to_status'),
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
    this.workflowSummary,
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
  final QualityDefectWorkflowSummary? workflowSummary;
  final List<QualityDefectPhotoModel> photos;
  final List<QualityDefectHistoryModel> statusHistory;
  final List<QualityDefectProblemFlag> problemFlags;

  int get serverId => id;
  String get projectName => project?.name ?? '';
  String get assignedUserName => assignedUser?.name ?? '';

  bool get isOverdue =>
      workflowSummary?.overdue == true ||
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
    final workflow = _asMap(json['workflow_summary']);

    return QualityDefectModel(
      id: _requiredInt(json, 'id'),
      defectNumber: _requiredString(json, 'defect_number'),
      title: _requiredString(json, 'title'),
      description: json['description']?.toString(),
      severity: _requiredString(json, 'severity'),
      severityLabel: json['severity_label']?.toString(),
      status: _requiredString(json, 'status'),
      statusLabel: json['status_label']?.toString(),
      availableActions: _actions(json['available_actions']),
      locationName: json['location_name']?.toString(),
      dueDate: json['due_date']?.toString(),
      inspectionRequired: _requiredBool(json, 'inspection_required'),
      project: project.isEmpty ? null : QualityDefectRef.fromJson(project),
      contractor:
          contractor.isEmpty ? null : QualityDefectRef.fromJson(contractor),
      assignedUser:
          assignedUser.isEmpty ? null : QualityDefectRef.fromJson(assignedUser),
      workflowSummary:
          workflow.isEmpty
              ? null
              : QualityDefectWorkflowSummary.fromJson(workflow),
      photos: _photos(json['photos']),
      statusHistory: _history(json['status_history']),
      problemFlags:
          (json['problem_flags'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => QualityDefectProblemFlag.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
    );
  }
}

List<QualityDefectPhotoModel> _photos(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map(
        (item) => QualityDefectPhotoModel.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList();
}

List<QualityDefectHistoryModel> _history(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map(
        (item) => QualityDefectHistoryModel.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList();
}

List<String> _actions(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) {
        if (item is Map) {
          return item['key']?.toString() ??
              item['action']?.toString() ??
              item['name']?.toString() ??
              '';
        }

        return item.toString();
      })
      .where((item) => item.isNotEmpty)
      .toList();
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing boolean field: $key');
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
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
