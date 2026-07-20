class LegalDocumentAction {
  const LegalDocumentAction({
    required this.action,
    required this.label,
    required this.enabled,
    required this.blockers,
    this.targetStepId,
    this.expectedInstanceLockVersion,
    this.expectedStepLockVersion,
    this.requiresComment = false,
    this.requiresReason = false,
  });

  final String action;
  final String label;
  final bool enabled;
  final List<String> blockers;
  final int? targetStepId;
  final int? expectedInstanceLockVersion;
  final int? expectedStepLockVersion;
  final bool requiresComment;
  final bool requiresReason;

  factory LegalDocumentAction.fromJson(Map<String, dynamic> json) {
    return LegalDocumentAction(
      action: _string(json['action']),
      label: _string(json['label'], fallback: _string(json['action'])),
      enabled: json['enabled'] == true,
      blockers: _strings(json['blockers']),
      targetStepId: _nullableInt(json['target_step_id']),
      expectedInstanceLockVersion: _nullableInt(json['expected_instance_lock_version']),
      expectedStepLockVersion: _nullableInt(json['expected_step_lock_version']),
      requiresComment: json['requires_comment'] == true,
      requiresReason: json['requires_reason'] == true,
    );
  }
}

class LegalDocumentVersion {
  const LegalDocumentVersion({
    required this.id,
    required this.versionNumber,
    this.fileName,
    this.contentHash,
    this.createdAt,
  });

  final int id;
  final int versionNumber;
  final String? fileName;
  final String? contentHash;
  final DateTime? createdAt;

  factory LegalDocumentVersion.fromJson(Map<String, dynamic> json) {
    return LegalDocumentVersion(
      id: _int(json['id']),
      versionNumber: _int(json['version_number'], fallback: 1),
      fileName: _nullableString(json['file_name']) ?? _nullableString(json['original_filename']),
      contentHash: _nullableString(json['content_hash']),
      createdAt: _date(json['created_at']),
    );
  }
}

class LegalDocumentWorkflow {
  const LegalDocumentWorkflow({
    required this.status,
    required this.actions,
    required this.problemFlags,
  });

  final String status;
  final List<LegalDocumentAction> actions;
  final List<String> problemFlags;

  factory LegalDocumentWorkflow.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return LegalDocumentWorkflow(
      status: _string(data['status'], fallback: 'not_started'),
      actions: _maps(data['available_action_details'])
          .map(LegalDocumentAction.fromJson)
          .toList(growable: false),
      problemFlags: _strings(data['problem_flags']),
    );
  }
}

class LegalDocumentObligation {
  const LegalDocumentObligation({required this.title, required this.status, this.dueAt});
  final String title;
  final String status;
  final DateTime? dueAt;
  factory LegalDocumentObligation.fromJson(Map<String, dynamic> json) => LegalDocumentObligation(
    title: _string(json['title'], fallback: 'Обязательство'), status: _string(json['status'], fallback: 'open'), dueAt: _date(json['due_at']),
  );
}

class LegalDocumentModel {
  const LegalDocumentModel({
    required this.id,
    required this.title,
    required this.documentTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.workflow,
    required this.versions,
    required this.signatureStatus,
    required this.obligations,
    this.documentNumber,
    this.projectName,
    this.counterpartyName,
    this.currentVersion,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String documentTypeLabel;
  final String status;
  final String statusLabel;
  final LegalDocumentWorkflow workflow;
  final List<LegalDocumentVersion> versions;
  final String signatureStatus;
  final List<LegalDocumentObligation> obligations;
  final String? documentNumber;
  final String? projectName;
  final String? counterpartyName;
  final LegalDocumentVersion? currentVersion;
  final DateTime? updatedAt;

  factory LegalDocumentModel.fromJson(Map<String, dynamic> json) {
    final currentVersion = _mapOrNull(json['current_version']);
    final versions = _maps(json['versions'])
        .map(LegalDocumentVersion.fromJson)
        .toList(growable: false);
    return LegalDocumentModel(
      id: _int(json['id']),
      title: _string(json['title'], fallback: 'Юридический документ'),
      documentTypeLabel: _string(json['document_type_label'], fallback: 'Документ'),
      status: _string(json['status']),
      statusLabel: _string(json['status_label'], fallback: _string(json['status'])),
      workflow: LegalDocumentWorkflow.fromJson(_mapOrNull(json['workflow_summary'])),
      versions: versions,
      signatureStatus: _string(
        _mapOrNull(json['signature_summary'])?['status'],
        fallback: 'not_signed',
      ),
      obligations: _maps(json['obligations']).map(LegalDocumentObligation.fromJson).toList(growable: false),
      documentNumber: _nullableString(json['document_number']),
      projectName: _nullableString(_mapOrNull(json['project'])?['name']),
      counterpartyName: _nullableString(json['counterparty_name']),
      currentVersion:
          currentVersion == null ? (versions.isEmpty ? null : versions.first) : LegalDocumentVersion.fromJson(currentVersion),
      updatedAt: _date(json['updated_at']),
    );
  }
}

Map<String, dynamic>? _mapOrNull(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : null;

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map(_mapOrNull).whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.map((item) => _string(item)).where((item) => item.isNotEmpty).toList(growable: false)
    : const [];

String _string(Object? value, {String fallback = ''}) => value is String && value.trim().isNotEmpty ? value : fallback;
String? _nullableString(Object? value) => value is String && value.trim().isNotEmpty ? value : null;
int _int(Object? value, {int fallback = 0}) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
int? _nullableInt(Object? value) => value == null ? null : _int(value);
DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
