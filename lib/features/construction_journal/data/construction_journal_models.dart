abstract final class ConstructionJournalActionKeys {
  static const view = 'view';
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
  static const export = 'export';
  static const createEntry = 'create_entry';
  static const submit = 'submit';
  static const approve = 'approve';
  static const reject = 'reject';
  static const exportDailyReport = 'export_daily_report';
}

class ConstructionJournalActionModel {
  const ConstructionJournalActionModel({
    required this.action,
    required this.label,
  });

  final String action;
  final String label;

  factory ConstructionJournalActionModel.fromJson(Map<String, dynamic> json) {
    return ConstructionJournalActionModel(
      action: _requiredKnownString(json, 'action', _journalActions),
      label: _requiredCleanLabel(json, 'label'),
    );
  }
}

extension ConstructionJournalActionListX
    on Iterable<ConstructionJournalActionModel> {
  bool hasAction(String action) {
    return any((item) => item.action == action);
  }
}

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
      currentPage: _requiredInt(json, 'current_page'),
      perPage: _requiredInt(json, 'per_page'),
      lastPage: _requiredInt(json, 'last_page'),
      total: _requiredInt(json, 'total'),
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

  factory ConstructionJournalSummary.fromJournalListJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalSummary(
      totalJournals: _requiredInt(json, 'total_journals'),
      activeJournals: _requiredInt(json, 'active_journals'),
      archivedJournals: _requiredInt(json, 'archived_journals'),
      closedJournals: _requiredInt(json, 'closed_journals'),
    );
  }

  factory ConstructionJournalSummary.fromEntriesJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalSummary(
      totalEntries: _requiredInt(json, 'total_entries'),
      approvedEntries: _requiredInt(json, 'approved_entries'),
      submittedEntries: _requiredInt(json, 'submitted_entries'),
      rejectedEntries: _requiredInt(json, 'rejected_entries'),
    );
  }
}

class ConstructionJournalProjectRef {
  const ConstructionJournalProjectRef({required this.id, required this.name});

  final int id;
  final String name;

  factory ConstructionJournalProjectRef.fromJson(Map<String, dynamic> json) {
    return ConstructionJournalProjectRef(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
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
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      quantity: _asNullableDouble(json['quantity']),
      measurementUnit: _asNullableString(json['measurement_unit']),
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

  String get displayName {
    final short = shortName?.trim();
    return short == null || short.isEmpty ? name : short;
  }

  factory ConstructionJournalMeasurementUnitRef.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalMeasurementUnitRef(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      shortName: _asNullableString(json['short_name']),
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
    final measurementUnitPayload = _optionalMap(
      json['measurementUnit'],
      'measurementUnit',
    );

    return ConstructionJournalWorkTypeOption(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      measurementUnitId: _asNullableInt(json['measurement_unit_id']),
      measurementUnit:
          measurementUnitPayload == null
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
    required this.itemType,
    required this.quantity,
    required this.quantityTotal,
    required this.contractLinks,
    this.positionNumber,
    this.workTypeId,
    this.measurementUnitId,
    this.workType,
    this.measurementUnit,
  });

  final int id;
  final int estimateId;
  final String name;
  final String itemType;
  final String? positionNumber;
  final double quantity;
  final double quantityTotal;
  final int? workTypeId;
  final int? measurementUnitId;
  final ConstructionJournalWorkTypeOption? workType;
  final ConstructionJournalMeasurementUnitRef? measurementUnit;
  final List<Map<String, dynamic>> contractLinks;

  String get displayName {
    final position = positionNumber?.trim();
    return position == null || position.isEmpty ? name : '$position - $name';
  }

  factory ConstructionJournalEstimateItemOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final workTypePayload = _optionalMap(json['workType'], 'workType');
    final measurementUnitPayload = _optionalMap(
      json['measurementUnit'],
      'measurementUnit',
    );

    return ConstructionJournalEstimateItemOption(
      id: _requiredInt(json, 'id'),
      estimateId: _requiredInt(json, 'estimate_id'),
      name: _requiredString(json, 'name'),
      itemType: _requiredKnownString(json, 'item_type', _estimateItemTypes),
      positionNumber: _asNullableString(json['position_number']),
      quantity: _requiredDouble(json, 'quantity'),
      quantityTotal: _requiredDouble(json, 'quantity_total'),
      workTypeId: _asNullableInt(json['work_type_id']),
      measurementUnitId: _asNullableInt(json['measurement_unit_id']),
      workType:
          workTypePayload == null
              ? null
              : ConstructionJournalWorkTypeOption.fromJson(workTypePayload),
      measurementUnit:
          measurementUnitPayload == null
              ? null
              : ConstructionJournalMeasurementUnitRef.fromJson(
                measurementUnitPayload,
              ),
      contractLinks: _requiredRawMapList(json, 'contract_links'),
    );
  }
}

class ConstructionJournalEstimateOption {
  const ConstructionJournalEstimateOption({
    required this.id,
    required this.name,
    required this.items,
    this.number,
  });

