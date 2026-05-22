class WarehouseSummaryModel {
  const WarehouseSummaryModel({
    required this.summary,
    required this.warehouses,
    required this.recentMovements,
  });

  final WarehouseSummaryData summary;
  final List<WarehouseCardModel> warehouses;
  final List<WarehouseMovementModel> recentMovements;

  factory WarehouseSummaryModel.fromJson(Map<String, dynamic> json) {
    final summaryJson = _requiredMap(json, 'summary');
    final warehousesJson = _requiredList(json, 'warehouses');
    final movementsJson = _requiredList(json, 'recent_movements');

    return WarehouseSummaryModel(
      summary: WarehouseSummaryData.fromJson(summaryJson),
      warehouses: warehousesJson.map(WarehouseCardModel.fromJson).toList(),
      recentMovements:
          movementsJson.map(WarehouseMovementModel.fromJson).toList(),
    );
  }
}

class WarehouseSummaryData {
  const WarehouseSummaryData({
    required this.warehouseCount,
    required this.uniqueItemsCount,
    required this.lowStockCount,
    required this.reservedItemsCount,
    required this.recentMovementsCount,
    required this.totalValue,
  });

  final int warehouseCount;
  final int uniqueItemsCount;
  final int lowStockCount;
  final int reservedItemsCount;
  final int recentMovementsCount;
  final double totalValue;

  factory WarehouseSummaryData.fromJson(Map<String, dynamic> json) {
    return WarehouseSummaryData(
      warehouseCount: _requiredInt(json, 'warehouse_count'),
      uniqueItemsCount: _requiredInt(json, 'unique_items_count'),
      lowStockCount: _requiredInt(json, 'low_stock_count'),
      reservedItemsCount: _requiredInt(json, 'reserved_items_count'),
      recentMovementsCount: _requiredInt(json, 'recent_movements_count'),
      totalValue: _requiredDouble(json, 'total_value'),
    );
  }
}

class WarehouseCardModel {
  const WarehouseCardModel({
    required this.id,
    required this.name,
    required this.isMain,
    required this.uniqueItemsCount,
    required this.totalValue,
    this.address,
    this.warehouseType,
  });

  final int id;
  final String name;
  final bool isMain;
  final int uniqueItemsCount;
  final double totalValue;
  final String? address;
  final String? warehouseType;

  factory WarehouseCardModel.fromJson(Map<String, dynamic> json) {
    return WarehouseCardModel(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      isMain: _requiredBool(json, 'is_main'),
      uniqueItemsCount: _requiredInt(json, 'unique_items_count'),
      totalValue: _requiredDouble(json, 'total_value'),
      address: _asNullableString(json['address']),
      warehouseType: _asNullableString(json['warehouse_type']),
    );
  }
}

class WarehouseMovementModel {
  const WarehouseMovementModel({
    required this.id,
    required this.movementType,
    required this.movementTypeLabel,
    required this.quantity,
    required this.price,
    required this.photoGallery,
    this.warehouseName,
    this.materialName,
    this.measurementUnit,
    this.projectName,
    this.documentNumber,
    this.reason,
    this.movementDate,
  });

  final int id;
  final String movementType;
  final String movementTypeLabel;
  final double quantity;
  final double price;
  final List<WarehousePhotoModel> photoGallery;
  final String? warehouseName;
  final String? materialName;
  final String? measurementUnit;
  final String? projectName;
  final String? documentNumber;
  final String? reason;
  final DateTime? movementDate;

  WarehouseMovementModel copyWith({List<WarehousePhotoModel>? photoGallery}) {
    return WarehouseMovementModel(
      id: id,
      movementType: movementType,
      movementTypeLabel: movementTypeLabel,
      quantity: quantity,
      price: price,
      photoGallery: photoGallery ?? this.photoGallery,
      warehouseName: warehouseName,
      materialName: materialName,
      measurementUnit: measurementUnit,
      projectName: projectName,
      documentNumber: documentNumber,
      reason: reason,
      movementDate: movementDate,
    );
  }

