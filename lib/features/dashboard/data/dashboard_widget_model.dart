enum DashboardWidgetStatus {
  ok('ok'),
  active('active'),
  attention('attention'),
  critical('critical');

  const DashboardWidgetStatus(this.value);

  final String value;

  static DashboardWidgetStatus fromValue(String value) {
    return switch (value) {
      'ok' => DashboardWidgetStatus.ok,
      'active' => DashboardWidgetStatus.active,
      'attention' => DashboardWidgetStatus.attention,
      'critical' => DashboardWidgetStatus.critical,
      _ => throw FormatException('Unknown dashboard status: $value'),
    };
  }
}

class DashboardMetric {
  const DashboardMetric({required this.label, required this.value});

  final String label;
  final Object value;

  String get displayValue {
    final metricValue = value;

    if (metricValue is int) {
      return metricValue.toString();
    }

    if (metricValue is num) {
      return metricValue % 1 == 0
          ? metricValue.toInt().toString()
          : metricValue.toString();
    }

    return metricValue.toString();
  }

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    final label = _requiredString(json, 'label');
    final value = json['value'];

    if (value == null) {
      throw const FormatException('Dashboard metric value is required');
    }

    return DashboardMetric(label: label, value: value);
  }
}

class DashboardWidgetModel {
  const DashboardWidgetModel({
    required this.slug,
    required this.title,
    required this.status,
    required this.primaryMetric,
    required this.secondaryMetric,
    required this.route,
    required this.updatedAt,
  });

  final String slug;
  final String title;
  final DashboardWidgetStatus status;
  final DashboardMetric primaryMetric;
  final DashboardMetric secondaryMetric;
  final String route;
  final DateTime updatedAt;

  factory DashboardWidgetModel.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetModel(
      slug: _requiredString(json, 'slug'),
      title: _requiredString(json, 'title'),
      status: DashboardWidgetStatus.fromValue(_requiredString(json, 'status')),
      primaryMetric: DashboardMetric.fromJson(
        _requiredMap(json, 'primary_metric'),
      ),
      secondaryMetric: DashboardMetric.fromJson(
        _requiredMap(json, 'secondary_metric'),
      ),
      route: _requiredString(json, 'route'),
      updatedAt: _requiredDateTime(json, 'updated_at'),
    );
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> source, String key) {
  final value = source[key];

  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  throw FormatException('Dashboard field $key must be an object');
}

String _requiredString(Map<String, dynamic> source, String key) {
  final value = source[key]?.toString().trim() ?? '';

  if (value.isEmpty) {
    throw FormatException('Dashboard field $key is required');
  }

  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> source, String key) {
  final rawValue = _requiredString(source, key);
  final value = DateTime.tryParse(rawValue);

  if (value == null) {
    throw FormatException('Dashboard field $key must be a valid date');
  }

  return value;
}
