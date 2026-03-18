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
      movementOutId: _asInt(movementOut['id']),
      movementInId: _asInt(movementIn['id']),
      averagePrice: _asDouble(json['avg_price']),
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
      resolved: _asBool(json['resolved']),
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
      entityId: json['entity_id'] == null ? null : _asInt(json['entity_id']),
      entitySummary:
          _asMap(json['entity_summary']).isEmpty
              ? null
              : WarehouseEntityRefModel.fromJson(_asMap(json['entity_summary'])),
      entity:
          _asMap(json['entity']).isEmpty
              ? null
              : WarehouseScannedEntityModel.fromJson(
                _asMap(json['entity']),
                _asNullableString(json['entity_type']) ?? '',
              ),
      relatedTasks:
          _asList(
            json['related_tasks'],
          ).map(WarehouseTaskModel.fromJson).toList(),
      availableActions:
          (json['available_actions'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList(),
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
      id: _asInt(json['id']),
      code: _asString(json['code']),
      source: _asString(json['source']),
      result: _asString(json['result']),
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
      id: _asInt(json['id']),
      code: _asString(json['code']),
      identifierType: _asString(json['identifier_type']),
      entityType: _asString(json['entity_type']),
      entityId: _asInt(json['entity_id']),
      isPrimary: _asBool(json['is_primary']),
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
      id: _asInt(json['id']),
      name: name ?? 'Объект склада',
      code: code,
      subtitle: subtitle,
    );
  }
}

class WarehouseScannedEntityModel {
  const WarehouseScannedEntityModel({
    required this.type,
    required this.raw,
  });

  final String type;
  final Map<String, dynamic> raw;

  int get id => _asInt(raw['id']);
  String get name => _asString(raw['name']);
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
    required this.status,
    required this.priority,
    required this.metadata,
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
  final String status;
  final String priority;
  final Map<String, dynamic> metadata;
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
      id: _asInt(json['id']),
      warehouseId: _asInt(json['warehouse_id']),
      zoneId: json['zone_id'] == null ? null : _asInt(json['zone_id']),
      cellId: json['cell_id'] == null ? null : _asInt(json['cell_id']),
      logisticUnitId:
          json['logistic_unit_id'] == null
              ? null
              : _asInt(json['logistic_unit_id']),
      materialId:
          json['material_id'] == null ? null : _asInt(json['material_id']),
      projectId: json['project_id'] == null ? null : _asInt(json['project_id']),
      inventoryActId:
          json['inventory_act_id'] == null
              ? null
              : _asInt(json['inventory_act_id']),
      movementId:
          json['movement_id'] == null ? null : _asInt(json['movement_id']),
      assignedToId:
          json['assigned_to_id'] == null
              ? null
              : _asInt(json['assigned_to_id']),
      taskNumber: _asString(json['task_number']),
      title: _asString(json['title']),
      taskType: _asString(json['task_type']),
      status: _asString(json['status']),
      priority: _asString(json['priority']),
      metadata: _asMap(json['metadata']),
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

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value.whereType<Map>().map(_asMap).toList();
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}

String _asString(dynamic value) {
  return value?.toString() ?? '';
}

String? _asNullableString(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized = value?.toString().toLowerCase().trim();
  return normalized == 'true' || normalized == '1';
}
