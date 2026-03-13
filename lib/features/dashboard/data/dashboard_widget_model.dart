enum DashboardWidgetType {
  projectOverview('project_overview'),
  siteRequests('site_requests'),
  siteRequestApprovals('site_request_approvals'),
  warehouse('warehouse'),
  schedule('schedule'),
  unknown('unknown');

  const DashboardWidgetType(this.value);

  final String value;

  static DashboardWidgetType fromValue(String? value) {
    for (final type in DashboardWidgetType.values) {
      if (type.value == value) {
        return type;
      }
    }

    return DashboardWidgetType.unknown;
  }
}

class DashboardWidgetModel {
  const DashboardWidgetModel({
    required this.type,
    required this.order,
    required this.title,
    required this.description,
    required this.payload,
    this.route,
    this.badge,
  });

  final DashboardWidgetType type;
  final int order;
  final String title;
  final String description;
  final String? route;
  final String? badge;
  final Map<String, dynamic> payload;

  factory DashboardWidgetModel.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];

    return DashboardWidgetModel(
      type: DashboardWidgetType.fromValue(json['type'] as String?),
      order: json['order'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      route: json['route'] as String?,
      badge: json['badge']?.toString(),
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
              ? rawPayload.map((key, value) => MapEntry(key.toString(), value))
              : const {},
    );
  }
}
