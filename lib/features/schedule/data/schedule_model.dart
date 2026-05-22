abstract final class ScheduleActionKeys {
  static const recordFact = 'record_fact';
  static const submit = 'submit';
  static const createLinkedAction = 'create_linked_action';
}

class ScheduleOverviewModel {
  const ScheduleOverviewModel({
    required this.project,
    required this.summary,
    required this.schedules,
  });

  final ScheduleProjectModel project;
  final ScheduleOverviewSummaryModel summary;
  final List<ScheduleItemModel> schedules;

  factory ScheduleOverviewModel.fromJson(Map<String, dynamic> json) {
    return ScheduleOverviewModel(
      project: ScheduleProjectModel.fromJson(_requiredMap(json, 'project')),
      summary: ScheduleOverviewSummaryModel.fromJson(
        _requiredMap(json, 'summary'),
      ),
      schedules:
          _requiredList(
            json,
            'schedules',
          ).map(ScheduleItemModel.fromJson).toList(),
    );
  }
}

class ScheduleProjectModel {
  const ScheduleProjectModel({required this.id, required this.name});

  final int id;
  final String name;

  factory ScheduleProjectModel.fromJson(Map<String, dynamic> json) {
    return ScheduleProjectModel(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
    );
  }
}

class ScheduleOverviewSummaryModel {
  const ScheduleOverviewSummaryModel({
    required this.totalSchedules,
    required this.activeSchedules,
    required this.completedSchedules,
    required this.averageProgressPercent,
  });

  final int totalSchedules;
  final int activeSchedules;
  final int completedSchedules;
  final double averageProgressPercent;

  factory ScheduleOverviewSummaryModel.fromJson(Map<String, dynamic> json) {
    return ScheduleOverviewSummaryModel(
      totalSchedules: _requiredInt(json, 'total_schedules'),
      activeSchedules: _requiredInt(json, 'active_schedules'),
      completedSchedules: _requiredInt(json, 'completed_schedules'),
      averageProgressPercent: _requiredDouble(json, 'average_progress_percent'),
    );
  }
}

class ScheduleItemModel {
  const ScheduleItemModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.overallProgressPercent,
    required this.progressColor,
    required this.criticalPathCalculated,
    required this.tasksCount,
    required this.completedTasksCount,
    required this.overdueTasksCount,
    this.healthStatus,
    this.description,
    this.plannedStartDate,
    this.plannedEndDate,
    this.plannedDurationDays,
    this.actualStartDate,
    this.actualEndDate,
    this.criticalPathDurationDays,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int projectId;
  final String name;
  final String? description;
  final String status;
  final String statusLabel;
  final String statusColor;
  final double overallProgressPercent;
  final String progressColor;
  final String? healthStatus;
  final String? plannedStartDate;
  final String? plannedEndDate;
  final int? plannedDurationDays;
  final String? actualStartDate;
  final String? actualEndDate;
  final bool criticalPathCalculated;
  final int? criticalPathDurationDays;
  final int tasksCount;
  final int completedTasksCount;
  final int overdueTasksCount;
  final String? createdAt;
  final String? updatedAt;

  factory ScheduleItemModel.fromJson(Map<String, dynamic> json) {
    return ScheduleItemModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      name: _requiredString(json, 'name'),
      description: _asNullableString(json['description']),
      status: _requiredKnownString(json, 'status', _scheduleStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      statusColor: _requiredColor(json, 'status_color'),
      overallProgressPercent: _requiredDouble(json, 'overall_progress_percent'),
      progressColor: _requiredColor(json, 'progress_color'),
      healthStatus: _asNullableKnownString(
        json['health_status'],
        _healthStatuses,
        'health_status',
      ),
      plannedStartDate: _asNullableString(json['planned_start_date']),
      plannedEndDate: _asNullableString(json['planned_end_date']),
      plannedDurationDays: _asNullableInt(json['planned_duration_days']),
      actualStartDate: _asNullableString(json['actual_start_date']),
      actualEndDate: _asNullableString(json['actual_end_date']),
      criticalPathCalculated: _requiredBool(json, 'critical_path_calculated'),
      criticalPathDurationDays: _asNullableInt(
        json['critical_path_duration_days'],
      ),
      tasksCount: _requiredInt(json, 'tasks_count'),
      completedTasksCount: _requiredInt(json, 'completed_tasks_count'),
      overdueTasksCount: _requiredInt(json, 'overdue_tasks_count'),
      createdAt: _asNullableString(json['created_at']),
      updatedAt: _asNullableString(json['updated_at']),
    );
  }
}

