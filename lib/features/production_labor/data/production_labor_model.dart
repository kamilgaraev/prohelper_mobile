class LaborProblemFlagModel {
  const LaborProblemFlagModel({
    required this.code,
    required this.severity,
    required this.message,
  });

  final String code;
  final String severity;
  final String message;

  factory LaborProblemFlagModel.fromJson(Map<String, dynamic> json) {
    return LaborProblemFlagModel(
      code: _asString(json['code']),
      severity: _asString(json['severity']),
      message: _asString(json['message']),
    );
  }
}

class LaborWorkOrderLineModel {
  const LaborWorkOrderLineModel({
    required this.id,
    required this.workOrderId,
    required this.name,
    required this.unit,
    required this.plannedQuantity,
    required this.acceptedQuantity,
    required this.remainingQuantity,
    required this.requiresSafetyPermit,
  });

  final int id;
  final int workOrderId;
  final String name;
  final String unit;
  final double plannedQuantity;
  final double acceptedQuantity;
  final double remainingQuantity;
  final bool requiresSafetyPermit;

  factory LaborWorkOrderLineModel.fromJson(Map<String, dynamic> json) {
    return LaborWorkOrderLineModel(
      id: _asInt(json['id']),
      workOrderId: _asInt(json['work_order_id']),
      name: _firstString(json['name'], json['work_name']),
      unit: _asString(json['unit']),
      plannedQuantity: _asDouble(json['planned_quantity']),
      acceptedQuantity: _asDouble(json['accepted_quantity']),
      remainingQuantity: _asDouble(json['remaining_quantity']),
      requiresSafetyPermit: _asBool(json['requires_safety_permit']),
    );
  }
}

class LaborWorkOrderModel {
  const LaborWorkOrderModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    required this.lines,
    this.assigneeName,
    this.problemFlags = const [],
  });

  final int id;
  final int projectId;
  final String title;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final List<String> availableActions;
  final List<LaborWorkOrderLineModel> lines;
  final String? assigneeName;
  final List<LaborProblemFlagModel> problemFlags;

  bool get canRecordFact => status == 'issued' || status == 'in_progress';

  factory LaborWorkOrderModel.fromJson(Map<String, dynamic> json) {
    return LaborWorkOrderModel(
      id: _asInt(json['id']),
      projectId: _asInt(json['project_id']),
      title: _asString(json['title']),
      orderNumber: _firstString(json['order_number'], json['work_order_number']),
      status: _asString(json['status']),
      statusLabel: _asString(json['status_label']),
      availableActions: _stringList(json['available_actions']),
      lines: _mapList(json['lines']).map(LaborWorkOrderLineModel.fromJson).toList(),
      assigneeName: _asNullableString(json['assignee_name']),
      problemFlags: _mapList(json['problem_flags']).map(LaborProblemFlagModel.fromJson).toList(),
    );
  }
}

class LaborOutputModel {
  const LaborOutputModel({
    required this.id,
    required this.workOrderId,
    required this.workOrderLineId,
    required this.workDate,
    required this.quantity,
    required this.hours,
    required this.statusLabel,
  });

  final int id;
  final int workOrderId;
  final int workOrderLineId;
  final String workDate;
  final double quantity;
  final double hours;
  final String statusLabel;

  factory LaborOutputModel.fromJson(Map<String, dynamic> json) {
    return LaborOutputModel(
      id: _asInt(json['id']),
      workOrderId: _asInt(json['work_order_id']),
      workOrderLineId: _asInt(json['work_order_line_id']),
      workDate: _firstString(json['work_date'], json['output_date']),
      quantity: _asDouble(json['quantity']),
      hours: _asDouble(json['hours']),
      statusLabel: _asString(json['status_label']),
    );
  }
}

class LaborTimesheetModel {
  const LaborTimesheetModel({
    required this.id,
    required this.workOrderId,
    required this.shiftDate,
    required this.statusLabel,
    required this.totalHours,
  });

  final int id;
  final int workOrderId;
  final String shiftDate;
  final String statusLabel;
  final double totalHours;

  factory LaborTimesheetModel.fromJson(Map<String, dynamic> json) {
    return LaborTimesheetModel(
      id: _asInt(json['id']),
      workOrderId: _asInt(json['work_order_id']),
      shiftDate: _firstString(json['shift_date'], json['work_date']),
      statusLabel: _asString(json['status_label']),
      totalHours: _asDouble(json['total_hours']),
    );
  }
}

List<Map<String, dynamic>> laborMapList(dynamic value) => _mapList(value);

List<Map<String, dynamic>> _mapList(dynamic value) {
  final list = value is List ? value : const [];

  return list
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? const []).map((item) => item.toString()).toList();
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
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  return value?.toString() == '1' || value?.toString().toLowerCase() == 'true';
}

String _asString(dynamic value) => value?.toString() ?? '';

String _firstString(dynamic primary, dynamic secondary) {
  final first = primary?.toString().trim() ?? '';
  if (first.isNotEmpty) {
    return first;
  }

  return secondary?.toString() ?? '';
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}
