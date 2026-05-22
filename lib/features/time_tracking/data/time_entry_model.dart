class TimeEntryCorrectionModel {
  const TimeEntryCorrectionModel({
    required this.id,
    required this.reason,
    required this.newHours,
    required this.submittedByUserId,
    required this.createdAt,
    this.previousHours,
  });

  final String id;
  final String reason;
  final double? previousHours;
  final double newHours;
  final int submittedByUserId;
  final String createdAt;

  factory TimeEntryCorrectionModel.fromJson(Map<String, dynamic> json) {
    return TimeEntryCorrectionModel(
      id: _requiredString(json, 'id'),
      reason: _requiredString(json, 'reason'),
      previousHours: _nullableDouble(json['previous_hours']),
      newHours: _requiredDouble(json, 'new_hours'),
      submittedByUserId: _requiredInt(json, 'submitted_by_user_id'),
      createdAt: _requiredString(json, 'created_at'),
    );
  }
}

class TimeEntryApprovalSummaryModel {
  const TimeEntryApprovalSummaryModel({
    required this.status,
    required this.statusLabel,
    this.approvedByLabel,
    this.approvedAt,
    this.rejectionReason,
  });

  final String status;
  final String statusLabel;
  final String? approvedByLabel;
  final String? approvedAt;
  final String? rejectionReason;

  factory TimeEntryApprovalSummaryModel.fromJson(Map<String, dynamic> json) {
    return TimeEntryApprovalSummaryModel(
      status: _requiredStringIn(json, 'status', _timeEntryStatuses),
      statusLabel: _requiredString(json, 'status_label'),
      approvedByLabel: _nullableString(json['approved_by_label']),
      approvedAt: _nullableString(json['approved_at']),
      rejectionReason: _nullableString(json['rejection_reason']),
    );
  }
}

class TimeEntryModel {
  const TimeEntryModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.projectId,
    required this.projectLabel,
    required this.workDate,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.isActiveTimer,
    required this.isBillable,
    required this.corrections,
    required this.availableActions,
    required this.approvalSummary,
    required this.createdAt,
    required this.updatedAt,
    this.workTypeId,
    this.workTypeLabel,
    this.taskId,
    this.taskLabel,
    this.startTime,
    this.endTime,
    this.hoursWorked,
    this.breakTime,
    this.description,
    this.location,
    this.notes,
    this.approvedByUserId,
    this.approvedByLabel,
    this.approvedAt,
    this.rejectionReason,
  });

  final int id;
  final int organizationId;
  final int userId;
  final int projectId;
  final String projectLabel;
  final int? workTypeId;
  final String? workTypeLabel;
  final int? taskId;
  final String? taskLabel;
  final String workDate;
  final String? startTime;
  final String? endTime;
  final double? hoursWorked;
  final double? breakTime;
  final String title;
  final String? description;
  final String status;
  final String statusLabel;
  final bool isActiveTimer;
  final bool isBillable;
  final String? location;
  final String? notes;
  final int? approvedByUserId;
  final String? approvedByLabel;
  final String? approvedAt;
  final String? rejectionReason;
  final List<TimeEntryCorrectionModel> corrections;
  final List<String> availableActions;
  final TimeEntryApprovalSummaryModel approvalSummary;
  final String createdAt;
  final String updatedAt;

  bool get canStop => availableActions.contains('stop');
  bool get canSubmit => availableActions.contains('submit');
  bool get canCorrect => availableActions.contains('correction');

  factory TimeEntryModel.fromJson(Map<String, dynamic> json) {
    return TimeEntryModel(
      id: _requiredInt(json, 'id'),
      organizationId: _requiredInt(json, 'organization_id'),
      userId: _requiredInt(json, 'user_id'),
      projectId: _requiredInt(json, 'project_id'),
      projectLabel: _requiredString(json, 'project_label'),
      workTypeId: _nullableInt(json['work_type_id']),
      workTypeLabel: _nullableString(json['work_type_label']),
      taskId: _nullableInt(json['task_id']),
      taskLabel: _nullableString(json['task_label']),
      workDate: _requiredString(json, 'work_date'),
      startTime: _nullableString(json['start_time']),
      endTime: _nullableString(json['end_time']),
      hoursWorked: _nullableDouble(json['hours_worked']),
      breakTime: _nullableDouble(json['break_time']),
      title: _requiredString(json, 'title'),
      description: _nullableString(json['description']),
      status: _requiredStringIn(json, 'status', _timeEntryStatuses),
      statusLabel: _requiredString(json, 'status_label'),
      isActiveTimer: _requiredBool(json, 'is_active_timer'),
      isBillable: _requiredBool(json, 'is_billable'),
      location: _nullableString(json['location']),
      notes: _nullableString(json['notes']),
      approvedByUserId: _nullableInt(json['approved_by_user_id']),
      approvedByLabel: _nullableString(json['approved_by_label']),
      approvedAt: _nullableString(json['approved_at']),
      rejectionReason: _nullableString(json['rejection_reason']),
      corrections:
          _requiredMapList(
            json,
            'corrections',
          ).map(TimeEntryCorrectionModel.fromJson).toList(),
      availableActions: _requiredStringListIn(
        json,
        'available_actions',
        _timeEntryActions,
      ),
      approvalSummary: TimeEntryApprovalSummaryModel.fromJson(
        _requiredMap(json, 'approval_summary'),
      ),
      createdAt: _requiredString(json, 'created_at'),
      updatedAt: _requiredString(json, 'updated_at'),
    );
  }
}

