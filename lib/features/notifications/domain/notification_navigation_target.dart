import '../data/notification_model.dart';

enum NotificationTargetType {
  siteRequest,
  constructionJournalEntry,
  schedule,
  warehouseTask,
  unknown,
}

class NotificationNavigationTarget {
  const NotificationNavigationTarget({
    required this.type,
    this.siteRequestId,
    this.journalId,
    this.journalEntryId,
    this.scheduleId,
    this.warehouseId,
    this.warehouseTaskId,
  });

  final NotificationTargetType type;
  final int? siteRequestId;
  final int? journalId;
  final int? journalEntryId;
  final int? scheduleId;
  final int? warehouseId;
  final int? warehouseTaskId;

  bool get hasConcreteTarget {
    return switch (type) {
      NotificationTargetType.siteRequest => siteRequestId != null,
      NotificationTargetType.constructionJournalEntry =>
        journalId != null && journalEntryId != null,
      NotificationTargetType.schedule => scheduleId != null,
      NotificationTargetType.warehouseTask => warehouseTaskId != null,
      NotificationTargetType.unknown => false,
    };
  }

  factory NotificationNavigationTarget.fromNotification(
    NotificationModel notification,
  ) {
    final data = notification.data;
    final actionParams =
        notification.actions.isEmpty
            ? const <String, dynamic>{}
            : notification.actions.first.params;
    final merged = <String, dynamic>{...data, ...actionParams};
    final targetType = _resolveType(notification, merged);

    return switch (targetType) {
      NotificationTargetType.siteRequest => NotificationNavigationTarget(
        type: targetType,
        siteRequestId: _firstInt(merged, const [
          'site_request_id',
          'request_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.constructionJournalEntry =>
        NotificationNavigationTarget(
          type: targetType,
          journalId: _firstInt(merged, const [
            'journal_id',
            'construction_journal_id',
          ]),
          journalEntryId: _firstInt(merged, const [
            'journal_entry_id',
            'construction_journal_entry_id',
            'entry_id',
            'entity_id',
          ]),
        ),
      NotificationTargetType.schedule => NotificationNavigationTarget(
        type: targetType,
        scheduleId: _firstInt(merged, const [
          'schedule_id',
          'work_schedule_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.warehouseTask => NotificationNavigationTarget(
        type: targetType,
        warehouseId: _firstInt(merged, const ['warehouse_id']),
        warehouseTaskId: _firstInt(merged, const [
          'warehouse_task_id',
          'task_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.unknown => const NotificationNavigationTarget(
        type: NotificationTargetType.unknown,
      ),
    };
  }
}

NotificationTargetType _resolveType(
  NotificationModel notification,
  Map<String, dynamic> data,
) {
  final rawValues =
      <String>[
        notification.type,
        notification.notificationType ?? '',
        notification.category,
        notificationAsNullableString(data['target_type']) ?? '',
        notificationAsNullableString(data['entity_type']) ?? '',
        notificationAsNullableString(data['related_type']) ?? '',
        notificationAsNullableString(data['module']) ?? '',
        notificationAsNullableString(data['route']) ?? '',
      ].join(' ').toLowerCase();

  if (rawValues.contains('site_request') ||
      rawValues.contains('site-requests') ||
      data.containsKey('site_request_id') ||
      data.containsKey('request_id')) {
    return NotificationTargetType.siteRequest;
  }

  if (rawValues.contains('construction_journal_entry') ||
      rawValues.contains('journal_entry') ||
      rawValues.contains('journal-entry') ||
      data.containsKey('journal_entry_id') ||
      data.containsKey('construction_journal_entry_id')) {
    return NotificationTargetType.constructionJournalEntry;
  }

  if (rawValues.contains('schedule') ||
      rawValues.contains('work_schedule') ||
      data.containsKey('schedule_id')) {
    return NotificationTargetType.schedule;
  }

  if (rawValues.contains('warehouse_task') ||
      rawValues.contains('warehouse-task') ||
      rawValues.contains('warehouse') ||
      data.containsKey('warehouse_task_id')) {
    return NotificationTargetType.warehouseTask;
  }

  return NotificationTargetType.unknown;
}

int? _firstInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (!data.containsKey(key)) {
      continue;
    }

    final value = notificationAsInt(data[key]);
    if (value > 0) {
      return value;
    }
  }

  return null;
}
