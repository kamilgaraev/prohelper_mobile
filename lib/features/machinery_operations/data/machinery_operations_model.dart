class MachineryProblemFlagModel {
  const MachineryProblemFlagModel({
    required this.code,
    required this.severity,
    required this.message,
  });

  final String code;
  final String severity;
  final String message;

  factory MachineryProblemFlagModel.fromJson(Map<String, dynamic> json) {
    return MachineryProblemFlagModel(
      code: _asString(json['code']),
      severity: _asString(json['severity']),
      message: _asString(json['message']),
    );
  }
}

class MachineryAssetModel {
  const MachineryAssetModel({
    required this.id,
    required this.assetCode,
    required this.name,
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    this.projectId,
    this.projectName,
    this.problemFlags = const [],
  });

  final int id;
  final String assetCode;
  final String name;
  final String status;
  final String statusLabel;
  final List<String> availableActions;
  final int? projectId;
  final String? projectName;
  final List<MachineryProblemFlagModel> problemFlags;

  factory MachineryAssetModel.fromJson(Map<String, dynamic> json) {
    return MachineryAssetModel(
      id: _asInt(json['id']),
      assetCode: _asString(json['asset_code']),
      name: _asString(json['name']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
      availableActions: _stringList(json['available_actions']),
      projectId: _asNullableInt(json['project_id']),
      projectName: _nestedName(json['project']),
      problemFlags:
          _mapList(
            json['problem_flags'],
          ).map(MachineryProblemFlagModel.fromJson).toList(),
    );
  }
}

class MachineryShiftReportModel {
  const MachineryShiftReportModel({
    required this.id,
    required this.assetId,
    required this.projectId,
    required this.reportDate,
    required this.status,
    required this.statusLabel,
    required this.actualHours,
    required this.fuelConsumed,
    required this.availableActions,
    this.assetName,
  });

  final int id;
  final int assetId;
  final int projectId;
  final String reportDate;
  final String status;
  final String statusLabel;
  final double actualHours;
  final double fuelConsumed;
  final List<String> availableActions;
  final String? assetName;

  factory MachineryShiftReportModel.fromJson(Map<String, dynamic> json) {
    return MachineryShiftReportModel(
      id: _asInt(json['id']),
      assetId: _asInt(json['asset_id']),
      projectId: _asInt(json['project_id']),
      reportDate: _asString(json['report_date']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
      actualHours: _asDouble(json['actual_hours']),
      fuelConsumed: _asDouble(json['fuel_consumed']),
      availableActions: _stringList(json['available_actions']),
      assetName: _nestedName(json['asset']),
    );
  }
}

List<Map<String, dynamic>> machineryMapList(dynamic value) => _mapList(value);

List<Map<String, dynamic>> _mapList(dynamic value) {
  final list = value is List ? value : const [];

  return list
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .toList();
}

String? _nestedName(dynamic value) {
  if (value is Map) {
    return _asNullableString(value['name']);
  }

  return null;
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

int? _asNullableInt(dynamic value) {
  final parsed = _asInt(value);

  return parsed == 0 ? null : parsed;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(dynamic value) => value?.toString() ?? '';

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}
