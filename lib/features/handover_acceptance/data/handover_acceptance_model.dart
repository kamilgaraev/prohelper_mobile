class HandoverReference {
  const HandoverReference({required this.id, required this.name});

  final int id;
  final String name;

  factory HandoverReference.fromJson(Map<String, dynamic> json) {
    return HandoverReference(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class HandoverProblemFlag {
  const HandoverProblemFlag({
    required this.key,
    required this.severity,
    required this.label,
    required this.count,
  });

  final String key;
  final String severity;
  final String label;
  final int count;

  factory HandoverProblemFlag.fromJson(Map<String, dynamic> json) {
    return HandoverProblemFlag(
      key: json['key']?.toString() ?? json['code']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      label: json['label']?.toString() ?? json['message']?.toString() ?? '',
      count: _asInt(json['count']),
    );
  }
}

class HandoverWorkflowSummary {
  const HandoverWorkflowSummary({
    required this.status,
    required this.availableActions,
    required this.problemFlags,
  });

  final String status;
  final List<String> availableActions;
  final List<HandoverProblemFlag> problemFlags;

  factory HandoverWorkflowSummary.fromJson(Map<String, dynamic> json) {
    return HandoverWorkflowSummary(
      status: json['status']?.toString() ?? '',
      availableActions: _asStringList(json['available_actions']),
      problemFlags:
          _asMapList(
            json['problem_flags'],
          ).map(HandoverProblemFlag.fromJson).toList(),
    );
  }
}

class HandoverLocation {
  const HandoverLocation({required this.id, required this.name, this.path});

  final int id;
  final String name;
  final String? path;

  factory HandoverLocation.fromJson(Map<String, dynamic> json) {
    return HandoverLocation(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString(),
    );
  }
}

class AcceptanceFindingModel {
  const AcceptanceFindingModel({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.severity,
    required this.status,
    this.description,
    this.qualityDefectId,
  });

  final int id;
  final int sessionId;
  final int? qualityDefectId;
  final String title;
  final String? description;
  final String severity;
  final String status;

  bool get isOpen => status == 'open';

  factory AcceptanceFindingModel.fromJson(Map<String, dynamic> json) {
    return AcceptanceFindingModel(
      id: _asInt(json['id']),
      sessionId: _asInt(json['acceptance_session_id']),
      qualityDefectId: _nullableInt(json['quality_defect_id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      severity: json['severity']?.toString() ?? 'major',
      status: json['status']?.toString() ?? 'open',
    );
  }
}

class HandoverPackageDocumentModel {
  const HandoverPackageDocumentModel({
    required this.id,
    required this.title,
    required this.required,
    required this.status,
  });

  final int id;
  final String title;
  final bool required;
  final String status;

  bool get approved => status == 'approved';

  factory HandoverPackageDocumentModel.fromJson(Map<String, dynamic> json) {
    return HandoverPackageDocumentModel(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      required: json['is_required'] == true,
      status: json['status']?.toString() ?? 'missing',
    );
  }
}

class HandoverPackageModel {
  const HandoverPackageModel({
    required this.id,
    required this.title,
    required this.status,
    required this.documents,
  });

  final int id;
  final String title;
  final String status;
  final List<HandoverPackageDocumentModel> documents;

  int get approvedRequiredDocuments =>
      documents
          .where((document) => document.required && document.approved)
          .length;

  int get requiredDocuments =>
      documents.where((document) => document.required).length;

  factory HandoverPackageModel.fromJson(Map<String, dynamic> json) {
    return HandoverPackageModel(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      documents:
          _asMapList(
            json['documents'],
          ).map(HandoverPackageDocumentModel.fromJson).toList(),
    );
  }
}

class AcceptanceSessionModel {
  const AcceptanceSessionModel({
    required this.id,
    required this.status,
    required this.findings,
  });

  final int id;
  final String status;
  final List<AcceptanceFindingModel> findings;

  factory AcceptanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AcceptanceSessionModel(
      id: _asInt(json['id']),
      status: json['status']?.toString() ?? '',
      findings:
          _asMapList(
            json['findings'],
          ).map(AcceptanceFindingModel.fromJson).toList(),
    );
  }
}

class AcceptanceScopeModel {
  const AcceptanceScopeModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.workflowSummary,
    required this.sessions,
    required this.findings,
    this.description,
    this.project,
    this.location,
    this.handoverPackage,
  });

  final int id;
  final int projectId;
  final String title;
  final String? description;
  final String status;
  final HandoverWorkflowSummary workflowSummary;
  final HandoverReference? project;
  final HandoverLocation? location;
  final List<AcceptanceSessionModel> sessions;
  final List<AcceptanceFindingModel> findings;
  final HandoverPackageModel? handoverPackage;

  int get openFindings => findings.where((finding) => finding.isOpen).length;

  String get locationLabel => location?.path ?? location?.name ?? '';

  factory AcceptanceScopeModel.fromJson(Map<String, dynamic> json) {
    final workflow = _asMap(json['workflow_summary']);
    final project = _asMap(json['project']);
    final location = _asMap(json['location']);
    final package = _asMap(json['handover_package']);

    return AcceptanceScopeModel(
      id: _asInt(json['id']),
      projectId: _asInt(json['project_id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? '',
      workflowSummary:
          workflow.isEmpty
              ? HandoverWorkflowSummary(
                status: json['status']?.toString() ?? '',
                availableActions: const [],
                problemFlags: const [],
              )
              : HandoverWorkflowSummary.fromJson(workflow),
      project: project.isEmpty ? null : HandoverReference.fromJson(project),
      location: location.isEmpty ? null : HandoverLocation.fromJson(location),
      sessions:
          _asMapList(
            json['sessions'],
          ).map(AcceptanceSessionModel.fromJson).toList(),
      findings:
          _asMapList(
            json['findings'],
          ).map(AcceptanceFindingModel.fromJson).toList(),
      handoverPackage:
          package.isEmpty ? null : HandoverPackageModel.fromJson(package),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  return _asInt(value);
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

List<Map<String, dynamic>> _asMapList(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

List<String> _asStringList(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}
