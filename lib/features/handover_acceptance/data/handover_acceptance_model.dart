class HandoverReference {
  const HandoverReference({required this.id, required this.name});

  final int id;
  final String name;

  factory HandoverReference.fromJson(Map<String, dynamic> json) {
    return HandoverReference(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
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
      key: _requiredAnyString(json, ['key', 'code']),
      severity: _requiredString(json, 'severity'),
      label: _requiredAnyString(json, ['label', 'message']),
      count: _requiredInt(json, 'count'),
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
      status: _requiredString(json, 'status'),
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
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
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
      id: _requiredInt(json, 'id'),
      sessionId: _requiredInt(json, 'acceptance_session_id'),
      qualityDefectId: _nullableInt(json['quality_defect_id']),
      title: _requiredString(json, 'title'),
      description: json['description']?.toString(),
      severity: _requiredString(json, 'severity'),
      status: _requiredString(json, 'status'),
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
      id: _requiredInt(json, 'id'),
      title: _requiredString(json, 'title'),
      required: _requiredBool(json, 'is_required'),
      status: _requiredString(json, 'status'),
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
      id: _requiredInt(json, 'id'),
      title: _requiredString(json, 'title'),
      status: _requiredString(json, 'status'),
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
      id: _requiredInt(json, 'id'),
      status: _requiredString(json, 'status'),
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
    final workflow = _requiredMap(json, 'workflow_summary');
    final project = _asMap(json['project']);
    final location = _asMap(json['location']);
    final package = _asMap(json['handover_package']);

    return AcceptanceScopeModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      title: _requiredString(json, 'title'),
      description: json['description']?.toString(),
      status: _requiredString(json, 'status'),
      workflowSummary: HandoverWorkflowSummary.fromJson(workflow),
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

String _requiredAnyString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  throw FormatException('Missing string field: ${keys.join('|')}');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing boolean field: $key');
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = _asMap(json[key]);
  if (value.isEmpty) {
    throw FormatException('Missing map field: $key');
  }

  return value;
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
