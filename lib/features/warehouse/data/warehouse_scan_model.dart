class WarehouseScanPayload {
  const WarehouseScanPayload({
    required this.code,
    this.warehouseId,
    this.scanContext,
  });

  final String code;
  final int? warehouseId;
  final String? scanContext;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code.trim(),
      'source': 'mobile',
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if ((scanContext ?? '').trim().isNotEmpty)
        'scan_context': scanContext!.trim(),
    };
  }
}

class WarehouseTaskStatusPayload {
  const WarehouseTaskStatusPayload({
    required this.status,
    this.completedQuantity,
    this.notes,
  });

  final String status;
  final double? completedQuantity;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      if (completedQuantity != null) 'completed_quantity': completedQuantity,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

class WarehouseTransferPayload {
  const WarehouseTransferPayload({
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.materialId,
    required this.quantity,
    this.documentNumber,
    this.reason,
  });

  final int fromWarehouseId;
  final int toWarehouseId;
  final int materialId;
  final double quantity;
  final String? documentNumber;
  final String? reason;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'material_id': materialId,
      'quantity': quantity,
      if ((documentNumber ?? '').trim().isNotEmpty)
        'document_number': documentNumber!.trim(),
      if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
    };
  }
}

class WarehouseTransferResultModel {
  const WarehouseTransferResultModel({
    required this.movementOutId,
    required this.movementInId,
    required this.averagePrice,
  });

  final int movementOutId;
  final int movementInId;
  final double averagePrice;

  factory WarehouseTransferResultModel.fromJson(Map<String, dynamic> json) {
    final movementOut = _asMap(json['movement_out']);
    final movementIn = _asMap(json['movement_in']);

    return WarehouseTransferResultModel(
      movementOutId: _requiredInt(movementOut, 'id'),
      movementInId: _requiredInt(movementIn, 'id'),
      averagePrice: _requiredDouble(json, 'avg_price'),
    );
  }
}

class WarehouseScanResultModel {
  const WarehouseScanResultModel({
    required this.resolved,
    required this.relatedTasks,
    required this.availableActions,
    this.resolvedBy,
    this.warehouse,
    this.scanEvent,
    this.identifier,
    this.entityType,
    this.entityId,
    this.entitySummary,
    this.entity,
    this.recommendedAction,
  });

  final bool resolved;
  final String? resolvedBy;
  final WarehouseEntityRefModel? warehouse;
  final WarehouseScanEventModel? scanEvent;
  final WarehouseIdentifierModel? identifier;
  final String? entityType;
  final int? entityId;
  final WarehouseEntityRefModel? entitySummary;
  final WarehouseScannedEntityModel? entity;
  final List<WarehouseTaskModel> relatedTasks;
  final List<String> availableActions;
  final String? recommendedAction;

  factory WarehouseScanResultModel.fromJson(Map<String, dynamic> json) {
    return WarehouseScanResultModel(
      resolved: _requiredBool(json, 'resolved'),
      resolvedBy: _asNullableString(json['resolved_by']),
      warehouse:
          _asMap(json['warehouse']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['warehouse'])),
      scanEvent:
          _asMap(json['scan_event']).isEmpty
              ? null
              : WarehouseScanEventModel.fromJson(_asMap(json['scan_event'])),
      identifier:
          _asMap(json['identifier']).isEmpty
              ? null
              : WarehouseIdentifierModel.fromJson(_asMap(json['identifier'])),
      entityType: _asNullableString(json['entity_type']),
      entityId:
          json['entity_id'] == null ? null : _requiredInt(json, 'entity_id'),
      entitySummary:
          _asMap(json['entity_summary']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(
                _asMap(json['entity_summary']),
              ),
      entity:
          _asMap(json['entity']).isEmpty
              ? null
              : WarehouseScannedEntityModel.fromJson(
                _asMap(json['entity']),
                _requiredKnownString(json, 'entity_type', _entityTypes),
              ),
      relatedTasks:
          _requiredList(
            json,
            'related_tasks',
          ).map(WarehouseTaskModel.fromJson).toList(),
      availableActions: _requiredScalarList(json, 'available_actions')
          .map((value) => _requiredKnownValue(value, _warehouseActions))
          .toList(growable: false),
      recommendedAction: _asNullableString(json['recommended_action']),
    );
  }
}

class WarehouseScanEventModel {
  const WarehouseScanEventModel({
    required this.id,
    required this.code,
    required this.source,
    required this.result,
    this.scannedAt,
  });