class TimeEntryListMeta {
  const TimeEntryListMeta({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  factory TimeEntryListMeta.fromJson(Map<String, dynamic> json) {
    return TimeEntryListMeta(
      currentPage: _requiredInt(json, 'current_page'),
      perPage: _requiredInt(json, 'per_page'),
      total: _requiredInt(json, 'total'),
      lastPage: _requiredInt(json, 'last_page'),
    );
  }
}

class TimeTotalsModel {
  const TimeTotalsModel({
    required this.totalHours,
    required this.billableHours,
    required this.entriesCount,
    required this.byStatus,
  });

  final double totalHours;
  final double billableHours;
  final int entriesCount;
  final Map<String, int> byStatus;

  factory TimeTotalsModel.fromJson(Map<String, dynamic> json) {
    return TimeTotalsModel(
      totalHours: _requiredDouble(json, 'total_hours'),
      billableHours: _requiredDouble(json, 'billable_hours'),
      entriesCount: _requiredInt(json, 'entries_count'),
      byStatus: _statusCountMap(_requiredMap(json, 'by_status')),
    );
  }
}

class TimeEntryListResult {
  const TimeEntryListResult({
    required this.items,
    required this.meta,
    required this.summary,
  });

  final List<TimeEntryModel> items;
  final TimeEntryListMeta meta;
  final TimeTotalsModel summary;

  factory TimeEntryListResult.fromJson(Map<String, dynamic> json) {
    return TimeEntryListResult(
      items:
          _requiredMapList(json, 'items').map(TimeEntryModel.fromJson).toList(),
      meta: TimeEntryListMeta.fromJson(_requiredMap(json, 'meta')),
      summary: TimeTotalsModel.fromJson(_requiredMap(json, 'summary')),
    );
  }
}

class DailyTimeSummaryModel {
  const DailyTimeSummaryModel({
    required this.date,
    required this.entries,
    required this.totals,
    required this.approvalStatus,
    this.projectId,
    this.activeTimer,
  });

  final String date;
  final int? projectId;
  final List<TimeEntryModel> entries;
  final TimeEntryModel? activeTimer;
  final TimeTotalsModel totals;
  final Map<String, int> approvalStatus;

  factory DailyTimeSummaryModel.fromJson(Map<String, dynamic> json) {
    final activeTimerMap = _nullableMap(json['active_timer']);

    return DailyTimeSummaryModel(
      date: _requiredString(json, 'date'),
      projectId: _nullableInt(json['project_id']),
      entries:
          _requiredMapList(
            json,
            'entries',
          ).map(TimeEntryModel.fromJson).toList(),
      activeTimer:
          activeTimerMap == null
              ? null
              : TimeEntryModel.fromJson(activeTimerMap),
      totals: TimeTotalsModel.fromJson(_requiredMap(json, 'totals')),
      approvalStatus: _statusCountMap(_requiredMap(json, 'approval_status')),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Missing integer field: $key');
  }

  return parsed;
}

int? _nullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    throw const FormatException('Invalid nullable integer field');
  }

  return parsed;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = _nullableDouble(json[key]);
  if (value == null) {
    throw FormatException('Missing double field: $key');
  }

  return value;
}

double? _nullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }

  final parsed = double.tryParse(value.toString());
  if (parsed == null) {
    throw const FormatException('Invalid nullable double field');
  }

  return parsed;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing bool field: $key');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing string field: $key');
  }

  return value;
}

String _requiredStringIn(
  Map<String, dynamic> json,
  String key,
  Set<String> allowed,
) {
  return _stringInValue(_requiredString(json, key), key, allowed);
}

String _stringInValue(String value, String key, Set<String> allowed) {
  if (!allowed.contains(value)) {
    throw FormatException('Invalid string field: $key');
  }

  return value;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const <String, dynamic>{};
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing map field: $key');
  }

  final map = _asMap(json[key]);
  if (map.isEmpty) {
    throw FormatException('Invalid map field: $key');
  }

  return map;
}

Map<String, dynamic>? _nullableMap(dynamic value) {
  if (value == null) {
    return null;
  }

  final map = _asMap(value);
  if (map.isEmpty) {
    throw const FormatException('Invalid nullable map field');
  }

  return map;
}

List<Map<String, dynamic>> _requiredMapList(
  Map<String, dynamic> json,
  String key,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing list field: $key');
  }

  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }

  return value
      .map((item) {
        if (item is! Map) {
          throw FormatException('Invalid list item: $key');
        }

        return item.map((key, value) => MapEntry(key.toString(), value));
      })
      .toList(growable: false);
}

List<String> _requiredStringListIn(
  Map<String, dynamic> json,
  String key,
  Set<String> allowed,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing list field: $key');
  }

  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid list field: $key');
  }

  return value
      .map((item) => _stringInValue(item.toString(), key, allowed))
      .toList(growable: false);
}

Map<String, int> _statusCountMap(Map<String, dynamic> map) {
  return map.map((key, value) {
    final status = _stringInValue(key, 'by_status', _timeEntryStatuses);
    final count = _nullableInt(value);
    if (count == null) {
      throw const FormatException('Invalid status count');
    }

    return MapEntry(status, count);
  });
}

const _timeEntryStatuses = {'draft', 'submitted', 'approved', 'rejected'};

const _timeEntryActions = {'stop', 'submit', 'correction'};