class ScheduleDetailsModel {
  const ScheduleDetailsModel({
    required this.project,
    required this.schedule,
    required this.summary,
    required this.tasks,
  });

  final ScheduleProjectModel project;
  final ScheduleItemModel schedule;
  final ScheduleDetailsSummaryModel summary;
  final List<ScheduleTaskModel> tasks;

  factory ScheduleDetailsModel.fromJson(Map<String, dynamic> json) {
    return ScheduleDetailsModel(
      project: ScheduleProjectModel.fromJson(_requiredMap(json, 'project')),
      schedule: ScheduleItemModel.fromJson(_requiredMap(json, 'schedule')),
      summary: ScheduleDetailsSummaryModel.fromJson(
        _requiredMap(json, 'summary'),
      ),
      tasks:
          _requiredList(json, 'tasks').map(ScheduleTaskModel.fromJson).toList(),
    );
  }
}

class ScheduleDetailsSummaryModel {
  const ScheduleDetailsSummaryModel({
    required this.tasksCount,
    required this.completedTasksCount,
    required this.inProgressTasksCount,
    required this.overdueTasksCount,
  });

  final int tasksCount;
  final int completedTasksCount;
  final int inProgressTasksCount;
  final int overdueTasksCount;

  factory ScheduleDetailsSummaryModel.fromJson(Map<String, dynamic> json) {
    return ScheduleDetailsSummaryModel(
      tasksCount: _requiredInt(json, 'tasks_count'),
      completedTasksCount: _requiredInt(json, 'completed_tasks_count'),
      inProgressTasksCount: _requiredInt(json, 'in_progress_tasks_count'),
      overdueTasksCount: _requiredInt(json, 'overdue_tasks_count'),
    );
  }
}

class ScheduleTaskModel {
  const ScheduleTaskModel({
    required this.id,
    required this.name,
    required this.taskType,
    required this.taskTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.progressPercent,
    required this.isCritical,
    required this.level,
    required this.childrenCount,
    this.parentTaskId,
    this.description,
    this.plannedStartDate,
    this.plannedEndDate,
    this.plannedDurationDays,
    this.actualStartDate,
    this.actualEndDate,
    this.quantity,
    this.completedQuantity,
    this.measurementUnit,
  });

  final int id;
  final int? parentTaskId;
  final String name;
  final String? description;
  final String taskType;
  final String taskTypeLabel;
  final String status;
  final String statusLabel;
  final String statusColor;
  final double progressPercent;
  final bool isCritical;
  final int level;
  final int childrenCount;
  final String? plannedStartDate;
  final String? plannedEndDate;
  final int? plannedDurationDays;
  final String? actualStartDate;
  final String? actualEndDate;
  final double? quantity;
  final double? completedQuantity;
  final String? measurementUnit;

  factory ScheduleTaskModel.fromJson(Map<String, dynamic> json) {
    return ScheduleTaskModel(
      id: _requiredInt(json, 'id'),
      parentTaskId: _asNullableInt(json['parent_task_id']),
      name: _requiredString(json, 'name'),
      description: _asNullableString(json['description']),
      taskType: _requiredKnownString(json, 'task_type', _taskTypes),
      taskTypeLabel: _requiredCleanLabel(json, 'task_type_label'),
      status: _requiredKnownString(json, 'status', _taskStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      statusColor: _requiredColor(json, 'status_color'),
      progressPercent: _requiredDouble(json, 'progress_percent'),
      isCritical: _requiredBool(json, 'is_critical'),
      level: _requiredInt(json, 'level'),
      childrenCount: _requiredInt(json, 'children_count'),
      plannedStartDate: _asNullableString(json['planned_start_date']),
      plannedEndDate: _asNullableString(json['planned_end_date']),
      plannedDurationDays: _asNullableInt(json['planned_duration_days']),
      actualStartDate: _asNullableString(json['actual_start_date']),
      actualEndDate: _asNullableString(json['actual_end_date']),
      quantity: _asNullableDouble(json['quantity']),
      completedQuantity: _asNullableDouble(json['completed_quantity']),
      measurementUnit: _asNullableString(json['measurement_unit']),
    );
  }
}

class DailyWorkPlanModel {
  const DailyWorkPlanModel({
    required this.id,
    required this.projectId,
    required this.scheduleId,
    required this.lookaheadPlanId,
    required this.scheduleName,
    required this.workDate,
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    required this.assignments,
  });

