class ProjectMaterialDeliveryEventModel {
  const ProjectMaterialDeliveryEventModel({
    required this.id,
    required this.eventType,
    this.fromStatus,
    this.toStatus,
    this.quantity,
    this.notes,
    this.occurredAt,
    this.userName,
  });

  final int id;
  final String eventType;
  final String? fromStatus;
  final String? toStatus;
  final double? quantity;
  final String? notes;
  final DateTime? occurredAt;
  final String? userName;

  factory ProjectMaterialDeliveryEventModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final user = json['user'];

    return ProjectMaterialDeliveryEventModel(
      id: _requiredInt(json, 'id'),
      eventType: _requiredString(json, 'event_type'),
      fromStatus: json['from_status']?.toString(),
      toStatus: json['to_status']?.toString(),
      quantity: _asDouble(json['quantity']),
      notes: json['notes']?.toString(),
      occurredAt:
          json['occurred_at'] != null
              ? DateTime.tryParse(json['occurred_at'].toString())
              : null,
      userName: user is Map ? user['name']?.toString() : null,
    );
  }
}

class ProjectMaterialDeliveryModel {
  const ProjectMaterialDeliveryModel({
    required this.id,
    required this.status,
    required this.requestedQuantity,
    required this.reservedQuantity,
    required this.shippedQuantity,
    required this.acceptedQuantity,
    required this.usedQuantity,
    required this.availableQuantity,
    required this.remainingToShip,
    required this.remainingToAccept,
    required this.canReceive,
    this.statusLabel,
    this.statusColor,
    this.sourceType,
    this.projectId,
    this.projectName,
    this.materialId,
    this.materialName,
    this.materialUnit,
    this.warehouseId,
    this.warehouseName,
    this.plannedDeliveryDate,
    this.shippedAt,
    this.deliveredAt,
    this.acceptedAt,
    this.siteRequestId,
    this.purchaseRequestId,
    this.purchaseOrderId,
    this.events = const [],
  });

  final int id;
  final String status;
  final String? statusLabel;
  final String? statusColor;
  final String? sourceType;
  final int? projectId;
  final String? projectName;
  final int? materialId;
  final String? materialName;
  final String? materialUnit;
  final int? warehouseId;
  final String? warehouseName;
  final double requestedQuantity;
  final double reservedQuantity;
  final double shippedQuantity;
  final double acceptedQuantity;
  final double usedQuantity;
  final double availableQuantity;
  final double remainingToShip;
  final double remainingToAccept;
  final String? plannedDeliveryDate;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? acceptedAt;
  final int? siteRequestId;
  final int? purchaseRequestId;
  final int? purchaseOrderId;
  final bool canReceive;
  final List<ProjectMaterialDeliveryEventModel> events;

  factory ProjectMaterialDeliveryModel.fromJson(Map<String, dynamic> json) {
    final project = json['project'];
    final material = json['material'];
    final projectJson = _requiredMapValue(project, 'project');
    final materialJson = _requiredMapValue(material, 'material');
    final measurementUnit =
        material is Map ? material['measurement_unit'] : null;
    final warehouse = json['warehouse'];
    final linkedEntities = json['linked_entities'];
    final rawEvents = json['events'];

    return ProjectMaterialDeliveryModel(
      id: _requiredInt(json, 'id'),
      sourceType: json['source_type']?.toString(),
      status: _requiredKnownString(
        json,
        'status',
        _projectMaterialDeliveryStatuses,
      ),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      statusColor: json['status_color']?.toString(),
      projectId: _requiredInt(projectJson, 'id'),
      projectName: _requiredString(projectJson, 'name'),
      materialId: _requiredInt(materialJson, 'id'),
      materialName: _requiredString(materialJson, 'name'),
      materialUnit:
          measurementUnit is Map
              ? measurementUnit['short_name']?.toString()
              : null,
      warehouseId: warehouse is Map ? _asNullableInt(warehouse['id']) : null,
      warehouseName: warehouse is Map ? warehouse['name']?.toString() : null,
      requestedQuantity: _requiredDouble(json, 'requested_quantity'),
      reservedQuantity: _requiredDouble(json, 'reserved_quantity'),
      shippedQuantity: _requiredDouble(json, 'shipped_quantity'),
      acceptedQuantity: _requiredDouble(json, 'accepted_quantity'),
      usedQuantity: _requiredDouble(json, 'used_quantity'),
      availableQuantity: _requiredDouble(json, 'available_quantity'),
      remainingToShip: _requiredDouble(json, 'remaining_to_ship'),
      remainingToAccept: _requiredDouble(json, 'remaining_to_accept'),
      plannedDeliveryDate: json['planned_delivery_date']?.toString(),
      shippedAt: _parseDate(json['shipped_at']),
      deliveredAt: _parseDate(json['delivered_at']),
      acceptedAt: _parseDate(json['accepted_at']),
      siteRequestId:
          linkedEntities is Map
              ? _asNullableInt(linkedEntities['site_request_id'])
              : null,
      purchaseRequestId:
          linkedEntities is Map
              ? _asNullableInt(linkedEntities['purchase_request_id'])
              : null,
      purchaseOrderId:
          linkedEntities is Map
              ? _asNullableInt(linkedEntities['purchase_order_id'])
              : null,
      canReceive: _requiredBool(json, 'can_receive'),
      events:
          rawEvents is List
              ? rawEvents
                  .whereType<Map>()
                  .map(
                    (item) => ProjectMaterialDeliveryEventModel.fromJson(
                      item.map((key, value) => MapEntry(key.toString(), value)),
                    ),
                  )
                  .toList(growable: false)
              : const <ProjectMaterialDeliveryEventModel>[],
    );
  }
}

