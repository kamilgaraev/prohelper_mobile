class AttendanceQrModel {
  const AttendanceQrModel({
    required this.qrToken,
    required this.expiresAt,
    required this.employeeId,
    required this.employeeLabel,
    required this.workDate,
    required this.status,
    required this.statusLabel,
    this.projectId,
    this.projectLabel,
  });

  final String qrToken;
  final DateTime expiresAt;
  final int employeeId;
  final String employeeLabel;
  final int? projectId;
  final String? projectLabel;
  final DateTime workDate;
  final String status;
  final String statusLabel;

  factory AttendanceQrModel.fromJson(Map<String, dynamic> json) {
    return AttendanceQrModel(
      qrToken: _requiredString(json, 'qr_token'),
      expiresAt: _requiredDateTime(json, 'expires_at'),
      employeeId: _requiredInt(json, 'employee_id'),
      employeeLabel: _requiredString(json, 'employee_label'),
      projectId: _nullableInt(json, 'project_id'),
      projectLabel: _nullableString(json, 'project_label'),
      workDate: _requiredDate(json, 'work_date'),
      status: _requiredAllowedString(json, 'status', const {'active'}),
      statusLabel: _requiredString(json, 'status_label'),
    );
  }
}

class AttendanceScanResultModel {
  const AttendanceScanResultModel({
    required this.scanEventId,
    required this.employeeId,
    required this.employeeLabel,
    required this.workDate,
    required this.status,
    required this.statusLabel,
    required this.source,
    required this.sourceLabel,
    required this.confirmedAt,
    this.projectId,
    this.projectLabel,
  });

  final int scanEventId;
  final int employeeId;
  final String employeeLabel;
  final int? projectId;
  final String? projectLabel;
  final DateTime workDate;
  final String status;
  final String statusLabel;
  final String source;
  final String sourceLabel;
  final DateTime confirmedAt;

  factory AttendanceScanResultModel.fromJson(Map<String, dynamic> json) {
    return AttendanceScanResultModel(
      scanEventId: _requiredInt(json, 'scan_event_id'),
      employeeId: _requiredInt(json, 'employee_id'),
      employeeLabel: _requiredString(json, 'employee_label'),
      projectId: _nullableInt(json, 'project_id'),
      projectLabel: _nullableString(json, 'project_label'),
      workDate: _requiredDate(json, 'work_date'),
      status: _requiredAllowedString(json, 'status', const {'at_work'}),
      statusLabel: _requiredString(json, 'status_label'),
      source: _requiredAllowedString(json, 'source', const {
        'qr_scan',
        'self_attendance',
      }),
      sourceLabel: _requiredString(json, 'source_label'),
      confirmedAt: _requiredDateTime(json, 'confirmed_at'),
    );
  }

  AttendanceHistoryItemModel toHistoryItem() {
    return AttendanceHistoryItemModel(
      scanEventId: scanEventId,
      employeeId: employeeId,
      employeeLabel: employeeLabel,
      projectId: projectId,
      projectLabel: projectLabel,
      workDate: workDate,
      status: status,
      statusLabel: statusLabel,
      source: source,
      sourceLabel: sourceLabel,
      confirmedAt: confirmedAt,
    );
  }
}

class AttendanceHistoryModel {
  const AttendanceHistoryModel({required this.items});

  final List<AttendanceHistoryItemModel> items;

  factory AttendanceHistoryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryModel(
      items: _requiredList(
        json,
        'items',
      ).map(AttendanceHistoryItemModel.fromJson).toList(growable: false),
    );
  }
}

class AttendanceHistoryItemModel {
  const AttendanceHistoryItemModel({
    required this.scanEventId,
    required this.employeeId,
    required this.employeeLabel,
    required this.workDate,
    required this.status,
    required this.statusLabel,
    required this.source,
    required this.sourceLabel,
    required this.confirmedAt,
    this.projectId,
    this.projectLabel,
  });

  final int scanEventId;
  final int employeeId;
  final String employeeLabel;
  final int? projectId;
  final String? projectLabel;
  final DateTime workDate;
  final String status;
  final String statusLabel;
  final String source;
  final String sourceLabel;
  final DateTime confirmedAt;

  factory AttendanceHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryItemModel(
      scanEventId: _requiredInt(json, 'scan_event_id'),
      employeeId: _requiredInt(json, 'employee_id'),
      employeeLabel: _requiredString(json, 'employee_label'),
      projectId: _nullableInt(json, 'project_id'),
      projectLabel: _nullableString(json, 'project_label'),
      workDate: _requiredDate(json, 'work_date'),
      status: _requiredAllowedString(json, 'status', const {'at_work'}),
      statusLabel: _requiredString(json, 'status_label'),
      source: _requiredAllowedString(json, 'source', const {
        'qr_scan',
        'self_attendance',
        'manual_correction',
      }),
      sourceLabel: _requiredString(json, 'source_label'),
      confirmedAt: _requiredDateTime(json, 'confirmed_at'),
    );
  }
}

Map<String, dynamic> workforceDataMap(dynamic responseData, String endpoint) {
  final root = _asMap(responseData, '$endpoint response');

  if (!root.containsKey('data')) {
    throw FormatException('$endpoint response data is required.');
  }

  return _asMap(root['data'], '$endpoint data');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  throw FormatException('Workforce attendance field "$key" is required.');
}

String _requiredAllowedString(
  Map<String, dynamic> json,
  String key,
  Set<String> allowed,
) {
  final value = _requiredString(json, key);

  if (allowed.contains(value)) {
    return value;
  }

  throw FormatException('Workforce attendance field "$key" has unknown value.');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is String) {
    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  throw FormatException('Workforce attendance field "$key" must be a string.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is int) {
    return value;
  }

  if (value is num && value % 1 == 0) {
    return value.toInt();
  }

  if (value is String && value.trim().isNotEmpty) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) {
      return parsed;
    }
  }

  throw FormatException('Workforce attendance field "$key" is required.');
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num && value % 1 == 0) {
    return value.toInt();
  }

  if (value is String && value.trim().isNotEmpty) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) {
      return parsed;
    }
  }

  throw FormatException(
    'Workforce attendance field "$key" must be an integer.',
  );
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);

  if (parsed != null && value.length == 10) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  throw FormatException('Workforce attendance field "$key" must be a date.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);

  if (parsed != null) {
    return parsed;
  }

  throw FormatException(
    'Workforce attendance field "$key" must be a date-time.',
  );
}

List<Map<String, dynamic>> _requiredList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];

  if (value is! List) {
    throw FormatException('Workforce attendance field "$key" must be a list.');
  }

  return value.map((item) => _asMap(item, key)).toList(growable: false);
}

Map<String, dynamic> _asMap(dynamic value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  throw FormatException(
    'Workforce attendance field "$field" must be an object.',
  );
}
