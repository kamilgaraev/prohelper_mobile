class JournalPaginationMeta {
  const JournalPaginationMeta({
    required this.currentPage,
    required this.perPage,
    required this.lastPage,
    required this.total,
  });

  final int currentPage;
  final int perPage;
  final int lastPage;
  final int total;

  factory JournalPaginationMeta.fromJson(Map<String, dynamic> json) {
    return JournalPaginationMeta(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 0,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConstructionJournalSummary {
  const ConstructionJournalSummary({
    this.totalJournals = 0,
    this.activeJournals = 0,
    this.archivedJournals = 0,
    this.closedJournals = 0,
    this.totalEntries = 0,
    this.approvedEntries = 0,
    this.submittedEntries = 0,
    this.rejectedEntries = 0,
  });

  final int totalJournals;
  final int activeJournals;
  final int archivedJournals;
  final int closedJournals;
  final int totalEntries;
  final int approvedEntries;
  final int submittedEntries;
  final int rejectedEntries;

  factory ConstructionJournalSummary.fromJson(Map<String, dynamic> json) {
    return ConstructionJournalSummary(
      totalJournals: (json['total_journals'] as num?)?.toInt() ?? 0,
      activeJournals: (json['active_journals'] as num?)?.toInt() ?? 0,
      archivedJournals: (json['archived_journals'] as num?)?.toInt() ?? 0,
      closedJournals: (json['closed_journals'] as num?)?.toInt() ?? 0,
      totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
      approvedEntries: (json['approved_entries'] as num?)?.toInt() ?? 0,
      submittedEntries: (json['submitted_entries'] as num?)?.toInt() ?? 0,
      rejectedEntries: (json['rejected_entries'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConstructionJournalProjectRef {
  const ConstructionJournalProjectRef({required this.id, required this.name});

  final int id;
  final String name;

  factory ConstructionJournalProjectRef.fromJson(Map<String, dynamic> json) {
    return ConstructionJournalProjectRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class ConstructionJournalScheduleTaskRef {
  const ConstructionJournalScheduleTaskRef({
    required this.id,
    required this.name,
    this.quantity,
    this.measurementUnit,
  });

  final int id;
  final String name;
  final double? quantity;
  final String? measurementUnit;

  factory ConstructionJournalScheduleTaskRef.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalScheduleTaskRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      quantity: _parseNullableDouble(json['quantity']),
      measurementUnit: json['measurement_unit'] as String?,
    );
  }
}

class ConstructionJournalMeasurementUnitRef {
  const ConstructionJournalMeasurementUnitRef({
    required this.id,
    required this.name,
    this.shortName,
  });

  final int id;
  final String name;
  final String? shortName;

  String get displayName =>
      (shortName ?? '').trim().isNotEmpty ? shortName!.trim() : name;

  factory ConstructionJournalMeasurementUnitRef.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalMeasurementUnitRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      shortName: json['short_name'] as String?,
    );
  }
}

class ConstructionJournalWorkTypeOption {
  const ConstructionJournalWorkTypeOption({
    required this.id,
    required this.name,
    this.measurementUnitId,
    this.measurementUnit,
  });

  final int id;
  final String name;
  final int? measurementUnitId;
  final ConstructionJournalMeasurementUnitRef? measurementUnit;

  factory ConstructionJournalWorkTypeOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final measurementUnitPayload = _asMap(json['measurementUnit']);

    return ConstructionJournalWorkTypeOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      measurementUnitId: (json['measurement_unit_id'] as num?)?.toInt(),
      measurementUnit:
          measurementUnitPayload.isEmpty
              ? null
              : ConstructionJournalMeasurementUnitRef.fromJson(
                measurementUnitPayload,
              ),
    );
  }
}

class ConstructionJournalEstimateItemOption {
  const ConstructionJournalEstimateItemOption({
    required this.id,
    required this.estimateId,
    required this.name,
    this.positionNumber,
    this.quantity = 0,
    this.workTypeId,
    this.measurementUnitId,
    this.workType,
    this.measurementUnit,
    this.contractLinks = const [],
  });

  final int id;
  final int estimateId;
  final String name;
  final String? positionNumber;
  final double quantity;
  final int? workTypeId;
  final int? measurementUnitId;
  final ConstructionJournalWorkTypeOption? workType;
  final ConstructionJournalMeasurementUnitRef? measurementUnit;
  final List<Map<String, dynamic>> contractLinks;

  String get displayName {
    final position = (positionNumber ?? '').trim();
    return position.isEmpty ? name : '$position - $name';
  }

  factory ConstructionJournalEstimateItemOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final workTypePayload = _asMap(json['workType']);
    final measurementUnitPayload = _asMap(json['measurementUnit']);

    return ConstructionJournalEstimateItemOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      estimateId: (json['estimate_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      positionNumber: json['position_number'] as String?,
      quantity:
          _parseNullableDouble(json['quantity']) ??
          _parseNullableDouble(json['quantity_total']) ??
          0,
      workTypeId: (json['work_type_id'] as num?)?.toInt(),
      measurementUnitId: (json['measurement_unit_id'] as num?)?.toInt(),
      workType:
          workTypePayload.isEmpty
              ? null
              : ConstructionJournalWorkTypeOption.fromJson(workTypePayload),
      measurementUnit:
          measurementUnitPayload.isEmpty
              ? null
              : ConstructionJournalMeasurementUnitRef.fromJson(
                measurementUnitPayload,
              ),
      contractLinks:
          (json['contract_links'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList(),
    );
  }
}

class ConstructionJournalEstimateOption {
  const ConstructionJournalEstimateOption({
    required this.id,
    required this.name,
    this.number,
    this.items = const [],
  });

  final int id;
  final String name;
  final String? number;
  final List<ConstructionJournalEstimateItemOption> items;

  String get displayName {
    final label = (name.trim().isNotEmpty ? name : 'Смета #$id').trim();
    final estimateNumber = (number ?? '').trim();
    return estimateNumber.isEmpty ? label : '$estimateNumber - $label';
  }

  factory ConstructionJournalEstimateOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalEstimateOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      number: json['number'] as String?,
      items:
          (json['items'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => ConstructionJournalEstimateItemOption.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
    );
  }
}

class ConstructionJournalEntryFormOptions {
  const ConstructionJournalEntryFormOptions({
    required this.estimates,
    required this.workTypes,
    this.projectMaterials = const [],
  });

  final List<ConstructionJournalEstimateOption> estimates;
  final List<ConstructionJournalWorkTypeOption> workTypes;
  final List<ConstructionJournalProjectMaterialOption> projectMaterials;

  factory ConstructionJournalEntryFormOptions.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalEntryFormOptions(
      estimates:
          (json['estimates'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (estimate) => ConstructionJournalEstimateOption.fromJson(
                  estimate.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
      workTypes:
          (json['work_types'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (workType) => ConstructionJournalWorkTypeOption.fromJson(
                  workType.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
      projectMaterials:
          (json['project_materials'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (material) => ConstructionJournalProjectMaterialOption.fromJson(
                  material.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((material) => material.materialId > 0)
              .toList(),
    );
  }
}

class ConstructionJournalProjectMaterialOption {
  const ConstructionJournalProjectMaterialOption({
    required this.deliveryId,
    required this.materialId,
    required this.materialName,
    required this.availableQuantity,
    required this.measurementUnit,
    this.status,
    this.acceptedAt,
  });

  final int deliveryId;
  final int materialId;
  final String materialName;
  final double availableQuantity;
  final String measurementUnit;
  final String? status;
  final String? acceptedAt;

  factory ConstructionJournalProjectMaterialOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final measurementUnit = _asMap(json['measurement_unit']);

    return ConstructionJournalProjectMaterialOption(
      deliveryId:
          (json['delivery_id'] as num?)?.toInt() ??
          (json['project_material_delivery_id'] as num?)?.toInt() ??
          0,
      materialId: (json['material_id'] as num?)?.toInt() ?? 0,
      materialName:
          json['material_name'] as String? ?? json['name'] as String? ?? '',
      availableQuantity: _parseNullableDouble(json['available_quantity']) ?? 0,
      measurementUnit:
          measurementUnit['short_name'] as String? ??
          measurementUnit['name'] as String? ??
          json['measurement_unit'] as String? ??
          '',
      status: json['status'] as String?,
      acceptedAt: json['accepted_at'] as String?,
    );
  }
}

class ConstructionJournalMaterialUsageModel {
  const ConstructionJournalMaterialUsageModel({
    this.materialId,
    required this.materialName,
    required this.quantity,
    required this.measurementUnit,
    this.notes,
  });

  final int? materialId;
  final String materialName;
  final double quantity;
  final String measurementUnit;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      if (materialId != null) 'material_id': materialId,
      'material_name': materialName,
      'quantity': quantity,
      'measurement_unit': measurementUnit,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

class ConstructionJournalWorkVolumeModel {
  const ConstructionJournalWorkVolumeModel({
    this.id,
    this.estimateItemId,
    this.workTypeId,
    this.quantity = 0,
    this.measurementUnitId,
    this.notes,
    this.title,
    this.measurementUnitName,
  });

  final int? id;
  final int? estimateItemId;
  final int? workTypeId;
  final double quantity;
  final int? measurementUnitId;
  final String? notes;
  final String? title;
  final String? measurementUnitName;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (estimateItemId != null) 'estimate_item_id': estimateItemId,
      if (workTypeId != null) 'work_type_id': workTypeId,
      'quantity': quantity,
      if (measurementUnitId != null) 'measurement_unit_id': measurementUnitId,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }

  factory ConstructionJournalWorkVolumeModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final estimateItem = _asMap(json['estimateItem']);
    final workType = _asMap(json['workType']);
    final measurementUnit = _asMap(json['measurementUnit']);

    return ConstructionJournalWorkVolumeModel(
      id: (json['id'] as num?)?.toInt(),
      estimateItemId: (json['estimate_item_id'] as num?)?.toInt(),
      workTypeId: (json['work_type_id'] as num?)?.toInt(),
      quantity: _parseNullableDouble(json['quantity']) ?? 0,
      measurementUnitId: (json['measurement_unit_id'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      title: (estimateItem['name'] ?? workType['name']) as String?,
      measurementUnitName:
          (measurementUnit['short_name'] ?? measurementUnit['name']) as String?,
    );
  }
}

class ConstructionJournalBlockerModel {
  const ConstructionJournalBlockerModel({
    required this.code,
    required this.message,
    required this.target,
    required this.canOverride,
    this.journalWorkVolumeId,
  });

  final String code;
  final String message;
  final String target;
  final bool canOverride;
  final int? journalWorkVolumeId;

  factory ConstructionJournalBlockerModel.fromJson(Map<String, dynamic> json) {
    return ConstructionJournalBlockerModel(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      target: json['target'] as String? ?? '',
      canOverride: json['can_override'] == true,
      journalWorkVolumeId: (json['journal_work_volume_id'] as num?)?.toInt(),
    );
  }
}

class ConstructionJournalModel {
  const ConstructionJournalModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.journalNumber,
    required this.startDate,
    required this.status,
    this.endDate,
    this.project,
    this.contractNumber,
    this.createdByName,
    this.totalEntries = 0,
    this.approvedEntries = 0,
    this.submittedEntries = 0,
    this.rejectedEntries = 0,
    this.availableActions = const [],
  });

  final int id;
  final int projectId;
  final String name;
  final String journalNumber;
  final String startDate;
  final String? endDate;
  final String status;
  final ConstructionJournalProjectRef? project;
  final String? contractNumber;
  final String? createdByName;
  final int totalEntries;
  final int approvedEntries;
  final int submittedEntries;
  final int rejectedEntries;
  final List<String> availableActions;

  factory ConstructionJournalModel.fromJson(Map<String, dynamic> json) {
    final projectPayload = json['project'];
    final contractPayload = json['contract'];
    final createdByPayload = json['createdBy'];

    return ConstructionJournalModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      projectId: (json['project_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      journalNumber: json['journal_number'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String?,
      status: json['status'] as String? ?? '',
      project:
          projectPayload is Map<String, dynamic>
              ? ConstructionJournalProjectRef.fromJson(projectPayload)
              : projectPayload is Map
              ? ConstructionJournalProjectRef.fromJson(
                projectPayload.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              : null,
      contractNumber:
          contractPayload is Map ? contractPayload['number'] as String? : null,
      createdByName:
          createdByPayload is Map ? createdByPayload['name'] as String? : null,
      totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
      approvedEntries: (json['approved_entries'] as num?)?.toInt() ?? 0,
      submittedEntries: (json['submitted_entries'] as num?)?.toInt() ?? 0,
      rejectedEntries: (json['rejected_entries'] as num?)?.toInt() ?? 0,
      availableActions: _parseActions(json['available_actions']),
    );
  }
}

class ConstructionJournalEntryModel {
  const ConstructionJournalEntryModel({
    required this.id,
    required this.journalId,
    required this.entryDate,
    required this.entryNumber,
    required this.workDescription,
    required this.status,
    this.rejectionReason,
    this.createdByName,
    this.approvedByName,
    this.scheduleTask,
    this.estimateId,
    this.problemsDescription,
    this.safetyNotes,
    this.visitorsNotes,
    this.qualityNotes,
    this.workflowState,
    this.workVolumes = const [],
    this.blockers = const [],
    this.availableActions = const [],
  });

  final int id;
  final int journalId;
  final String entryDate;
  final int entryNumber;
  final String workDescription;
  final String status;
  final String? rejectionReason;
  final String? createdByName;
  final String? approvedByName;
  final ConstructionJournalScheduleTaskRef? scheduleTask;
  final int? estimateId;
  final String? problemsDescription;
  final String? safetyNotes;
  final String? visitorsNotes;
  final String? qualityNotes;
  final String? workflowState;
  final List<ConstructionJournalWorkVolumeModel> workVolumes;
  final List<ConstructionJournalBlockerModel> blockers;
  final List<String> availableActions;

  factory ConstructionJournalEntryModel.fromJson(Map<String, dynamic> json) {
    final createdByPayload = json['createdBy'];
    final approvedByPayload = json['approvedBy'];
    final scheduleTaskPayload = _asMap(json['scheduleTask']);

    return ConstructionJournalEntryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      journalId: (json['journal_id'] as num?)?.toInt() ?? 0,
      entryDate: json['entry_date'] as String? ?? '',
      entryNumber: (json['entry_number'] as num?)?.toInt() ?? 0,
      workDescription: json['work_description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      rejectionReason: json['rejection_reason'] as String?,
      createdByName:
          createdByPayload is Map ? createdByPayload['name'] as String? : null,
      approvedByName:
          approvedByPayload is Map
              ? approvedByPayload['name'] as String?
              : null,
      scheduleTask:
          scheduleTaskPayload.isEmpty
              ? null
              : ConstructionJournalScheduleTaskRef.fromJson(
                scheduleTaskPayload,
              ),
      estimateId: (json['estimate_id'] as num?)?.toInt(),
      problemsDescription: json['problems_description'] as String?,
      safetyNotes: json['safety_notes'] as String?,
      visitorsNotes: json['visitors_notes'] as String?,
      qualityNotes: json['quality_notes'] as String?,
      workflowState: json['workflow_state'] as String?,
      workVolumes:
          ((json['workVolumes'] as List<dynamic>?) ??
                  (json['work_volumes'] as List<dynamic>?) ??
                  const [])
              .whereType<Map>()
              .map(
                (volume) => ConstructionJournalWorkVolumeModel.fromJson(
                  volume.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
      blockers:
          (json['blockers'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (blocker) => ConstructionJournalBlockerModel.fromJson(
                  blocker.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(),
      availableActions: _parseActions(json['available_actions']),
    );
  }
}

class ConstructionJournalListPayload {
  const ConstructionJournalListPayload({
    required this.items,
    required this.meta,
    required this.summary,
    required this.availableActions,
    this.project,
  });

  final List<ConstructionJournalModel> items;
  final JournalPaginationMeta meta;
  final ConstructionJournalSummary summary;
  final List<String> availableActions;
  final ConstructionJournalProjectRef? project;
}

class ConstructionJournalDetailPayload {
  const ConstructionJournalDetailPayload({
    required this.journal,
    required this.entries,
    required this.entriesMeta,
    required this.entriesSummary,
    required this.availableActions,
  });

  final ConstructionJournalModel journal;
  final List<ConstructionJournalEntryModel> entries;
  final JournalPaginationMeta entriesMeta;
  final ConstructionJournalSummary entriesSummary;
  final List<String> availableActions;
}

List<String> _parseActions(dynamic payload) {
  if (payload is! List) {
    return const [];
  }

  return payload.whereType<String>().toList();
}

Map<String, dynamic> _asMap(dynamic payload) {
  if (payload is Map<String, dynamic>) {
    return payload;
  }

  if (payload is Map) {
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }

  return const {};
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString().replaceAll(',', '.'));
}