  final int id;
  final String name;
  final String? number;
  final List<ConstructionJournalEstimateItemOption> items;

  String get displayName {
    final estimateNumber = number?.trim();
    return estimateNumber == null || estimateNumber.isEmpty
        ? name
        : '$estimateNumber - $name';
  }

  factory ConstructionJournalEstimateOption.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalEstimateOption(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      number: _asNullableString(json['number']),
      items:
          _requiredList(
            json,
            'items',
          ).map(ConstructionJournalEstimateItemOption.fromJson).toList(),
    );
  }
}

class ConstructionJournalEntryFormOptions {
  const ConstructionJournalEntryFormOptions({
    required this.estimates,
    required this.workTypes,
    required this.projectMaterials,
  });

  final List<ConstructionJournalEstimateOption> estimates;
  final List<ConstructionJournalWorkTypeOption> workTypes;
  final List<ConstructionJournalProjectMaterialOption> projectMaterials;

  factory ConstructionJournalEntryFormOptions.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConstructionJournalEntryFormOptions(
      estimates:
          _requiredList(
            json,
            'estimates',
          ).map(ConstructionJournalEstimateOption.fromJson).toList(),
      workTypes:
          _requiredList(
            json,
            'work_types',
          ).map(ConstructionJournalWorkTypeOption.fromJson).toList(),
      projectMaterials:
          _requiredList(
            json,
            'project_materials',
          ).map(ConstructionJournalProjectMaterialOption.fromJson).toList(),
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
    final measurementUnit = _requiredMap(json, 'measurement_unit');
    final shortName = _asNullableString(measurementUnit['short_name']);
    final unitName = _requiredString(measurementUnit, 'name');

    return ConstructionJournalProjectMaterialOption(
      deliveryId: _requiredInt(json, 'delivery_id'),
      materialId: _requiredInt(json, 'material_id'),
      materialName: _requiredString(json, 'name'),
      availableQuantity: _requiredDouble(json, 'available_quantity'),
      measurementUnit: shortName ?? unitName,
      status: _asNullableString(json['status']),
      acceptedAt: _asNullableString(json['accepted_at']),
    );
  }
}

class ConstructionJournalMaterialUsageModel {
  const ConstructionJournalMaterialUsageModel({
    this.materialId,
    this.projectMaterialDeliveryId,
    required this.materialName,
    required this.quantity,
    required this.measurementUnit,
    this.notes,
  });

