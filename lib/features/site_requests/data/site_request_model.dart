import 'package:isar/isar.dart';

class SiteRequestTransition {
  const SiteRequestTransition({
    required this.status,
    this.name,
    this.color,
    this.icon,
  });

  final String status;
  final String? name;
  final String? color;
  final String? icon;

  factory SiteRequestTransition.fromJson(Map<String, dynamic> json) {
    final status = _requiredString(json, 'status');
    final name = _cleanLabel(json['name']);

    if (!_siteRequestStatuses.contains(status) && name == null) {
      throw FormatException(
        'Site request transition "$status" must include a readable name.',
      );
    }

    return SiteRequestTransition(
      status: status,
      name: name,
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
    );
  }
}

class SiteRequestHistoryEntry {
  const SiteRequestHistoryEntry({
    required this.id,
    required this.action,
    required this.actionLabel,
    this.notes,
    this.createdAt,
    this.userName,
    this.oldStatusLabel,
    this.newStatusLabel,
  });

  final int id;
  final String action;
  final String actionLabel;
  final String? notes;
  final DateTime? createdAt;
  final String? userName;
  final String? oldStatusLabel;
  final String? newStatusLabel;

  factory SiteRequestHistoryEntry.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    return SiteRequestHistoryEntry(
      id: _requiredInt(json, 'id'),
      action: _requiredString(json, 'action'),
      actionLabel: _requiredCleanLabel(json, 'action_label'),
      notes: json['notes']?.toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      userName: user is Map ? user['name']?.toString() : null,
      oldStatusLabel: _cleanLabel(json['old_status_label']),
      newStatusLabel: _cleanLabel(json['new_status_label']),
    );
  }
}

class SiteRequestGroupItem {
  const SiteRequestGroupItem({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.requestType,
    this.requestTypeLabel,
    this.materialName,
    this.materialQuantity,
    this.materialUnit,
    this.notes,
    this.assignedUserName,
    this.isCurrent = false,
  });

  final int id;
  final String title;
  final String status;
  final String statusLabel;
  final String requestType;
  final String? requestTypeLabel;
  final String? materialName;
  final double? materialQuantity;
  final String? materialUnit;
  final String? notes;
  final String? assignedUserName;
  final bool isCurrent;

  factory SiteRequestGroupItem.fromJson(Map<String, dynamic> json) {
    final assignedUser = json['assigned_user'];

    return SiteRequestGroupItem(
      id: _requiredInt(json, 'id'),
      title: _requiredString(json, 'title'),
      status: _requiredKnownString(json, 'status', _siteRequestStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      requestType: _requiredKnownString(
        json,
        'request_type',
        _siteRequestTypes,
      ),
      requestTypeLabel: _cleanLabel(json['request_type_label']),
      materialName: json['material_name']?.toString(),
      materialQuantity: _asDouble(json['material_quantity']),
      materialUnit: json['material_unit']?.toString(),
      notes: json['notes']?.toString(),
      assignedUserName:
          assignedUser is Map ? assignedUser['name']?.toString() : null,
      isCurrent: json['is_current'] == true,
    );
  }
}

class SiteRequestPurchaseRequestSummary {
  const SiteRequestPurchaseRequestSummary({
    required this.id,
    required this.number,
    required this.status,
    this.statusLabel,
    this.createdAt,
  });

  final int id;
  final String number;
  final String status;
  final String? statusLabel;
  final DateTime? createdAt;

  factory SiteRequestPurchaseRequestSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return SiteRequestPurchaseRequestSummary(
      id: _requiredInt(json, 'id'),
      number: _requiredString(json, 'request_number'),
      status: _requiredString(json, 'status'),
      statusLabel: _cleanLabel(json['status_label']),
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }
}

class SiteRequestPurchaseOrderSummary {
  const SiteRequestPurchaseOrderSummary({
    required this.id,
    required this.number,
    required this.status,
    this.statusLabel,
    this.supplierName,
    this.deliveryDate,
    this.createdAt,
  });

  final int id;
  final String number;
  final String status;
  final String? statusLabel;
  final String? supplierName;
  final String? deliveryDate;
  final DateTime? createdAt;

  factory SiteRequestPurchaseOrderSummary.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'];