  final int id;
  final String code;
  final String source;
  final String result;
  final DateTime? scannedAt;

  factory WarehouseScanEventModel.fromJson(Map<String, dynamic> json) {
    return WarehouseScanEventModel(
      id: _requiredInt(json, 'id'),
      code: _requiredString(json, 'code'),
      source: _requiredString(json, 'source'),
      result: _requiredString(json, 'result'),
      scannedAt:
          json['scanned_at'] != null
              ? DateTime.tryParse(json['scanned_at'].toString())
              : null,
    );
  }
}

class WarehouseIdentifierModel {
  const WarehouseIdentifierModel({
    required this.id,
    required this.code,
    required this.identifierType,
    required this.entityType,
    required this.entityId,
    required this.isPrimary,
    this.label,
    this.status,
  });

  final int id;
  final String code;
  final String identifierType;
  final String entityType;
  final int entityId;
  final bool isPrimary;
  final String? label;
  final String? status;

  factory WarehouseIdentifierModel.fromJson(Map<String, dynamic> json) {
    return WarehouseIdentifierModel(
      id: _requiredInt(json, 'id'),
      code: _requiredString(json, 'code'),
      identifierType: _requiredString(json, 'identifier_type'),
      entityType: _requiredKnownString(json, 'entity_type', _entityTypes),
      entityId: _requiredInt(json, 'entity_id'),
      isPrimary: _requiredBool(json, 'is_primary'),
      label: _asNullableString(json['label']),
      status: _asNullableString(json['status']),
    );
  }
}

class WarehouseEntityRefModel {
  const WarehouseEntityRefModel({
    required this.id,
    required this.name,
    this.code,
    this.subtitle,
  });

  final int id;
  final String name;
  final String? code;
  final String? subtitle;

  factory WarehouseEntityRefModel.fromJson(Map<String, dynamic> json) {
    final name = _firstNonEmpty(<dynamic>[
      json['name'],
      json['title'],
      json['act_number'],
      json['document_number'],
      json['email'],
      json['code'],
    ]);
    final code = _firstNonEmpty(<dynamic>[
      json['code'],
      json['status'],
      json['unit_type'],
      json['email'],
    ]);
    final subtitle = _firstNonEmpty(<dynamic>[
      json['warehouse_type'],
      json['full_address'],
      json['status'],
    ]);

    return WarehouseEntityRefModel(
      id: _requiredInt(json, 'id'),
      name:
          name ??
          (throw const FormatException(
            'Warehouse entity reference must include a readable name.',
          )),
      code: code,
      subtitle: subtitle,
    );
  }
}

class WarehouseScannedEntityModel {
  const WarehouseScannedEntityModel({required this.type, required this.raw});

  final String type;
  final Map<String, dynamic> raw;

  int get id => _requiredInt(raw, 'id');
  String get name => _requiredString(raw, 'name');
  String? get code => _asNullableString(raw['code']);
  String? get status => _asNullableString(raw['status']);
  String? get fullAddress =>
      _asNullableString(raw['full_address']) ??
      _asNullableString(raw['storage_address']);
  String? get assetTypeLabel => _asNullableString(raw['asset_type_label']);
  String? get assetType => _asNullableString(raw['asset_type']);
  String? get category => _asNullableString(raw['category']);
  String? get description => _asNullableString(raw['description']);
  String? get unitType => _asNullableString(raw['unit_type']);
  String? get cellType => _asNullableString(raw['cell_type']);
  double? get defaultPrice => _asNullableDouble(raw['default_price']);
  double? get capacity => _asNullableDouble(raw['capacity']);
  double? get currentLoad => _asNullableDouble(raw['current_load']);
  double? get currentUtilization =>
      _asNullableDouble(raw['current_utilization']);
  double? get storedQuantity => _asNullableDouble(raw['stored_quantity']);
  double? get totalQuantity => _asNullableDouble(raw['total_quantity']);
  double? get availableQuantity {
    final balance = _asMap(raw['warehouse_balance']);
    return balance.isEmpty
        ? _asNullableDouble(raw['total_available_quantity'])
        : _asNullableDouble(balance['available_quantity']);
  }

  double? get reservedQuantity {
    final balance = _asMap(raw['warehouse_balance']);
    return balance.isEmpty
        ? _asNullableDouble(raw['total_reserved_quantity'])
        : _asNullableDouble(balance['reserved_quantity']);
  }

  String? get locationCode {
    final balance = _asMap(raw['warehouse_balance']);
    return _asNullableString(balance['location_code']);
  }

