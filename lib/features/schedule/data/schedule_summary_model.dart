class ScheduleSummaryModel {
  const ScheduleSummaryModel({required this.summary, required this.events});

  final ScheduleSummaryData summary;
  final List<ScheduleEventModel> events;

  factory ScheduleSummaryModel.fromJson(Map<String, dynamic> json) {
    return ScheduleSummaryModel(
      summary: ScheduleSummaryData.fromJson(_requiredMap(json, 'summary')),
      events:
          _requiredList(
            json,
            'events',
          ).map(ScheduleEventModel.fromJson).toList(),
    );
  }
}

class ScheduleSummaryData {
  const ScheduleSummaryData({
    required this.todayCount,
    required this.upcomingCount,
    required this.blockingCount,
    required this.inProgressCount,
    this.projectId,
    this.projectName,
  });

  final int todayCount;
  final int upcomingCount;
  final int blockingCount;
  final int inProgressCount;
  final int? projectId;
  final String? projectName;

  factory ScheduleSummaryData.fromJson(Map<String, dynamic> json) {
    return ScheduleSummaryData(
      todayCount: _requiredInt(json, 'today_count'),
      upcomingCount: _requiredInt(json, 'upcoming_count'),
      blockingCount: _requiredInt(json, 'blocking_count'),
      inProgressCount: _requiredInt(json, 'in_progress_count'),
      projectId: _asNullableInt(json['project_id']),
      projectName: _asNullableString(json['project_name']),
    );
  }
}

class ScheduleEventModel {
  const ScheduleEventModel({
    required this.id,
    required this.title,
    required this.eventType,
    required this.eventTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.priority,
    required this.priorityLabel,
    required this.isBlocking,
    required this.isAllDay,
    required this.eventDate,
    this.description,
    this.projectId,
    this.projectName,
    this.eventTime,
    this.location,
  });

  final int id;
  final String title;
  final String eventType;
  final String eventTypeLabel;
  final String status;
  final String statusLabel;
  final String priority;
  final String priorityLabel;
  final bool isBlocking;
  final bool isAllDay;
  final String? description;
  final int? projectId;
  final String? projectName;
  final DateTime eventDate;
  final String? eventTime;
  final String? location;

  factory ScheduleEventModel.fromJson(Map<String, dynamic> json) {
    return ScheduleEventModel(
      id: _requiredInt(json, 'id'),
      title: _requiredString(json, 'title'),
      eventType: _requiredKnownString(json, 'event_type', _eventTypes),
      eventTypeLabel: _requiredCleanLabel(json, 'event_type_label'),
      status: _requiredKnownString(json, 'status', _eventStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      priority: _requiredKnownString(json, 'priority', _eventPriorities),
      priorityLabel: _requiredCleanLabel(json, 'priority_label'),
      isBlocking: _requiredBool(json, 'is_blocking'),
      isAllDay: _requiredBool(json, 'is_all_day'),
      description: _asNullableString(json['description']),
      projectId: _asNullableInt(json['project_id']),
      projectName: _asNullableString(json['project_name']),
      eventDate: _requiredDate(json, 'event_date'),
      eventTime: _asNullableString(json['event_time']),
      location: _asNullableString(json['location']),
    );
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  throw FormatException('Schedule summary field "$key" must be an object.');
}

List<Map<String, dynamic>> _requiredList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Schedule summary field "$key" must be a list.');
  }

  return value.map((item) {
    if (item is Map<String, dynamic>) {
      return item;
    }

    if (item is Map) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException(
      'Schedule summary field "$key" must contain objects.',
    );
  }).toList();
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

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _asNullableInt(json[key]);
  if (value == null) {
    throw FormatException('Schedule summary field "$key" is required.');
  }

  return value;
}

String? _asNullableString(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _asNullableString(json[key]);
  if (value == null) {
    throw FormatException('Schedule summary field "$key" is required.');
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
    throw FormatException('Schedule summary field "$key" has unknown value.');
  }

  return value;
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

  final normalized = value.toString().toLowerCase().trim();
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
    throw FormatException('Schedule summary field "$key" is required.');
  }

  return value;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Schedule summary field "$key" must be a date.');
  }

  return parsed;
}

String? _cleanLabel(dynamic value) {
  final text = _asNullableString(value);
  if (text == null) {
    return null;
  }

  if (text.startsWith('mobile_schedule.')) {
    return null;
  }

  return text;
}

String _requiredCleanLabel(Map<String, dynamic> json, String key) {
  final label = _cleanLabel(json[key]);
  if (label == null) {
    throw FormatException('Schedule summary field "$key" must be readable.');
  }

  return label;
}

const _eventTypes = {
  'inspection',
  'delivery',
  'meeting',
  'maintenance',
  'weather',
  'other',
};

const _eventStatuses = {'scheduled', 'in_progress', 'completed', 'cancelled'};

const _eventPriorities = {'low', 'normal', 'high', 'critical'};