    return SiteRequestPurchaseOrderSummary(
      id: _requiredInt(json, 'id'),
      number: _requiredString(json, 'order_number'),
      status: _requiredString(json, 'status'),
      statusLabel: _cleanLabel(json['status_label']),
      supplierName: supplier is Map ? supplier['name']?.toString() : null,
      deliveryDate: json['delivery_date']?.toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }
}

class SiteRequestSupplierRequestSummary {
  const SiteRequestSupplierRequestSummary({
    required this.id,
    required this.number,
    required this.status,
    this.statusLabel,
    this.supplierName,
    this.sentAt,
    this.createdAt,
  });

  final int id;
  final String number;
  final String status;
  final String? statusLabel;
  final String? supplierName;
  final String? sentAt;
  final DateTime? createdAt;

  factory SiteRequestSupplierRequestSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final supplier = json['supplier'];
    final externalSupplier = json['external_supplier_contact'];

    return SiteRequestSupplierRequestSummary(
      id: _requiredInt(json, 'id'),
      number: _requiredString(json, 'request_number'),
      status: _requiredString(json, 'status'),
      statusLabel: _cleanLabel(json['status_label']),
      supplierName:
          supplier is Map
              ? supplier['name']?.toString()
              : externalSupplier is Map
              ? externalSupplier['name']?.toString()
              : null,
      sentAt: json['sent_at']?.toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }
}

class SiteRequestDeliverySummary {
  const SiteRequestDeliverySummary({
    required this.status,
    this.statusLabel,
    this.statusColor,
    this.requestedQuantity,
    this.reservedQuantity,
    this.shippedQuantity,
    this.acceptedQuantity,
    this.plannedDeliveryDate,
    this.latestDeliveryId,
    this.canReceive = false,
  });

  final String status;
  final String? statusLabel;
  final String? statusColor;
  final double? requestedQuantity;
  final double? reservedQuantity;
  final double? shippedQuantity;
  final double? acceptedQuantity;
  final String? plannedDeliveryDate;
  final int? latestDeliveryId;
  final bool canReceive;

  factory SiteRequestDeliverySummary.fromJson(Map<String, dynamic> json) {
    return SiteRequestDeliverySummary(
      status: _requiredString(json, 'status'),
      statusLabel: _cleanLabel(json['status_label']),
      statusColor: json['status_color']?.toString(),
      requestedQuantity: _asDouble(json['requested_quantity']),
      reservedQuantity: _asDouble(json['reserved_quantity']),
      shippedQuantity: _asDouble(json['shipped_quantity']),
      acceptedQuantity: _asDouble(json['accepted_quantity']),
      plannedDeliveryDate: json['planned_delivery_date']?.toString(),
      latestDeliveryId: _asNullableInt(json['latest_delivery_id']),
      canReceive: json['can_receive'] == true,
    );
  }
}

class SiteRequestModel {
  Id id = Isar.autoIncrement;

  late int serverId;
  late String title;
  String? description;
  String? notes;
  late String status;
  String? statusLabel;
  String? statusColor;
  late String priority;
  String? priorityLabel;
  String? priorityColor;
  late String requestType;
  String? requestTypeLabel;
  String? requiredDate;

  String? materialName;
  double? materialQuantity;
  String? materialUnit;

  String? personnelType;
  String? personnelTypeLabel;
  int? personnelCount;
  String? equipmentType;
  String? equipmentTypeLabel;
  String? workStartDate;
  String? workEndDate;
  String? rentalStartDate;
  String? rentalEndDate;

  int? projectId;
  String? projectName;
  String? userName;
  String? assignedUserName;
  int? siteRequestGroupId;
  String? groupTitle;
  String? groupStatus;
  String? groupStatusLabel;
  int groupRequestCount = 0;
  bool canBeCancelled = false;
  bool canBeEdited = false;
  bool materialReserved = false;
  double? reservedQuantity;
  DateTime? reservedAt;
  bool materialsReceived = false;
  DateTime? materialsReceivedAt;
  int? warehouseId;
  DateTime? createdAt;
  List<SiteRequestTransition> availableTransitions = const [];
  List<SiteRequestHistoryEntry> history = const [];
  List<SiteRequestGroupItem> groupItems = const [];
  List<SiteRequestPurchaseRequestSummary> purchaseRequests = const [];
  List<SiteRequestSupplierRequestSummary> supplierRequests = const [];
  List<SiteRequestPurchaseOrderSummary> purchaseOrders = const [];
  SiteRequestDeliverySummary? deliverySummary;

  SiteRequestModel();

