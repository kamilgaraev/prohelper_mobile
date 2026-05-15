class QualityDefectRef {
  const QualityDefectRef({required this.id, required this.name});

  final int id;
  final String name;

  factory QualityDefectRef.fromJson(Map<String, dynamic> json) {
    return QualityDefectRef(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
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
      code: json['code']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
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
  final List<QualityDefectProblemFlag> problemFlags;

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
      id: _asInt(json['id']),
      defectNumber: json['defect_number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      severity: json['severity']?.toString() ?? 'major',
      severityLabel: json['severity_label']?.toString(),
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString(),
      availableActions:
          (json['available_actions'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(),
      locationName: json['location_name']?.toString(),
      dueDate: json['due_date']?.toString(),
      inspectionRequired: json['inspection_required'] == true,
      project: project.isEmpty ? null : QualityDefectRef.fromJson(project),
      contractor:
          contractor.isEmpty ? null : QualityDefectRef.fromJson(contractor),
      assignedUser:
          assignedUser.isEmpty ? null : QualityDefectRef.fromJson(assignedUser),
      workflowSummary:
          workflow.isEmpty
              ? null
              : QualityDefectWorkflowSummary.fromJson(workflow),
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