  factory WarehouseMovementModel.fromJson(Map<String, dynamic> json) {
    final movementType = _requiredKnownString(
      json,
      'movement_type',
      _movementTypes,
    );

    return WarehouseMovementModel(
      id: _requiredInt(json, 'id'),
      movementType: movementType,
      movementTypeLabel: _requiredCleanLabel(json, 'movement_type_label'),
      quantity: _requiredDouble(json, 'quantity'),
      price: _requiredDouble(json, 'price'),
      warehouseName: _requiredString(json, 'warehouse_name'),
      materialName: _requiredString(json, 'material_name'),
      measurementUnit: _asNullableString(json['measurement_unit']),
      projectName: _asNullableString(json['project_name']),
      documentNumber: _asNullableString(json['document_number']),
      reason: _asNullableString(json['reason']),
      movementDate:
          json['movement_date'] != null
              ? DateTime.tryParse(json['movement_date'].toString())
              : null,
      photoGallery:
          _optionalList(
            json['photo_gallery'],
          ).map(WarehousePhotoModel.fromJson).toList(),
    );
  }
}

class WarehousePhotoModel {
  const WarehousePhotoModel({
    required this.id,
    required this.url,
    this.name,
    this.originalName,
    this.mimeType,
    this.size,
  });

  final int id;
  final String url;
  final String? name;
  final String? originalName;
  final String? mimeType;
  final int? size;

  factory WarehousePhotoModel.fromJson(Map<String, dynamic> json) {
    return WarehousePhotoModel(
      id: _requiredInt(json, 'id'),
      url: _requiredString(json, 'url'),
      name: _asNullableString(json['name']),
      originalName: _asNullableString(json['original_name']),
      mimeType: _asNullableString(json['mime_type']),
      size: json['size'] is num ? (json['size'] as num).toInt() : null,
    );
  }
}

class WarehouseBalanceModel {
  const WarehouseBalanceModel({
    required this.warehouseId,
    required this.warehouseName,
    required this.materialId,
    required this.materialName,
    required this.availableQuantity,
    required this.reservedQuantity,
    required this.totalQuantity,
    required this.averagePrice,
    required this.totalValue,
    required this.isLowStock,
    required this.photoGallery,
    required this.assetPhotoGallery,
    this.materialCode,
    this.assetType,
    this.category,
    this.measurementUnit,
    this.minStockLevel,
    this.maxStockLevel,
    this.locationCode,
    this.lastMovementAt,
  });

  final int warehouseId;
  final String warehouseName;
  final int materialId;
  final String materialName;
  final double availableQuantity;
  final double reservedQuantity;
  final double totalQuantity;
  final double averagePrice;
  final double totalValue;
  final bool isLowStock;
  final List<WarehousePhotoModel> photoGallery;
  final List<WarehousePhotoModel> assetPhotoGallery;
  final String? materialCode;
  final String? assetType;
  final String? category;
  final String? measurementUnit;
  final double? minStockLevel;
  final double? maxStockLevel;
  final String? locationCode;
  final DateTime? lastMovementAt;

  List<WarehousePhotoModel> get effectivePhotoGallery =>
      photoGallery.isNotEmpty ? photoGallery : assetPhotoGallery;

  WarehouseBalanceModel copyWith({
    List<WarehousePhotoModel>? photoGallery,
    List<WarehousePhotoModel>? assetPhotoGallery,
  }) {
    return WarehouseBalanceModel(
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      materialId: materialId,
      materialName: materialName,
      availableQuantity: availableQuantity,
      reservedQuantity: reservedQuantity,
      totalQuantity: totalQuantity,
      averagePrice: averagePrice,
      totalValue: totalValue,
      isLowStock: isLowStock,
      photoGallery: photoGallery ?? this.photoGallery,
      assetPhotoGallery: assetPhotoGallery ?? this.assetPhotoGallery,
      materialCode: materialCode,
      assetType: assetType,
      category: category,
      measurementUnit: measurementUnit,
      minStockLevel: minStockLevel,
      maxStockLevel: maxStockLevel,
      locationCode: locationCode,
      lastMovementAt: lastMovementAt,
    );
  }