  factory SiteRequestModel.fromJson(Map<String, dynamic> json) {
    _rejectDeprecatedKeys(json, const {
      'purchaseRequests': 'purchase_requests',
      'purchaseOrders': 'purchase_orders',
      'supplierRequests': 'supplier_requests',
      'deliverySummary': 'delivery_summary',
    });

    final rawTransitions = json['available_transitions'];
    final transitions =
        rawTransitions is List
            ? rawTransitions
                .whereType<Map>()
                .map(
                  (item) => SiteRequestTransition.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
            : const <SiteRequestTransition>[];
    final rawHistory = json['history'];
    final history =
        rawHistory is List
            ? rawHistory
                .whereType<Map>()
                .map(
                  (item) => SiteRequestHistoryEntry.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
            : const <SiteRequestHistoryEntry>[];
    final groupSummary = json['group'];
    final groupContext = json['group_context'];
    final groupPayload =
        groupContext is Map
            ? groupContext.map((key, value) => MapEntry(key.toString(), value))
            : groupSummary is Map
            ? groupSummary.map((key, value) => MapEntry(key.toString(), value))
            : null;
    final groupItems =
        groupContext is Map
            ? _requiredList(groupContext, 'items')
                .whereType<Map>()
                .map(
                  (item) => SiteRequestGroupItem.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
            : const <SiteRequestGroupItem>[];
    final metadata = json['metadata'];
    final rawPurchaseRequests = json['purchase_requests'];
    final purchaseRequests =
        rawPurchaseRequests is List
            ? rawPurchaseRequests
                .whereType<Map>()
                .map(
                  (item) => SiteRequestPurchaseRequestSummary.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
            : const <SiteRequestPurchaseRequestSummary>[];
    final rawSupplierRequests = json['supplier_requests'];
    final supplierRequests =
        rawSupplierRequests is List
            ? rawSupplierRequests
                .whereType<Map>()
                .map(
                  (item) => SiteRequestSupplierRequestSummary.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
            : const <SiteRequestSupplierRequestSummary>[];
    final rawPurchaseOrders = json['purchase_orders'];
    final purchaseOrders =
        rawPurchaseOrders is List
            ? rawPurchaseOrders
                .whereType<Map>()
                .map(
                  (item) => SiteRequestPurchaseOrderSummary.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
            : const <SiteRequestPurchaseOrderSummary>[];
    final user = json['user'];
    final assignedUser = json['assigned_user'];
    final rawDeliverySummary = json['delivery_summary'];

    return SiteRequestModel()
      ..serverId = _requiredInt(json, 'id')
      ..title = _requiredString(json, 'title')
      ..description = json['description']?.toString()
      ..notes = json['notes']?.toString()
      ..status = _requiredKnownString(json, 'status', _siteRequestStatuses)
      ..statusLabel = _cleanLabel(json['status_label'])
      ..statusColor = json['status_color']?.toString()
      ..priority = _requiredKnownString(
        json,
        'priority',
        _siteRequestPriorities,
      )
      ..priorityLabel = _cleanLabel(json['priority_label'])
      ..priorityColor = json['priority_color']?.toString()
      ..requestType = _requiredKnownString(
        json,
        'request_type',
        _siteRequestTypes,
      )
      ..requestTypeLabel = _cleanLabel(json['request_type_label'])
      ..requiredDate = json['required_date']?.toString()
      ..materialName = json['material_name']?.toString()
      ..materialQuantity = _asDouble(json['material_quantity'])
      ..materialUnit = json['material_unit']?.toString()
      ..personnelType = json['personnel_type']?.toString()
      ..personnelTypeLabel = _cleanLabel(json['personnel_type_label'])
      ..personnelCount = _asNullableInt(json['personnel_count'])
      ..equipmentType = json['equipment_type']?.toString()
      ..equipmentTypeLabel = _resolveEquipmentTypeLabel(
        json['equipment_type_label']?.toString(),
        json['equipment_type']?.toString(),
      )
      ..workStartDate = json['work_start_date']?.toString()
      ..workEndDate = json['work_end_date']?.toString()
      ..rentalStartDate = json['rental_start_date']?.toString()
      ..rentalEndDate = json['rental_end_date']?.toString()
      ..projectId = _asNullableInt(json['project_id'])
      ..projectName =
          json['project'] is Map ? (json['project']['name']?.toString()) : null
      ..userName = user is Map ? user['name']?.toString() : null
      ..assignedUserName =
          assignedUser is Map ? assignedUser['name']?.toString() : null
      ..siteRequestGroupId = _asNullableInt(json['site_request_group_id'])
      ..groupTitle = groupPayload?['title']?.toString()
      ..groupStatus = groupPayload?['status']?.toString()
      ..groupStatusLabel =
          groupPayload != null
              ? _cleanLabel(groupPayload['status_label'])
              : null
      ..groupRequestCount =
          groupContext is Map
              ? _requiredInt(
                groupContext.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
                'request_count',
              )
              : 0
      ..canBeCancelled = json['can_be_cancelled'] == true
      ..canBeEdited = json['can_be_edited'] == true
      ..materialReserved =
          metadata is Map && metadata['material_reserved'] == true
      ..reservedQuantity =
          metadata is Map ? _asDouble(metadata['reserved_quantity']) : null
      ..reservedAt =
          metadata is Map && metadata['reserved_at'] != null
              ? DateTime.tryParse(metadata['reserved_at'].toString())
              : null
      ..materialsReceived =
          metadata is Map && metadata['materials_received'] == true
      ..materialsReceivedAt =
          metadata is Map && metadata['received_at'] != null
              ? DateTime.tryParse(metadata['received_at'].toString())
              : null
      ..warehouseId =
          metadata is Map ? _asNullableInt(metadata['warehouse_id']) : null
      ..createdAt =
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null
      ..availableTransitions = transitions
      ..history = history
      ..groupItems = groupItems
      ..purchaseRequests = purchaseRequests
      ..supplierRequests = supplierRequests
      ..purchaseOrders = purchaseOrders
      ..deliverySummary =
          rawDeliverySummary is Map
              ? SiteRequestDeliverySummary.fromJson(
                rawDeliverySummary.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              : null;
  }
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

double? _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _asNullableInt(json[key]);
  if (value == null) {
    throw FormatException('Site request field "$key" is required.');
  }

  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Site request field "$key" is required.');
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
    throw FormatException('Site request field "$key" has unknown value.');
  }

  return value;
}

String? _cleanLabel(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  if (text.startsWith('site_requests.') || text.startsWith('mobile_')) {
    return null;
  }

  return text;
}

String _requiredCleanLabel(Map<String, dynamic> json, String key) {
  final label = _cleanLabel(json[key]);
  if (label == null) {
    throw FormatException('Site request field "$key" must be readable.');
  }

  return label;
}

List<dynamic> _requiredList(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Site request field "$key" must be a list.');
  }

  return value;
}

void _rejectDeprecatedKeys(
  Map<String, dynamic> json,
  Map<String, String> replacements,
) {
  for (final entry in replacements.entries) {
    if (json.containsKey(entry.key)) {
      throw FormatException(
        'Site request field "${entry.key}" was replaced by "${entry.value}".',
      );
    }
  }
}

String? _resolveEquipmentTypeLabel(String? rawLabel, String? rawType) {
  final label = _cleanLabel(rawLabel);
  if (label != null) {
    return label;
  }

  return switch ((rawType ?? '').trim().toLowerCase()) {
    'tower_crane' => 'Башенный кран',
    'mobile_crane' => 'Автокран',
    'excavator' => 'Экскаватор',
    'bulldozer' => 'Бульдозер',
    'loader' => 'Погрузчик',
    'dump_truck' => 'Самосвал',
    'concrete_mixer' => 'Бетономешалка',
    'concrete_pump' => 'Бетононасос',
    'forklift' => 'Вилочный погрузчик',
    'scaffolding' => 'Строительные леса',
    'compressor' => 'Компрессор',
    'generator' => 'Генератор',
    'welding_machine' => 'Сварочный аппарат',
    'vibrator' => 'Вибратор для бетона',
    'grader' => 'Грейдер',
    'roller' => 'Каток',
    'other' => 'Другое',
    '' => null,
    _ => throw FormatException('Unknown site request equipment type.'),
  };
}

const _siteRequestStatuses = {
  'draft',
  'pending',
  'in_review',
  'approved',
  'rejected',
  'in_progress',
  'fulfilled',
  'completed',
  'cancelled',
  'on_hold',
};

const _siteRequestPriorities = {'low', 'medium', 'high', 'urgent'};

const _siteRequestTypes = {
  'material_request',
  'personnel_request',
  'equipment_request',
  'info_request',
  'issue_report',
  'other',
};
