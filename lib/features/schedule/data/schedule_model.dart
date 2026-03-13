class ScheduleOverviewModel {
  const ScheduleOverviewModel({
    required this.project,
    required this.summary,
    required this.schedules,
  });

  final ScheduleProjectModel? project;
  final ScheduleOverviewSummaryModel summary;
  final List<ScheduleItemModel> schedules;

  factory ScheduleOverviewModel.fromJson(Map<String, dynamic> json) {
    final projectJson = json['project'];
    final summaryJson = json['summary'];
    final schedulesJson = json['schedules'];

    return ScheduleOverviewModel(
      project: projectJson is Map<String, dynamic>
          ? ScheduleProjectModel.fromJson(projectJson)
          : projectJson is Map
              ? ScheduleProjectModel.fromJson(
                  projectJson.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : null,
      summary: ScheduleOverviewSummaryModel.fromJson(
        summaryJson is Map<String, dynamic>
            ? summaryJson
            : summaryJson is Map
                ? summaryJson.map((key, value) => MapEntry(key.toString(), value))
                : const {},
      ),
      schedules: (schedulesJson as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (schedule) => ScheduleItemModel.fromJson(
              schedule.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
    );
  }
}

class ScheduleProjectModel {
  const ScheduleProjectModel({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ScheduleProjectModel.fromJson(Map<String, dynamic> json) {
    return ScheduleProjectModel(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
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
      totalSchedules: _parseInt(json['total_schedules']),
      activeSchedules: _parseInt(json['active_schedules']),
      completedSchedules: _parseInt(json['completed_schedules']),
      averageProgressPercent: _parseDouble(json['average_progress_percent']),
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
    required this.healthStatus,
    required this.criticalPathCalculated,
    required this.tasksCount,
    required this.completedTasksCount,
    required this.overdueTasksCount,
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
  final String healthStatus;
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
      id: _parseInt(json['id']),
      projectId: _parseInt(json['project_id']),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      statusColor: json['status_color'] as String? ?? '#6B7280',
      overallProgressPercent: _parseDouble(json['overall_progress_percent']),
      progressColor: json['progress_color'] as String? ?? '#3B82F6',
      healthStatus: json['health_status'] as String? ?? '',
      plannedStartDate: json['planned_start_date'] as String?,
      plannedEndDate: json['planned_end_date'] as String?,
      plannedDurationDays: json['planned_duration_days'] as int?,
      actualStartDate: json['actual_start_date'] as String?,
      actualEndDate: json['actual_end_date'] as String?,
      criticalPathCalculated: json['critical_path_calculated'] as bool? ?? false,
      criticalPathDurationDays: json['critical_path_duration_days'] as int?,
      tasksCount: _parseInt(json['tasks_count']),
      completedTasksCount: _parseInt(json['completed_tasks_count']),
      overdueTasksCount: _parseInt(json['overdue_tasks_count']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
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

  final ScheduleProjectModel? project;
  final ScheduleItemModel schedule;
  final ScheduleDetailsSummaryModel summary;
  final List<ScheduleTaskModel> tasks;

  factory ScheduleDetailsModel.fromJson(Map<String, dynamic> json) {
    final projectJson = json['project'];
    final scheduleJson = json['schedule'];
    final summaryJson = json['summary'];
    final tasksJson = json['tasks'];

    return ScheduleDetailsModel(
      project: projectJson is Map<String, dynamic>
          ? ScheduleProjectModel.fromJson(projectJson)
          : projectJson is Map
              ? ScheduleProjectModel.fromJson(
                  projectJson.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : null,
      schedule: ScheduleItemModel.fromJson(
        scheduleJson is Map<String, dynamic>
            ? scheduleJson
            : scheduleJson is Map
                ? scheduleJson.map((key, value) => MapEntry(key.toString(), value))
                : const {},
      ),
      summary: ScheduleDetailsSummaryModel.fromJson(
        summaryJson is Map<String, dynamic>
            ? summaryJson
            : summaryJson is Map
                ? summaryJson.map((key, value) => MapEntry(key.toString(), value))
                : const {},
      ),
      tasks: (tasksJson as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (task) => ScheduleTaskModel.fromJson(
              task.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
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
      tasksCount: _parseInt(json['tasks_count']),
      completedTasksCount: _parseInt(json['completed_tasks_count']),
      inProgressTasksCount: _parseInt(json['in_progress_tasks_count']),
      overdueTasksCount: _parseInt(json['overdue_tasks_count']),
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
      id: _parseInt(json['id']),
      parentTaskId: json['parent_task_id'] as int?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      taskType: json['task_type'] as String? ?? '',
      taskTypeLabel: json['task_type_label'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      statusColor: json['status_color'] as String? ?? '#6B7280',
      progressPercent: _parseDouble(json['progress_percent']),
      isCritical: json['is_critical'] as bool? ?? false,
      level: _parseInt(json['level']),
      childrenCount: _parseInt(json['children_count']),
      plannedStartDate: json['planned_start_date'] as String?,
      plannedEndDate: json['planned_end_date'] as String?,
      plannedDurationDays: json['planned_duration_days'] as int?,
      actualStartDate: json['actual_start_date'] as String?,
      actualEndDate: json['actual_end_date'] as String?,
      quantity: json['quantity'] != null ? _parseDouble(json['quantity']) : null,
      completedQuantity: json['completed_quantity'] != null
          ? _parseDouble(json['completed_quantity'])
          : null,
      measurementUnit: json['measurement_unit'] as String?,
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}