class ProjectMaterialStockDeliveryModel {
  const ProjectMaterialStockDeliveryModel({
    required this.id,
    required this.acceptedQuantity,
    required this.usedQuantity,
    required this.availableQuantity,
    this.sourceType,
    this.status,
    this.statusLabel,
    this.acceptedAt,
    this.warehouseName,
  });

  final int id;
  final String? sourceType;
  final String? status;
  final String? statusLabel;
  final double acceptedQuantity;
  final double usedQuantity;
  final double availableQuantity;
  final DateTime? acceptedAt;
  final String? warehouseName;

  factory ProjectMaterialStockDeliveryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final warehouse = json['warehouse'];

    return ProjectMaterialStockDeliveryModel(
      id: _requiredInt(json, 'id'),
      sourceType: json['source_type']?.toString(),
      status: _requiredKnownString(
        json,
        'status',
        _projectMaterialDeliveryStatuses,
      ),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      acceptedQuantity: _requiredDouble(json, 'accepted_quantity'),
      usedQuantity: _requiredDouble(json, 'used_quantity'),
      availableQuantity: _requiredDouble(json, 'available_quantity'),
      acceptedAt: _parseDate(json['accepted_at']),
      warehouseName: warehouse is Map ? warehouse['name']?.toString() : null,
    );
  }
}

class ProjectMaterialStockUsageModel {
  const ProjectMaterialStockUsageModel({
    required this.deliveryId,
    required this.quantity,
    this.journalEntryId,
    this.entryNumber,
    this.entryDate,
    this.workDescription,
    this.measurementUnit,
  });

  final int deliveryId;
  final int? journalEntryId;
  final int? entryNumber;
  final DateTime? entryDate;
  final String? workDescription;
  final double quantity;
  final String? measurementUnit;

  factory ProjectMaterialStockUsageModel.fromJson(Map<String, dynamic> json) {
    return ProjectMaterialStockUsageModel(
      deliveryId: _requiredInt(json, 'delivery_id'),
      journalEntryId: _asNullableInt(json['journal_entry_id']),
      entryNumber: _asNullableInt(json['entry_number']),
      entryDate: _parseDate(json['entry_date']),
      workDescription: json['work_description']?.toString(),
      quantity: _requiredDouble(json, 'quantity'),
      measurementUnit: json['measurement_unit']?.toString(),
    );
  }
}

class ProjectMaterialStockItemModel {
  const ProjectMaterialStockItemModel({
    required this.acceptedQuantity,
    required this.usedQuantity,
    required this.availableQuantity,
    required this.deliveries,
    required this.usages,
    this.projectId,
    this.projectName,
    this.materialId,
    this.materialName,
    this.materialUnit,
  });

  final int? projectId;
  final String? projectName;
  final int? materialId;
  final String? materialName;
  final String? materialUnit;
  final double acceptedQuantity;
  final double usedQuantity;
  final double availableQuantity;
  final List<ProjectMaterialStockDeliveryModel> deliveries;
  final List<ProjectMaterialStockUsageModel> usages;

