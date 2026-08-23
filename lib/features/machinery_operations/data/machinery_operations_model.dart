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
    this.assignmentId,
    this.organizationAssetId,
    this.inventoryNumber,
    this.qrCode,
    this.meterHours = 0,
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
  final int? assignmentId;
  final int? organizationAssetId;
  final String? inventoryNumber;
  final String? qrCode;
  final double meterHours;
  final List<MachineryProblemFlagModel> problemFlags;

  factory MachineryAssetModel.fromJson(Map<String, dynamic> json) {
    return MachineryAssetModel(
      id: _asInt(json['id']),
      assetCode: _asString(json['asset_code']),
      name: _asString(json['name']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
      availableActions: _stringList(json['available_actions']),
      projectId: _asNullableInt(
        json['current_project_id'] ??
            _nestedInt(json['linked_entities'], 'project_id'),
      ),
      projectName: _nestedName(json['current_project'] ?? json['project']),
      assignmentId: _nestedInt(json['current_assignment'], 'id'),
      organizationAssetId: _asNullableInt(json['organization_asset_id']),
      inventoryNumber: _asNullableString(json['inventory_number']),
      qrCode: _asNullableString(json['qr_code']),
      meterHours: _asDouble(json['meter_hours']),
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
    this.assignmentId,
    this.scheduleTaskId,
    this.constructionJournalEntryId,
    this.meterStart,
    this.meterEnd,
    this.cancelledAt,
    this.cancellationReason,
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
  final int? assignmentId;
  final int? scheduleTaskId;
  final int? constructionJournalEntryId;
  final double? meterStart;
  final double? meterEnd;
  final String? cancelledAt;
  final String? cancellationReason;

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
      assignmentId: _asNullableInt(json['assignment_id']),
      scheduleTaskId: _asNullableInt(json['schedule_task_id']),
      constructionJournalEntryId: _asNullableInt(
        json['construction_journal_entry_id'],
      ),
      meterStart: _asNullableDouble(json['meter_start']),
      meterEnd: _asNullableDouble(json['meter_end']),
      cancelledAt: _asNullableString(json['cancelled_at']),
      cancellationReason: _asNullableString(json['cancellation_reason']),
    );
  }
}

class MachineryMaintenanceOrderModel {
  const MachineryMaintenanceOrderModel({
    required this.id,
    required this.assetId,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.priority,
    required this.availableActions,
    this.projectId,
    this.plannedAt,
    this.description,
  });

  final int id;
  final int assetId;
  final int? projectId;
  final String title;
  final String status;
  final String statusLabel;
  final String priority;
  final DateTime? plannedAt;
  final String? description;
  final List<String> availableActions;

  factory MachineryMaintenanceOrderModel.fromJson(Map<String, dynamic> json) {
    return MachineryMaintenanceOrderModel(
      id: _asInt(json['id']),
      assetId: _asInt(json['asset_id']),
      projectId: _asNullableInt(json['project_id']),
      title: _asString(json['title']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
      priority: _asString(json['priority']),
      plannedAt: DateTime.tryParse(_asString(json['planned_at'])),
      description: _asNullableString(json['description']),
      availableActions: _stringList(json['available_actions']),
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

int? _nestedInt(dynamic value, String key) {
  if (value is Map) {
    return _asNullableInt(value[key]);
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

double? _asNullableDouble(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return _asDouble(value);
}

String _asString(dynamic value) => value?.toString() ?? '';

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}