  String get measurementLabel {
    final unit = _asMap(raw['measurement_unit']);
    return _asNullableString(unit['short_name']) ??
        _asNullableString(unit['name']) ??
        '';
  }

  WarehouseEntityRefModel? get zone {
    final zoneJson = _asMap(raw['zone']);
    return zoneJson.isEmpty ? null : WarehouseEntityRefModel.fromJson(zoneJson);
  }

  WarehouseEntityRefModel? get cell {
    final cellJson = _asMap(raw['cell']);
    return cellJson.isEmpty ? null : WarehouseEntityRefModel.fromJson(cellJson);
  }

  WarehouseEntityRefModel? get warehouse {
    final warehouseJson = _asMap(raw['warehouse']);
    return warehouseJson.isEmpty
        ? null
        : WarehouseEntityRefModel.fromJson(warehouseJson);
  }

  factory WarehouseScannedEntityModel.fromJson(
    Map<String, dynamic> json,
    String type,
  ) {
    return WarehouseScannedEntityModel(type: type, raw: json);
  }
}

class WarehouseTaskModel {
  const WarehouseTaskModel({
    required this.id,
    required this.warehouseId,
    required this.taskNumber,
    required this.title,
    required this.taskType,
    required this.taskTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.priority,
    required this.priorityLabel,
    required this.metadata,
    required this.availableTransitions,
    this.zoneId,
    this.cellId,
    this.logisticUnitId,
    this.materialId,
    this.projectId,
    this.inventoryActId,
    this.movementId,
    this.assignedToId,
    this.plannedQuantity,
    this.completedQuantity,
    this.progressPercent,
    this.notes,
    this.dueAt,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.warehouse,
    this.zone,
    this.cell,
    this.logisticUnit,
    this.material,
    this.project,
    this.inventoryAct,
    this.movement,
    this.assignedTo,
    this.creator,
    this.completedBy,
  });

  final int id;
  final int warehouseId;
  final int? zoneId;
  final int? cellId;
  final int? logisticUnitId;
  final int? materialId;
  final int? projectId;
  final int? inventoryActId;
  final int? movementId;
  final int? assignedToId;
  final String taskNumber;
  final String title;
  final String taskType;
  final String taskTypeLabel;
  final String status;
  final String statusLabel;
  final String priority;
  final String priorityLabel;
  final Map<String, dynamic> metadata;
  final List<WarehouseTaskTransitionModel> availableTransitions;
  final double? plannedQuantity;
  final double? completedQuantity;
  final double? progressPercent;
  final String? notes;
  final DateTime? dueAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final WarehouseEntityRefModel? warehouse;
  final WarehouseEntityRefModel? zone;
  final WarehouseEntityRefModel? cell;
  final WarehouseEntityRefModel? logisticUnit;
  final WarehouseEntityRefModel? material;
  final WarehouseEntityRefModel? project;
  final WarehouseEntityRefModel? inventoryAct;
  final WarehouseEntityRefModel? movement;
  final WarehouseEntityRefModel? assignedTo;
  final WarehouseEntityRefModel? creator;
  final WarehouseEntityRefModel? completedBy;

