class WarehouseCustodyBalanceModel {
  const WarehouseCustodyBalanceModel({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.custodyWarehouseId,
    required this.responsibleUserId,
    required this.responsibleUserName,
    required this.materialId,
    required this.materialName,
    required this.availableQuantity,
    this.unit,
    this.lastMovementAt,
  });

  final int id;
  final int projectId;
  final String projectName;
  final int custodyWarehouseId;
  final int responsibleUserId;
  final String responsibleUserName;
  final int materialId;
  final String materialName;
  final String? unit;
  final double availableQuantity;
  final DateTime? lastMovementAt;

  factory WarehouseCustodyBalanceModel.fromJson(Map<String, dynamic> json) {
    final project = _optionalMap(json['project']);
    final responsibleUser = _optionalMap(json['responsible_user']);
    final material = _optionalMap(json['material']);
    final measurementUnit = _optionalMap(material?['measurement_unit']);

    return WarehouseCustodyBalanceModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredNestedInt(json, project, 'project_id', 'id'),
      projectName: _requiredNestedString(
        json,
        project,
        'project_name',
        'name',
      ),
      custodyWarehouseId: _requiredInt(json, 'custody_warehouse_id'),
      responsibleUserId: _requiredNestedInt(
        json,
        responsibleUser,
        'responsible_user_id',
        'id',
      ),
      responsibleUserName: _requiredNestedString(
        json,
        responsibleUser,
        'responsible_user_name',
        'name',
      ),
      materialId: _requiredNestedInt(json, material, 'material_id', 'id'),
      materialName: _requiredNestedString(
        json,
        material,
        'material_name',
        'name',
      ),
      unit:
          _asNullableString(json['unit']) ??
          _asNullableString(measurementUnit?['short_name']) ??
          _asNullableString(measurementUnit?['name']),
      availableQuantity: _requiredDouble(json, 'available_quantity'),
      lastMovementAt: _parseDate(json['last_movement_at']),
    );
  }
}

Map<String, dynamic>? _optionalMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return null;
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
    throw FormatException('Warehouse custody field "$key" is required.');
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
    throw FormatException('Warehouse custody field "$key" is required.');
  }

  return value;
}

int _requiredNestedInt(
  Map<String, dynamic> json,
  Map<String, dynamic>? nested,
  String flatKey,
  String nestedKey,
) {
  final value =
      _asNullableInt(json[flatKey]) ?? _asNullableInt(nested?[nestedKey]);
  if (value == null) {
    throw FormatException('Warehouse custody field "$flatKey" is required.');
  }

  return value;
}

String _requiredNestedString(
  Map<String, dynamic> json,
  Map<String, dynamic>? nested,
  String flatKey,
  String nestedKey,
) {
  final value =
      _asNullableString(json[flatKey]) ?? _asNullableString(nested?[nestedKey]);
  if (value == null) {
    throw FormatException('Warehouse custody field "$flatKey" is required.');
  }

  return value;
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
