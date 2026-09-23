class PushMessageTarget {
  const PushMessageTarget({
    this.notificationId,
    this.targetType,
    this.targetId,
    this.route,
  });

  final String? notificationId;
  final String? targetType;
  final String? targetId;
  final String? route;

  factory PushMessageTarget.fromData(Map<String, dynamic> data) {
    String? value(String key) {
      final raw = data[key]?.toString().trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    return PushMessageTarget(
      notificationId: value('notification_id'),
      targetType: value('target_type'),
      targetId: value('target_id'),
      route: value('route'),
    );
  }
}
