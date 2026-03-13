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
    final summaryJson = json['summary'];
    final warehousesJson = json['warehouses'];
    final movementsJson = json['recent_movements'];

    return WarehouseSummaryModel(
      summary: WarehouseSummaryData.fromJson(
        summaryJson is Map<String, dynamic>
            ? summaryJson
            : summaryJson is Map
                ? summaryJson.map((key, value) => MapEntry(key.toString(), value))
                : const {},
      ),
      warehouses: (warehousesJson as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (warehouse) => WarehouseCardModel.fromJson(
              warehouse.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
      recentMovements: (movementsJson as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (movement) => WarehouseMovementModel.fromJson(
              movement.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
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
      warehouseCount: json['warehouse_count'] as int? ?? 0,
      uniqueItemsCount: json['unique_items_count'] as int? ?? 0,
      lowStockCount: json['low_stock_count'] as int? ?? 0,
      reservedItemsCount: json['reserved_items_count'] as int? ?? 0,
      recentMovementsCount: json['recent_movements_count'] as int? ?? 0,
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
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
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isMain: json['is_main'] as bool? ?? false,
      uniqueItemsCount: json['unique_items_count'] as int? ?? 0,
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      warehouseType: json['warehouse_type'] as String?,
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
  final String? warehouseName;
  final String? materialName;
  final String? measurementUnit;
  final String? projectName;
  final String? documentNumber;
  final String? reason;
  final DateTime? movementDate;

  factory WarehouseMovementModel.fromJson(Map<String, dynamic> json) {
    return WarehouseMovementModel(
      id: json['id'] as int? ?? 0,
      movementType: json['movement_type'] as String? ?? '',
      movementTypeLabel: json['movement_type_label'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      warehouseName: json['warehouse_name'] as String?,
      materialName: json['material_name'] as String?,
      measurementUnit: json['measurement_unit'] as String?,
      projectName: json['project_name'] as String?,
      documentNumber: json['document_number'] as String?,
      reason: json['reason'] as String?,
      movementDate: json['movement_date'] != null
          ? DateTime.tryParse(json['movement_date'].toString())
          : null,
    );
  }
}