  final int? materialId;
  final int? projectMaterialDeliveryId;
  final String materialName;
  final double quantity;
  final String measurementUnit;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      if (materialId != null) 'material_id': materialId,
      if (projectMaterialDeliveryId != null)
        'project_material_delivery_id': projectMaterialDeliveryId,
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
    required this.quantity,
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
    return ConstructionJournalWorkVolumeModel(
      id: _asNullableInt(json['id']),
      estimateItemId: _asNullableInt(json['estimate_item_id']),
      workTypeId: _asNullableInt(json['work_type_id']),
      quantity: _requiredDouble(json, 'quantity'),
      measurementUnitId: _asNullableInt(json['measurement_unit_id']),
      notes: _asNullableString(json['notes']),
      title: _requiredString(json, 'title'),
      measurementUnitName: _requiredString(json, 'measurement_unit_name'),
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
      code: _requiredString(json, 'code'),
      message: _requiredCleanLabel(json, 'message'),
      target: _requiredString(json, 'target'),
      canOverride: _requiredBool(json, 'can_override'),
      journalWorkVolumeId: _asNullableInt(json['journal_work_volume_id']),
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
    required this.statusLabel,
    required this.totalEntries,
    required this.approvedEntries,
    required this.submittedEntries,
    required this.rejectedEntries,
    required this.availableActions,
    this.endDate,
    this.project,
    this.contractNumber,
    this.createdByName,
  });

  final int id;
  final int projectId;
  final String name;
  final String journalNumber;
  final String startDate;
  final String? endDate;
  final String status;
  final String statusLabel;
  final ConstructionJournalProjectRef? project;
  final String? contractNumber;
  final String? createdByName;
  final int totalEntries;
  final int approvedEntries;
  final int submittedEntries;
  final int rejectedEntries;
  final List<ConstructionJournalActionModel> availableActions;

  bool hasAction(String action) {
    return availableActions.hasAction(action);
  }

  factory ConstructionJournalModel.fromJson(Map<String, dynamic> json) {
    final projectPayload = _optionalMap(json['project'], 'project');
    final contractPayload = _optionalMap(json['contract'], 'contract');
    final createdByPayload = _optionalMap(json['createdBy'], 'createdBy');

    return ConstructionJournalModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      name: _requiredString(json, 'name'),
      journalNumber: _requiredText(json, 'journal_number', allowEmpty: true),
      startDate: _requiredString(json, 'start_date'),
      endDate: _asNullableString(json['end_date']),
      status: _requiredKnownString(json, 'status', _journalStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      project:
          projectPayload == null
              ? null
              : ConstructionJournalProjectRef.fromJson(projectPayload),
      contractNumber:
          contractPayload == null
              ? null
              : _asNullableString(contractPayload['number']),
      createdByName:
          createdByPayload == null
              ? null
              : _asNullableString(createdByPayload['name']),
      totalEntries: _requiredInt(json, 'total_entries'),
      approvedEntries: _requiredInt(json, 'approved_entries'),
      submittedEntries: _requiredInt(json, 'submitted_entries'),
      rejectedEntries: _requiredInt(json, 'rejected_entries'),
      availableActions:
          _requiredList(
            json,
            'available_actions',
          ).map(ConstructionJournalActionModel.fromJson).toList(),
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
    required this.statusLabel,
    required this.workflowState,
    required this.workVolumes,
    required this.blockers,
    required this.availableActions,
    this.rejectionReason,
    this.createdByName,
    this.approvedByName,
    this.scheduleTask,
    this.estimateId,
    this.problemsDescription,
    this.safetyNotes,
    this.visitorsNotes,
    this.qualityNotes,
  });

  final int id;
  final int journalId;
  final String entryDate;
  final int entryNumber;
  final String workDescription;
  final String status;
  final String statusLabel;
  final String workflowState;
  final String? rejectionReason;
  final String? createdByName;
  final String? approvedByName;
  final ConstructionJournalScheduleTaskRef? scheduleTask;
  final int? estimateId;
  final String? problemsDescription;
  final String? safetyNotes;
  final String? visitorsNotes;
  final String? qualityNotes;
  final List<ConstructionJournalWorkVolumeModel> workVolumes;
  final List<ConstructionJournalBlockerModel> blockers;
  final List<ConstructionJournalActionModel> availableActions;

  bool hasAction(String action) {
    return availableActions.hasAction(action);
  }

  factory ConstructionJournalEntryModel.fromJson(Map<String, dynamic> json) {
    final createdByPayload = _optionalMap(json['createdBy'], 'createdBy');
    final approvedByPayload = _optionalMap(json['approvedBy'], 'approvedBy');
    final scheduleTaskPayload = _optionalMap(
      json['scheduleTask'],
      'scheduleTask',
    );

    return ConstructionJournalEntryModel(
      id: _requiredInt(json, 'id'),
      journalId: _requiredInt(json, 'journal_id'),
      entryDate: _requiredString(json, 'entry_date'),
      entryNumber: _requiredInt(json, 'entry_number'),
      workDescription: _requiredString(json, 'work_description'),
      status: _requiredKnownString(json, 'status', _entryStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      rejectionReason: _asNullableString(json['rejection_reason']),
      createdByName:
          createdByPayload == null
              ? null
              : _asNullableString(createdByPayload['name']),
      approvedByName:
          approvedByPayload == null
              ? null
              : _asNullableString(approvedByPayload['name']),
      scheduleTask:
          scheduleTaskPayload == null
              ? null
              : ConstructionJournalScheduleTaskRef.fromJson(
                scheduleTaskPayload,
              ),
      estimateId: _asNullableInt(json['estimate_id']),
      problemsDescription: _asNullableString(json['problems_description']),
      safetyNotes: _asNullableString(json['safety_notes']),
      visitorsNotes: _asNullableString(json['visitors_notes']),
      qualityNotes: _asNullableString(json['quality_notes']),
      workflowState: _requiredKnownString(
        json,
        'workflow_state',
        _workflowStates,
      ),
      workVolumes:
          _requiredList(
            json,
            'workVolumes',
          ).map(ConstructionJournalWorkVolumeModel.fromJson).toList(),
      blockers:
          _requiredList(
            json,
            'blockers',
          ).map(ConstructionJournalBlockerModel.fromJson).toList(),
      availableActions:
          _requiredList(
            json,
            'available_actions',
          ).map(ConstructionJournalActionModel.fromJson).toList(),
    );
  }
}