  final int id;
  final int projectId;
  final int scheduleId;
  final int lookaheadPlanId;
  final String scheduleName;
  final String workDate;
  final String status;
  final String statusLabel;
  final List<ScheduleActionModel> availableActions;
  final List<DailyWorkPlanAssignmentModel> assignments;

  bool hasAction(String action) {
    return availableActions.any((item) => item.action == action);
  }

  factory DailyWorkPlanModel.fromJson(Map<String, dynamic> json) {
    return DailyWorkPlanModel(
      id: _requiredInt(json, 'id'),
      projectId: _requiredInt(json, 'project_id'),
      scheduleId: _requiredInt(json, 'schedule_id'),
      lookaheadPlanId: _requiredInt(json, 'lookahead_plan_id'),
      scheduleName: _requiredString(json, 'schedule_name'),
      workDate: _requiredString(json, 'work_date'),
      status: _requiredKnownString(json, 'status', _dailyPlanStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      availableActions:
          _requiredList(
            json,
            'available_actions',
          ).map(ScheduleActionModel.fromJson).toList(),
      assignments:
          _requiredList(
            json,
            'assignments',
          ).map(DailyWorkPlanAssignmentModel.fromJson).toList(),
    );
  }
}

class ScheduleActionModel {
  const ScheduleActionModel({required this.action, required this.label});

  final String action;
  final String label;

  factory ScheduleActionModel.fromJson(Map<String, dynamic> json) {
    return ScheduleActionModel(
      action: _requiredKnownString(json, 'action', _scheduleActions),
      label: _requiredCleanLabel(json, 'label'),
    );
  }
}

class DailyWorkFactStatusOptionModel {
  const DailyWorkFactStatusOptionModel({
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  factory DailyWorkFactStatusOptionModel.fromJson(Map<String, dynamic> json) {
    return DailyWorkFactStatusOptionModel(
      status: _requiredKnownString(json, 'status', _assignmentStatuses),
      label: _requiredCleanLabel(json, 'label'),
    );
  }
}

class DailyWorkFactInput {
  const DailyWorkFactInput({
    required this.status,
    this.completedQuantity,
    this.actualWorkHours,
    this.factComment,
    this.failureReason,
  });

  final String status;
  final double? completedQuantity;
  final double? actualWorkHours;
  final String? factComment;
  final String? failureReason;

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (completedQuantity != null) 'completed_quantity': completedQuantity,
      if (actualWorkHours != null) 'actual_work_hours': actualWorkHours,
      if (factComment != null && factComment!.trim().isNotEmpty)
        'fact_comment': factComment!.trim(),
      if (failureReason != null && failureReason!.trim().isNotEmpty)
        'failure_reason': failureReason!.trim(),
    };
  }
}

class DailyWorkPlanAssignmentModel {
  const DailyWorkPlanAssignmentModel({
    required this.id,
    required this.dailyWorkPlanId,
    required this.lookaheadPlanTaskId,
    required this.scheduleTaskId,
    required this.status,
    required this.statusLabel,
    required this.factStatusOptions,
    required this.scheduleTaskName,
    required this.plannedQuantity,
    required this.completedQuantity,
    required this.plannedWorkHours,
    required this.actualWorkHours,
    required this.constraints,
    required this.linkedBlockingEntities,
    this.journalEntryId,
    this.failureReason,
    this.factComment,
  });

