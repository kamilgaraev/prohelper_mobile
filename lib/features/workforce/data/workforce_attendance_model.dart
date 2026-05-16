class AttendanceQrModel {
  const AttendanceQrModel({
    required this.qrToken,
    required this.expiresAt,
    required this.employeeLabel,
    required this.workDate,
    required this.statusLabel,
    this.projectId,
    this.projectLabel,
  });

  final String qrToken;
  final DateTime expiresAt;
  final String employeeLabel;
  final int? projectId;
  final String? projectLabel;
  final DateTime workDate;
  final String statusLabel;

  factory AttendanceQrModel.fromJson(Map<String, dynamic> json) {
    return AttendanceQrModel(
      qrToken: _asString(json['qr_token']),
      expiresAt: _asDateTime(json['expires_at']),
      employeeLabel: _asString(json['employee_label']),
      projectId: _asNullableInt(json['project_id']),
      projectLabel: _asNullableString(json['project_label']),
      workDate: _asDateTime(json['work_date']),
      statusLabel: _asString(json['status_label']),
    );
  }
}

class AttendanceScanResultModel {
  const AttendanceScanResultModel({
    required this.employeeLabel,
    required this.workDate,
    required this.statusLabel,
    required this.confirmedAt,
    this.projectLabel,
    this.sourceLabel,
  });

  final String employeeLabel;
  final String? projectLabel;
  final DateTime workDate;
  final String statusLabel;
  final String? sourceLabel;
  final DateTime confirmedAt;

  factory AttendanceScanResultModel.fromJson(Map<String, dynamic> json) {
    return AttendanceScanResultModel(
      employeeLabel: _asString(json['employee_label']),
      projectLabel: _asNullableString(json['project_label']),
      workDate: _asDateTime(json['work_date']),
      statusLabel: _asString(json['status_label']),
      sourceLabel: _asNullableString(json['source_label']),
      confirmedAt: _asDateTime(json['confirmed_at']),
    );
  }
}

Map<String, dynamic> workforceObject(dynamic responseData) {
  final payload =
      responseData is Map<String, dynamic>
          ? responseData['data']
          : responseData;

  if (payload is Map) {
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }

  return const {};
}

String _asString(dynamic value) => value?.toString() ?? '';

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';

  return text.isEmpty ? null : text;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

DateTime _asDateTime(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
