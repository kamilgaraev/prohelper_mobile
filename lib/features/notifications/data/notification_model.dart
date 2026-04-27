enum NotificationFilter {
  all,
  unread,
  read;

  String? get queryValue {
    return switch (this) {
      NotificationFilter.all => null,
      NotificationFilter.unread => 'unread',
      NotificationFilter.read => 'read',
    };
  }
}

class NotificationsPageResult {
  const NotificationsPageResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final List<NotificationModel> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.category,
    required this.data,
    required this.actions,
    required this.createdAt,
    this.notificationType,
    this.readAt,
  });

  final String id;
  final String type;
  final String? notificationType;
  final String title;
  final String message;
  final String priority;
  final String category;
  final Map<String, dynamic> data;
  final List<NotificationActionModel> actions;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  NotificationModel copyWith({
    String? id,
    String? type,
    String? notificationType,
    String? title,
    String? message,
    String? priority,
    String? category,
    Map<String, dynamic>? data,
    List<NotificationActionModel>? actions,
    DateTime? readAt,
    DateTime? createdAt,
    bool clearReadAt = false,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      notificationType: notificationType ?? this.notificationType,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      data: data ?? this.data,
      actions: actions ?? this.actions,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']);
    final actions = _asList(
      data['actions'],
    ).map(NotificationActionModel.fromJson).toList(growable: false);
    final rawTitle =
        _asNullableString(data['title']) ?? _asNullableString(json['title']);
    final rawMessage =
        _asNullableString(data['message']) ??
        _asNullableString(json['message']) ??
        _asNullableString(data['body']) ??
        _asNullableString(json['body']);
    final notificationType = _asNullableString(json['notification_type']);
    final type = _asString(
      json['type'],
      fallback: notificationType ?? 'notification',
    );
    final priority = _asString(
      json['priority'] ?? data['priority'],
      fallback: 'normal',
    );
    final category = _asString(
      json['category'] ?? data['category'] ?? notificationType,
      fallback: 'general',
    );

    return NotificationModel(
      id: _asString(json['id']),
      type: type,
      notificationType: notificationType,
      title: rawTitle ?? _fallbackTitle(category, type),
      message: rawMessage ?? 'Откройте уведомление, чтобы посмотреть детали.',
      priority: priority,
      category: category,
      data: data,
      actions: actions,
      readAt: _asDateTime(json['read_at']),
      createdAt: _asDateTime(json['created_at']),
    );
  }
}

class NotificationActionModel {
  const NotificationActionModel({
    required this.label,
    this.route,
    this.url,
    this.method,
    this.params = const <String, dynamic>{},
  });

  final String label;
  final String? route;
  final String? url;
  final String? method;
  final Map<String, dynamic> params;

  factory NotificationActionModel.fromJson(Map<String, dynamic> json) {
    return NotificationActionModel(
      label: _asString(json['label'], fallback: 'Открыть'),
      route: _asNullableString(json['route']),
      url: _asNullableString(json['url']),
      method: _asNullableString(json['method']),
      params: _asMap(json['params']),
    );
  }
}

Map<String, dynamic> notificationAsMap(dynamic value) => _asMap(value);

List<Map<String, dynamic>> notificationAsList(dynamic value) => _asList(value);

int notificationAsInt(dynamic value) => _asInt(value);

String? notificationAsNullableString(dynamic value) => _asNullableString(value);

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value.whereType<Map>().map(_asMap).toList(growable: false);
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String? _asNullableString(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

DateTime? _asDateTime(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : DateTime.tryParse(normalized);
}

String _fallbackTitle(String category, String type) {
  return switch (category.trim().toLowerCase()) {
    'warning' => 'Требуется внимание',
    'error' => 'Важное уведомление',
    'security' => 'Безопасность',
    'procurement' => 'Закупки',
    _ => type.contains('Notification') ? 'Уведомление' : 'Новое уведомление',
  };
}