  final int id;
  final int dailyWorkPlanId;
  final int lookaheadPlanTaskId;
  final int scheduleTaskId;
  final int? journalEntryId;
  final String status;
  final String statusLabel;
  final List<DailyWorkFactStatusOptionModel> factStatusOptions;
  final double? plannedQuantity;
  final double? completedQuantity;
  final double? plannedWorkHours;
  final double? actualWorkHours;
  final String? failureReason;
  final String? factComment;
  final String scheduleTaskName;
  final List<DailyWorkConstraintModel> constraints;
  final List<DailyWorkLinkedEntityModel> linkedBlockingEntities;

  factory DailyWorkPlanAssignmentModel.fromJson(Map<String, dynamic> json) {
    final scheduleTask = _requiredMap(json, 'schedule_task');

    return DailyWorkPlanAssignmentModel(
      id: _requiredInt(json, 'id'),
      dailyWorkPlanId: _requiredInt(json, 'daily_work_plan_id'),
      lookaheadPlanTaskId: _requiredInt(json, 'lookahead_plan_task_id'),
      scheduleTaskId: _requiredInt(json, 'schedule_task_id'),
      journalEntryId: _asNullableInt(json['journal_entry_id']),
      status: _requiredKnownString(json, 'status', _assignmentStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      factStatusOptions:
          _requiredList(
            json,
            'fact_status_options',
          ).map(DailyWorkFactStatusOptionModel.fromJson).toList(),
      plannedQuantity: _asNullableDouble(json['planned_quantity']),
      completedQuantity: _asNullableDouble(json['completed_quantity']),
      plannedWorkHours: _asNullableDouble(json['planned_work_hours']),
      actualWorkHours: _asNullableDouble(json['actual_work_hours']),
      failureReason: _asNullableString(json['failure_reason']),
      factComment: _asNullableString(json['fact_comment']),
      scheduleTaskName: _requiredString(scheduleTask, 'name'),
      constraints:
          _requiredList(
            json,
            'constraints',
          ).map(DailyWorkConstraintModel.fromJson).toList(),
      linkedBlockingEntities:
          _requiredList(
            json,
            'linked_blocking_entities',
          ).map(DailyWorkLinkedEntityModel.fromJson).toList(),
    );
  }
}

class DailyWorkConstraintModel {
  const DailyWorkConstraintModel({
    required this.id,
    required this.title,
    required this.constraintType,
    required this.constraintTypeLabel,
    required this.severity,
    required this.severityLabel,
    required this.status,
    required this.statusLabel,
    required this.availableActions,
    this.linkedAction,
    this.linkedEntity,
    this.dueDate,
  });

  final int id;
  final String title;
  final String constraintType;
  final String constraintTypeLabel;
  final String severity;
  final String severityLabel;
  final String status;
  final String statusLabel;
  final List<ScheduleActionModel> availableActions;
  final DailyWorkLinkedEntityModel? linkedAction;
  final DailyWorkLinkedEntityModel? linkedEntity;
  final String? dueDate;

  bool hasAction(String action) {
    return availableActions.any((item) => item.action == action);
  }

  factory DailyWorkConstraintModel.fromJson(Map<String, dynamic> json) {
    final linkedActionJson = _optionalMap(json['linked_action']);
    final linkedEntityJson = _optionalMap(json['linked_entity']);

    return DailyWorkConstraintModel(
      id: _requiredInt(json, 'id'),
      title: _requiredString(json, 'title'),
      constraintType: _requiredKnownString(
        json,
        'constraint_type',
        _constraintTypes,
      ),
      constraintTypeLabel: _requiredCleanLabel(json, 'constraint_type_label'),
      severity: _requiredKnownString(json, 'severity', _constraintSeverities),
      severityLabel: _requiredCleanLabel(json, 'severity_label'),
      status: _requiredKnownString(json, 'status', _constraintStatuses),
      statusLabel: _requiredCleanLabel(json, 'status_label'),
      availableActions:
          _requiredList(
            json,
            'available_actions',
          ).map(ScheduleActionModel.fromJson).toList(),
      linkedAction:
          linkedActionJson == null
              ? null
              : DailyWorkLinkedEntityModel.fromJson(linkedActionJson),
      linkedEntity:
          linkedEntityJson == null
              ? null
              : DailyWorkLinkedEntityModel.fromJson(linkedEntityJson),
      dueDate: _asNullableString(json['due_date']),
    );
  }
}

class DailyWorkLinkedEntityModel {
  const DailyWorkLinkedEntityModel({
    required this.type,
    required this.id,
    this.constraintId,
  });

