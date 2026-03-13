class ScheduleSummaryModel {
  const ScheduleSummaryModel({
    required this.summary,
    required this.events,
  });

  final ScheduleSummaryData summary;
  final List<ScheduleEventModel> events;

  factory ScheduleSummaryModel.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'];
    final eventsJson = json['events'];

    return ScheduleSummaryModel(
      summary: ScheduleSummaryData.fromJson(
        summaryJson is Map<String, dynamic>
            ? summaryJson
            : summaryJson is Map
                ? summaryJson.map((key, value) => MapEntry(key.toString(), value))
                : const {},
      ),
      events: (eventsJson as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (event) => ScheduleEventModel.fromJson(
              event.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
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
      todayCount: json['today_count'] as int? ?? 0,
      upcomingCount: json['upcoming_count'] as int? ?? 0,
      blockingCount: json['blocking_count'] as int? ?? 0,
      inProgressCount: json['in_progress_count'] as int? ?? 0,
      projectId: json['project_id'] as int?,
      projectName: json['project_name'] as String?,
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
    this.description,
    this.projectId,
    this.projectName,
    this.eventDate,
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
  final DateTime? eventDate;
  final String? eventTime;
  final String? location;

  factory ScheduleEventModel.fromJson(Map<String, dynamic> json) {
    return ScheduleEventModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      eventTypeLabel: json['event_type_label'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      priorityLabel: json['priority_label'] as String? ?? '',
      isBlocking: json['is_blocking'] as bool? ?? false,
      isAllDay: json['is_all_day'] as bool? ?? false,
      description: json['description'] as String?,
      projectId: json['project_id'] as int?,
      projectName: json['project_name'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'].toString())
          : null,
      eventTime: json['event_time'] as String?,
      location: json['location'] as String?,
    );
  }
}