  factory ProjectMaterialStockItemModel.fromJson(Map<String, dynamic> json) {
    final project = json['project'];
    final material = json['material'];
    final projectJson = _requiredMapValue(project, 'project');
    final materialJson = _requiredMapValue(material, 'material');
    final measurementUnit =
        material is Map ? material['measurement_unit'] : null;
    final rawDeliveries = json['deliveries'];
    final rawUsages = json['journal_usages'];

    return ProjectMaterialStockItemModel(
      projectId: _requiredInt(projectJson, 'id'),
      projectName: _requiredString(projectJson, 'name'),
      materialId: _requiredInt(materialJson, 'id'),
      materialName: _requiredString(materialJson, 'name'),
      materialUnit:
          measurementUnit is Map
              ? measurementUnit['short_name']?.toString() ??
                  measurementUnit['name']?.toString()
              : null,
      acceptedQuantity: _requiredDouble(json, 'accepted_quantity'),
      usedQuantity: _requiredDouble(json, 'used_quantity'),
      availableQuantity: _requiredDouble(json, 'available_quantity'),
      deliveries:
          rawDeliveries is List
              ? rawDeliveries
                  .whereType<Map>()
                  .map(
                    (item) => ProjectMaterialStockDeliveryModel.fromJson(
                      item.map((key, value) => MapEntry(key.toString(), value)),
                    ),
                  )
                  .toList(growable: false)
              : const <ProjectMaterialStockDeliveryModel>[],
      usages:
          rawUsages is List
              ? rawUsages
                  .whereType<Map>()
                  .map(
                    (item) => ProjectMaterialStockUsageModel.fromJson(
                      item.map((key, value) => MapEntry(key.toString(), value)),
                    ),
                  )
                  .toList(growable: false)
              : const <ProjectMaterialStockUsageModel>[],
    );
  }
}

class ProjectMaterialStockSummaryModel {
  const ProjectMaterialStockSummaryModel({
    required this.materialsCount,
    required this.deliveriesCount,
    required this.acceptedQuantity,
    required this.usedQuantity,
    required this.availableQuantity,
  });

  final int materialsCount;
  final int deliveriesCount;
  final double acceptedQuantity;
  final double usedQuantity;
  final double availableQuantity;

  factory ProjectMaterialStockSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProjectMaterialStockSummaryModel(
      materialsCount: _requiredInt(json, 'materials_count'),
      deliveriesCount: _requiredInt(json, 'deliveries_count'),
      acceptedQuantity: _requiredDouble(json, 'accepted_quantity'),
      usedQuantity: _requiredDouble(json, 'used_quantity'),
      availableQuantity: _requiredDouble(json, 'available_quantity'),
    );
  }
}

class ProjectMaterialStockModel {
  const ProjectMaterialStockModel({required this.items, required this.summary});

  final List<ProjectMaterialStockItemModel> items;
  final ProjectMaterialStockSummaryModel summary;

  factory ProjectMaterialStockModel.fromJson(Map<String, dynamic> json) {
    final rawItems = _requiredList(json, 'items');
    final rawSummary = _requiredMap(json, 'summary');

    return ProjectMaterialStockModel(
      items: rawItems
          .map(ProjectMaterialStockItemModel.fromJson)
          .toList(growable: false),
      summary: ProjectMaterialStockSummaryModel.fromJson(rawSummary),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  return value == null ? null : DateTime.tryParse(value.toString());
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
    throw FormatException(
      'Project material delivery field "$key" is required.',
    );
  }

  return value;
}

double? _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = _asDouble(json[key]);
  if (value == null) {
    throw FormatException(
      'Project material delivery field "$key" is required.',
    );
  }

  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException(
      'Project material delivery field "$key" is required.',
    );
  }

  return value;
}

String _requiredKnownString(
  Map<String, dynamic> json,
  String key,
  Set<String> allowedValues,
) {
  final value = _requiredString(json, key);
  if (!allowedValues.contains(value)) {
    throw FormatException(
      'Project material delivery field "$key" has unknown value.',
    );
  }

  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Project material delivery field "$key" is required.');
}

Map<String, dynamic> _requiredMapValue(dynamic value, String key) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  throw FormatException('Project material delivery field "$key" is required.');
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  return _requiredMapValue(json[key], key);
}

List<Map<String, dynamic>> _requiredList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException(
      'Project material delivery field "$key" must be a list.',
    );
  }

  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
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
    throw FormatException(
      'Project material delivery field "$key" must be readable.',
    );
  }

  return label;
}

const _projectMaterialDeliveryStatuses = {
  'requested',
  'processing',
  'reserved',
  'preparing',
  'in_transit',
  'partially_delivered',
  'delivered',
  'accepted',
  'problem',
  'cancelled',
};
