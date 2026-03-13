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
    final type = DashboardWidgetType.fromValue(json['type'] as String?);
    final rawPayload = json['payload'];
    final payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : rawPayload is Map
            ? rawPayload.map((key, value) => MapEntry(key.toString(), value))
            : const <String, dynamic>{};

    return DashboardWidgetModel(
      type: type,
      order: json['order'] as int? ?? 0,
      title: _resolveDashboardTitle(type, json['title'] as String?),
      description: _resolveDashboardDescription(
        type,
        json['description'] as String?,
        payload,
      ),
      route: json['route'] as String?,
      badge: json['badge']?.toString(),
      payload: payload,
    );
  }
}

String _resolveDashboardTitle(DashboardWidgetType type, String? rawTitle) {
  if (!_needsDashboardFallback(rawTitle)) {
    return rawTitle!.trim();
  }

  return switch (type) {
    DashboardWidgetType.projectOverview => 'Обзор объекта',
    DashboardWidgetType.siteRequests => 'Заявки с объекта',
    DashboardWidgetType.siteRequestApprovals => 'Согласования',
    DashboardWidgetType.warehouse => 'Склад',
    DashboardWidgetType.schedule => 'График работ',
    DashboardWidgetType.unknown => 'Виджет',
  };
}

String _resolveDashboardDescription(
  DashboardWidgetType type,
  String? rawDescription,
  Map<String, dynamic> payload,
) {
  if (!_needsDashboardFallback(rawDescription)) {
    return rawDescription!.trim();
  }

  return switch (type) {
    DashboardWidgetType.projectOverview => 'Текущий объект и ваша роль на нем.',
    DashboardWidgetType.siteRequests =>
      'Активных заявок: ${_intValue(payload['active_count'])}. Просрочено: ${_intValue(payload['overdue_count'])}.',
    DashboardWidgetType.siteRequestApprovals =>
      'Ожидают решения: ${_intValue(payload['pending_count'])}. На рассмотрении: ${_intValue(payload['in_review_count'])}.',
    DashboardWidgetType.warehouse =>
      'Складов: ${_nestedIntValue(payload, 'summary', 'warehouse_count')}. Низкий остаток: ${_nestedIntValue(payload, 'summary', 'low_stock_count')}.',
    DashboardWidgetType.schedule =>
      'Событий на 7 дней: ${_nestedIntValue(payload, 'summary', 'upcoming_count')}. Блокирующих: ${_nestedIntValue(payload, 'summary', 'blocking_count')}.',
    DashboardWidgetType.unknown => '',
  };
}

bool _needsDashboardFallback(String? value) {
  final normalized = value?.trim() ?? '';

  return normalized.isEmpty ||
      normalized.startsWith('mobile_dashboard.widgets.');
}

int _nestedIntValue(
  Map<String, dynamic> source,
  String firstKey,
  String secondKey,
) {
  final nested = source[firstKey];

  if (nested is! Map) {
    return 0;
  }

  return _intValue(nested[secondKey]);
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