  factory WarehouseTaskModel.fromJson(Map<String, dynamic> json) {
    return WarehouseTaskModel(
      id: _requiredInt(json, 'id'),
      warehouseId: _requiredInt(json, 'warehouse_id'),
      zoneId: json['zone_id'] == null ? null : _requiredInt(json, 'zone_id'),
      cellId: json['cell_id'] == null ? null : _requiredInt(json, 'cell_id'),
      logisticUnitId:
          json['logistic_unit_id'] == null
              ? null
              : _requiredInt(json, 'logistic_unit_id'),
      materialId:
          json['material_id'] == null
              ? null
              : _requiredInt(json, 'material_id'),
      projectId:
          json['project_id'] == null ? null : _requiredInt(json, 'project_id'),
      inventoryActId:
          json['inventory_act_id'] == null
              ? null
              : _requiredInt(json, 'inventory_act_id'),
      movementId:
          json['movement_id'] == null
              ? null
              : _requiredInt(json, 'movement_id'),
      assignedToId:
          json['assigned_to_id'] == null
              ? null
              : _requiredInt(json, 'assigned_to_id'),
      taskNumber: _requiredString(json, 'task_number'),
      title: _requiredString(json, 'title'),
      taskType: _requiredKnownString(json, 'task_type', _taskTypes),
      taskTypeLabel: _requiredCleanLabel(json, 'task_type_label'),
      status: _requiredKnownString(json, 'status', _taskStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      priority: _requiredKnownString(json, 'priority', _taskPriorities),
      priorityLabel: _requiredCleanLabel(json, 'priority_label'),
      metadata: _asMap(json['metadata']),
      availableTransitions: _requiredList(
        json,
        'available_transitions',
      ).map(WarehouseTaskTransitionModel.fromJson).toList(growable: false),
      plannedQuantity: _asNullableDouble(json['planned_quantity']),
      completedQuantity: _asNullableDouble(json['completed_quantity']),
      progressPercent: _asNullableDouble(json['progress_percent']),
      notes: _asNullableString(json['notes']),
      dueAt: _parseDateTime(json['due_at']),
      startedAt: _parseDateTime(json['started_at']),
      completedAt: _parseDateTime(json['completed_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      warehouse:
          _asMap(json['warehouse']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['warehouse'])),
      zone:
          _asMap(json['zone']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['zone'])),
      cell:
          _asMap(json['cell']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['cell'])),
      logisticUnit:
          _asMap(json['logistic_unit']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['logistic_unit'])),
      material:
          _asMap(json['material']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['material'])),
      project:
          _asMap(json['project']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['project'])),
      inventoryAct:
          _asMap(json['inventory_act']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['inventory_act'])),
      movement:
          _asMap(json['movement']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['movement'])),
      assignedTo:
          _asMap(json['assigned_to']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['assigned_to'])),
      creator:
          _asMap(json['creator']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['creator'])),
      completedBy:
          _asMap(json['completed_by']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['completed_by'])),
    );
  }
}

class WarehouseTaskTransitionModel {
  const WarehouseTaskTransitionModel({
    required this.status,
    required this.name,
  });

  final String status;
  final String name;

  factory WarehouseTaskTransitionModel.fromJson(Map<String, dynamic> json) {
    return WarehouseTaskTransitionModel(
      status: _requiredKnownString(json, 'status', _taskStatuses),
      name: _requiredCleanLabel(json, 'name'),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _requiredList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Warehouse scan field "$key" must be a list.');
  }

  return value.whereType<Map>().map(_asMap).toList(growable: false);
}

List<dynamic> _requiredScalarList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Warehouse scan field "$key" must be a list.');
  }

  return value;
}

int? _asNullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _asNullableInt(json[key]);
  if (value == null) {
    throw FormatException('Warehouse scan field "$key" is required.');
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

  return double.tryParse(value.toString());
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = _asNullableDouble(json[key]);
  if (value == null) {
    throw FormatException('Warehouse scan field "$key" is required.');
  }

  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Warehouse scan field "$key" is required.');
  }

  return value;
}

String _requiredKnownString(
  Map<String, dynamic> json,
  String key,
  Set<String> allowedValues,
) {
  final value = _requiredString(json, key);
  return _requiredKnownValue(value, allowedValues);
}

String _requiredKnownValue(dynamic value, Set<String> allowedValues) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    throw const FormatException('Warehouse scan list value is required.');
  }
  if (!allowedValues.contains(normalized)) {
    throw const FormatException('Warehouse scan field has unknown value.');
  }

  return normalized;
}

String? _asNullableString(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
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

  final normalized = value?.toString().toLowerCase().trim();
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
    throw FormatException('Warehouse scan field "$key" is required.');
  }

  return value;
}

String? _cleanLabel(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  if (text.startsWith('basic_warehouse.') || text.startsWith('mobile_')) {
    return null;
  }

  return text;
}

String _requiredCleanLabel(Map<String, dynamic> json, String key) {
  final label = _cleanLabel(json[key]);
  if (label == null) {
    throw FormatException('Warehouse scan field "$key" must be readable.');
  }

  return label;
}

const _entityTypes = {
  'asset',
  'cell',
  'logistic_unit',
  'warehouse',
  'zone',
  'inventory_act',
  'movement',
};

const _warehouseActions = {
  'receipt',
  'transfer',
  'placement',
  'cycle_count',
  'inspection',
};

const _taskTypes = {
  'receipt',
  'placement',
  'transfer',
  'picking',
  'cycle_count',
  'issue',
  'return',
  'relabel',
  'inspection',
};

const _taskStatuses = {
  'draft',
  'queued',
  'in_progress',
  'blocked',
  'completed',
  'cancelled',
};

const _taskPriorities = {'critical', 'high', 'normal', 'low'};