  factory WarehouseBalanceModel.fromJson(Map<String, dynamic> json) {
    return WarehouseBalanceModel(
      warehouseId: _requiredInt(json, 'warehouse_id'),
      warehouseName: _requiredString(json, 'warehouse_name'),
      materialId: _requiredInt(json, 'material_id'),
      materialName: _requiredString(json, 'material_name'),
      availableQuantity: _requiredDouble(json, 'available_quantity'),
      reservedQuantity: _requiredDouble(json, 'reserved_quantity'),
      totalQuantity: _requiredDouble(json, 'total_quantity'),
      averagePrice: _requiredDouble(json, 'average_price'),
      totalValue: _requiredDouble(json, 'total_value'),
      isLowStock: _requiredBool(json, 'is_low_stock'),
      photoGallery:
          _optionalList(
            json['photo_gallery'],
          ).map(WarehousePhotoModel.fromJson).toList(),
      assetPhotoGallery:
          _optionalList(
            json['asset_photo_gallery'],
          ).map(WarehousePhotoModel.fromJson).toList(),
      materialCode: _asNullableString(json['material_code']),
      assetType: _asNullableString(json['asset_type']),
      category: _asNullableString(json['category']),
      measurementUnit: _asNullableString(json['measurement_unit']),
      minStockLevel: _asNullableDouble(json['min_stock_level']),
      maxStockLevel: _asNullableDouble(json['max_stock_level']),
      locationCode: _asNullableString(json['location_code']),
      lastMovementAt:
          json['last_movement_at'] != null
              ? DateTime.tryParse(json['last_movement_at'].toString())
              : null,
    );
  }
}

class WarehouseMaterialOption {
  const WarehouseMaterialOption({
    required this.id,
    required this.name,
    required this.defaultPrice,
    this.code,
    this.measurementUnitId,
    this.measurementUnitName,
    this.measurementUnitShortName,
  });

  final int id;
  final String name;
  final double defaultPrice;
  final String? code;
  final int? measurementUnitId;
  final String? measurementUnitName;
  final String? measurementUnitShortName;

  String get measurementLabel =>
      measurementUnitShortName?.trim().isNotEmpty == true
          ? measurementUnitShortName!
          : (measurementUnitName ?? '');

  factory WarehouseMaterialOption.fromJson(Map<String, dynamic> json) {
    final measurementUnitJson = _optionalMap(json['measurement_unit']);

    return WarehouseMaterialOption(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      defaultPrice: _requiredDouble(json, 'default_price'),
      code: _asNullableString(json['code']),
      measurementUnitId:
          measurementUnitJson.isEmpty
              ? null
              : _requiredInt(measurementUnitJson, 'id'),
      measurementUnitName: _asNullableString(measurementUnitJson['name']),
      measurementUnitShortName: _asNullableString(
        measurementUnitJson['short_name'],
      ),
    );
  }
}

class WarehouseReceiptPayload {
  const WarehouseReceiptPayload({
    required this.warehouseId,
    required this.materialId,
    required this.quantity,
    required this.price,
    required this.photos,
    this.documentNumber,
    this.reason,
    this.projectId,
    this.metadata = const <String, dynamic>{},
  });

  final int warehouseId;
  final int materialId;
  final double quantity;
  final double price;
  final List<String> photos;
  final String? documentNumber;
  final String? reason;
  final int? projectId;
  final Map<String, dynamic> metadata;
}

Map<String, dynamic> _optionalMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return const <String, dynamic>{};
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = _optionalMap(json[key]);
  if (value.isEmpty && json[key] is! Map) {
    throw FormatException('Warehouse field "$key" must be an object.');
  }

  return value;
}

List<Map<String, dynamic>> _optionalList(dynamic value) {
  if (value == null) {
    return const <Map<String, dynamic>>[];
  }

  if (value is! List) {
    throw const FormatException('Warehouse field must be a list.');
  }

  return value.whereType<Map>().map(_asMap).toList();
}

List<Map<String, dynamic>> _requiredList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Warehouse field "$key" must be a list.');
  }

  return value.whereType<Map>().map(_asMap).toList();
}

Map<String, dynamic> _asMap(Map<dynamic, dynamic> value) {
  return value.map((key, value) => MapEntry(key.toString(), value));
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
    throw FormatException('Warehouse field "$key" is required.');
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
    throw FormatException('Warehouse field "$key" is required.');
  }

  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Warehouse field "$key" is required.');
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
    throw FormatException('Warehouse field "$key" has unknown value.');
  }

  return value;
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
    throw FormatException('Warehouse field "$key" is required.');
  }

  return value;
}

String? _cleanLabel(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  if (text.startsWith('mobile_warehouse.')) {
    return null;
  }

  return text;
}

String _requiredCleanLabel(Map<String, dynamic> json, String key) {
  final label = _cleanLabel(json[key]);
  if (label == null) {
    throw FormatException('Warehouse field "$key" must be readable.');
  }

  return label;
}

const _movementTypes = {
  'receipt',
  'write_off',
  'transfer_in',
  'transfer_out',
  'adjustment',
  'return',
};