  final String type;
  final int id;
  final int? constraintId;

  factory DailyWorkLinkedEntityModel.fromJson(Map<String, dynamic> json) {
    return DailyWorkLinkedEntityModel(
      type: _requiredKnownString(json, 'type', _linkedEntityTypes),
      id: _requiredInt(json, 'id'),
      constraintId: _asNullableInt(json['constraint_id']),
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

  throw FormatException('Schedule field "$key" must be an object.');
}

Map<String, dynamic>? _optionalMap(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  throw const FormatException('Schedule field must be an object.');
}

List<Map<String, dynamic>> _requiredList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Schedule field "$key" must be a list.');
  }

  return value.map((item) {
    if (item is Map<String, dynamic>) {
      return item;
    }

    if (item is Map) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('Schedule field "$key" must contain objects.');
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
    throw FormatException('Schedule field "$key" is required.');
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
    throw FormatException('Schedule field "$key" is required.');
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
    throw FormatException('Schedule field "$key" is required.');
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
    throw FormatException('Schedule field "$key" has unknown value.');
  }

  return value;
}

String? _asNullableKnownString(
  dynamic value,
  Set<String> allowedValues,
  String key,
) {
  final normalized = _asNullableString(value);
  if (normalized == null) {
    return null;
  }

  if (!allowedValues.contains(normalized)) {
    throw FormatException('Schedule field "$key" has unknown value.');
  }

  return normalized;
}

String _requiredColor(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  final hasValidLength = normalized.length == 6 || normalized.length == 8;
  final parsed = int.tryParse(normalized, radix: 16);

  if (!hasValidLength || parsed == null) {
    throw FormatException('Schedule field "$key" must be a hex color.');
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
    throw FormatException('Schedule field "$key" is required.');
  }

  return value;
}

String? _cleanLabel(dynamic value) {
  final text = _asNullableString(value);
  if (text == null) {
    return null;
  }

  if (text.startsWith('schedule_management.') ||
      text.startsWith('mobile_schedule.')) {
    return null;
  }

  return text;
}

String _requiredCleanLabel(Map<String, dynamic> json, String key) {
  final label = _cleanLabel(json[key]);
  if (label == null) {
    throw FormatException('Schedule field "$key" must be readable.');
  }

  return label;
}

const _scheduleStatuses = {
  'draft',
  'active',
  'paused',
  'completed',
  'cancelled',
};

const _taskStatuses = {
  'not_started',
  'in_progress',
  'completed',
  'cancelled',
  'on_hold',
  'waiting',
};

const _taskTypes = {'task', 'milestone', 'summary', 'container'};

const _healthStatuses = {
  'healthy',
  'on_track',
  'at_risk',
  'warning',
  'critical',
  'delayed',
  'overdue',
};

const _dailyPlanStatuses = {
  'draft',
  'published',
  'in_progress',
  'submitted',
  'accepted',
  'closed',
  'revised',
  'returned',
};

const _assignmentStatuses = {'planned', 'done', 'partially_done', 'not_done'};

const _scheduleActions = {
  ScheduleActionKeys.recordFact,
  ScheduleActionKeys.submit,
  ScheduleActionKeys.createLinkedAction,
};

const _constraintTypes = {
  'material_missing',
  'labor_missing',
  'machinery_missing',
  'design_question',
  'executive_doc_missing',
  'safety_permit_missing',
  'quality_blocker',
  'access_blocked',
  'weather_risk',
  'customer_decision',
  'other',
};

const _constraintSeverities = {'soft', 'hard'};

const _constraintStatuses = {'open', 'resolved', 'cancelled'};

const _linkedEntityTypes = {
  'site_request',
  'quality_defect',
  'safety_incident',
};
