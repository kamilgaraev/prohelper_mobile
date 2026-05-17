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
      occurredAt: json['occurred_at'] != null
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
    final measurementUnit = material is Map ? material['measurement_unit'] : null;
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
      materialUnit: measurementUnit is Map
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
      siteRequestId: linkedEntities is Map
          ? _asNullableInt(linkedEntities['site_request_id'])
          : null,
      purchaseRequestId: linkedEntities is Map
          ? _asNullableInt(linkedEntities['purchase_request_id'])
          : null,
      purchaseOrderId: linkedEntities is Map
          ? _asNullableInt(linkedEntities['purchase_order_id'])
          : null,
      canReceive: json['can_receive'] == true,
      events: rawEvents is List
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
