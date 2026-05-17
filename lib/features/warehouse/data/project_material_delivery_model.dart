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
      id: _asInt(json['id']),
      eventType: json['event_type']?.toString() ?? '',
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
    final measurementUnit =
        material is Map ? material['measurement_unit'] : null;
    final warehouse = json['warehouse'];
    final linkedEntities = json['linked_entities'];
    final rawEvents = json['events'];

    return ProjectMaterialDeliveryModel(
      id: _asInt(json['id']),
      sourceType: json['source_type']?.toString(),
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString(),
      statusColor: json['status_color']?.toString(),
      projectId: project is Map ? _asNullableInt(project['id']) : null,
      projectName: project is Map ? project['name']?.toString() : null,
      materialId: material is Map ? _asNullableInt(material['id']) : null,
      materialName: material is Map ? material['name']?.toString() : null,
      materialUnit:
          measurementUnit is Map
              ? measurementUnit['short_name']?.toString()
              : null,
      warehouseId: warehouse is Map ? _asNullableInt(warehouse['id']) : null,
      warehouseName: warehouse is Map ? warehouse['name']?.toString() : null,
      requestedQuantity: _asDouble(json['requested_quantity']) ?? 0,
      reservedQuantity: _asDouble(json['reserved_quantity']) ?? 0,
      shippedQuantity: _asDouble(json['shipped_quantity']) ?? 0,
      acceptedQuantity: _asDouble(json['accepted_quantity']) ?? 0,
      usedQuantity: _asDouble(json['used_quantity']) ?? 0,
      availableQuantity: _asDouble(json['available_quantity']) ?? 0,
      remainingToShip: _asDouble(json['remaining_to_ship']) ?? 0,
      remainingToAccept: _asDouble(json['remaining_to_accept']) ?? 0,
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
      canReceive: json['can_receive'] == true,
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
      id: _asInt(json['id']),
      sourceType: json['source_type']?.toString(),
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
      acceptedQuantity: _asDouble(json['accepted_quantity']) ?? 0,
      usedQuantity: _asDouble(json['used_quantity']) ?? 0,
      availableQuantity: _asDouble(json['available_quantity']) ?? 0,
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
      deliveryId: _asInt(json['delivery_id']),
      journalEntryId: _asNullableInt(json['journal_entry_id']),
      entryNumber: _asNullableInt(json['entry_number']),
      entryDate: _parseDate(json['entry_date']),
      workDescription: json['work_description']?.toString(),
      quantity: _asDouble(json['quantity']) ?? 0,
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
    final measurementUnit =
        material is Map ? material['measurement_unit'] : null;
    final rawDeliveries = json['deliveries'];
    final rawUsages = json['journal_usages'];

    return ProjectMaterialStockItemModel(
      projectId: project is Map ? _asNullableInt(project['id']) : null,
      projectName: project is Map ? project['name']?.toString() : null,
      materialId: material is Map ? _asNullableInt(material['id']) : null,
      materialName: material is Map ? material['name']?.toString() : null,
      materialUnit:
          measurementUnit is Map
              ? measurementUnit['short_name']?.toString() ??
                  measurementUnit['name']?.toString()
              : null,
      acceptedQuantity: _asDouble(json['accepted_quantity']) ?? 0,
      usedQuantity: _asDouble(json['used_quantity']) ?? 0,
      availableQuantity: _asDouble(json['available_quantity']) ?? 0,
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
      materialsCount: _asInt(json['materials_count']),
      deliveriesCount: _asInt(json['deliveries_count']),
      acceptedQuantity: _asDouble(json['accepted_quantity']) ?? 0,
      usedQuantity: _asDouble(json['used_quantity']) ?? 0,
      availableQuantity: _asDouble(json['available_quantity']) ?? 0,
    );
  }
}

class ProjectMaterialStockModel {
  const ProjectMaterialStockModel({required this.items, required this.summary});

  final List<ProjectMaterialStockItemModel> items;
  final ProjectMaterialStockSummaryModel summary;

  factory ProjectMaterialStockModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawSummary = json['summary'];

    return ProjectMaterialStockModel(
      items:
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map(
                    (item) => ProjectMaterialStockItemModel.fromJson(
                      item.map((key, value) => MapEntry(key.toString(), value)),
                    ),
                  )
                  .toList(growable: false)
              : const <ProjectMaterialStockItemModel>[],
      summary: ProjectMaterialStockSummaryModel.fromJson(
        rawSummary is Map
            ? rawSummary.map((key, value) => MapEntry(key.toString(), value))
            : const <String, dynamic>{},
      ),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  return value == null ? null : DateTime.tryParse(value.toString());
}

int _asInt(dynamic value) => _asNullableInt(value) ?? 0;

int? _asNullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
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
