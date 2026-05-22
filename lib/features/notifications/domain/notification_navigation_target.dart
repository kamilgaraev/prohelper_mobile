import '../../../core/providers/module_provider.dart';
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
    this.module,
    this.siteRequestId,
    this.journalId,
    this.journalEntryId,
    this.scheduleId,
    this.warehouseId,
    this.warehouseTaskId,
  });

  final NotificationTargetType type;
  final AppModule? module;
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
    final module = _resolveModule(notification, merged);
    final targetType = _resolveType(module);

    return switch (targetType) {
      NotificationTargetType.siteRequest => NotificationNavigationTarget(
        type: targetType,
        module: module,
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
          module: module,
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
        module: module,
        scheduleId: _firstInt(merged, const [
          'schedule_id',
          'work_schedule_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.warehouseTask => NotificationNavigationTarget(
        type: targetType,
        module: module,
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

NotificationTargetType _resolveType(AppModule? module) {
  return switch (module) {
    AppModule.siteRequests => NotificationTargetType.siteRequest,
    AppModule.constructionJournal =>
      NotificationTargetType.constructionJournalEntry,
    AppModule.scheduleManagement => NotificationTargetType.schedule,
    AppModule.basicWarehouse => NotificationTargetType.warehouseTask,
    _ => NotificationTargetType.unknown,
  };
}

AppModule? _resolveModule(
  NotificationModel notification,
  Map<String, dynamic> data,
) {
  final candidates = <String>[
    notificationAsNullableString(data['module']) ?? '',
    notificationAsNullableString(data['module_slug']) ?? '',
    notificationAsNullableString(data['target_module']) ?? '',
    notificationAsNullableString(data['route']) ?? '',
    notification.type,
    notification.notificationType ?? '',
    notification.category,
    notificationAsNullableString(data['target_type']) ?? '',
    notificationAsNullableString(data['entity_type']) ?? '',
    notificationAsNullableString(data['related_type']) ?? '',
  ];

  for (final candidate in candidates) {
    final module = _moduleFromText(candidate);
    if (module != null) {
      return module;
    }
  }

  return _moduleFromKeys(data);
}

AppModule? _moduleFromText(String raw) {
  final normalized = raw.trim().toLowerCase().replaceAll('_', '-');
  if (normalized.isEmpty) {
    return null;
  }

  final direct = AppModuleX.fromSlug(normalized);
  if (direct != null) {
    return direct;
  }

  for (final module in AppModule.values) {
    if (normalized.contains(module.backendSlug)) {
      return module;
    }
  }

  return switch (normalized) {
    String value
        when value.contains('site-request') || value.contains('request') =>
      AppModule.siteRequests,
    String value
        when value.contains('journal-entry') ||
            value.contains('construction-journal') =>
      AppModule.constructionJournal,
    String value when value.contains('schedule') =>
      AppModule.scheduleManagement,
    String value when value.contains('warehouse') => AppModule.basicWarehouse,
    _ => null,
  };
}

AppModule? _moduleFromKeys(Map<String, dynamic> data) {
  if (data.containsKey('site_request_id') || data.containsKey('request_id')) {
    return AppModule.siteRequests;
  }

  if (data.containsKey('journal_entry_id') ||
      data.containsKey('construction_journal_entry_id')) {
    return AppModule.constructionJournal;
  }

  if (data.containsKey('schedule_id')) {
    return AppModule.scheduleManagement;
  }

  if (data.containsKey('warehouse_task_id') ||
      data.containsKey('warehouse_id')) {
    return AppModule.basicWarehouse;
  }

  return null;
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