class ConstructionJournalListPayload {
  const ConstructionJournalListPayload({
    required this.items,
    required this.meta,
    required this.summary,
    required this.availableActions,
    required this.project,
  });

  final List<ConstructionJournalModel> items;
  final JournalPaginationMeta meta;
  final ConstructionJournalSummary summary;
  final List<ConstructionJournalActionModel> availableActions;
  final ConstructionJournalProjectRef project;
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
  final List<ConstructionJournalActionModel> availableActions;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  throw FormatException('Construction journal field "$key" must be an object.');
}

Map<String, dynamic>? _optionalMap(dynamic value, String key) {
  if (value == null) {
    return null;
  }

  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  throw FormatException('Construction journal field "$key" must be an object.');
}

List<Map<String, dynamic>> _requiredList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Construction journal field "$key" must be a list.');
  }

  return value.map((item) {
    if (item is Map<String, dynamic>) {
      return item;
    }

    if (item is Map) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException(
      'Construction journal field "$key" must contain objects.',
    );
  }).toList();
}

List<Map<String, dynamic>> _requiredRawMapList(
  Map<String, dynamic> json,
  String key,
) {
  return _requiredList(json, key).map(Map<String, dynamic>.from).toList();
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _asNullableInt(json[key]);
  if (value == null) {
    throw FormatException('Construction journal field "$key" is required.');
  }

  return value;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString().replaceAll(',', '.'));
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = _asNullableDouble(json[key]);
  if (value == null) {
    throw FormatException('Construction journal field "$key" is required.');
  }

  return value;
}

bool? _asNullableBool(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized = value.toString().toLowerCase().trim();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }

  return null;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = _asNullableBool(json[key]);
  if (value == null) {
    throw FormatException('Construction journal field "$key" is required.');
  }

  return value;
}

String? _asNullableString(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _requiredText(
  Map<String, dynamic> json,
  String key, {
  bool allowEmpty = false,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    throw FormatException('Construction journal field "$key" is required.');
  }

  final value = json[key].toString().trim();
  if (!allowEmpty && value.isEmpty) {
    throw FormatException('Construction journal field "$key" is required.');
  }

  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  return _requiredText(json, key);
}

String _requiredKnownString(
  Map<String, dynamic> json,
  String key,
  Set<String> allowedValues,
) {
  final value = _requiredString(json, key);
  if (!allowedValues.contains(value)) {
    throw FormatException(
      'Construction journal field "$key" has unknown value.',
    );
  }

  return value;
}

String _requiredCleanLabel(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (value.startsWith('construction_journal.') ||
      value.startsWith('mobile_construction_journal.')) {
    throw FormatException(
      'Construction journal field "$key" must be readable.',
    );
  }

  return value;
}

const _journalStatuses = {'active', 'archived', 'closed'};

const _entryStatuses = {'draft', 'submitted', 'approved', 'rejected'};

const _workflowStates = {'ready', 'blocked'};

const _estimateItemTypes = {'work'};

const _journalActions = {
  ConstructionJournalActionKeys.view,
  ConstructionJournalActionKeys.create,
  ConstructionJournalActionKeys.update,
  ConstructionJournalActionKeys.delete,
  ConstructionJournalActionKeys.export,
  ConstructionJournalActionKeys.createEntry,
  ConstructionJournalActionKeys.submit,
  ConstructionJournalActionKeys.approve,
  ConstructionJournalActionKeys.reject,
  ConstructionJournalActionKeys.exportDailyReport,
};
