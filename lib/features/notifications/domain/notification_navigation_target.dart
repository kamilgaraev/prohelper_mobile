import '../../../core/providers/module_provider.dart';
import '../data/notification_model.dart';

enum NotificationTargetType {
  siteRequest,
  constructionJournalEntry,
  schedule,
  scheduleTask,
  qualityDefect,
  paymentDocument,
  act,
  procurementPurchaseRequest,
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
    this.scheduleTaskId,
    this.qualityDefectId,
    this.paymentDocumentId,
    this.actId,
    this.purchaseRequestId,
    this.warehouseId,
    this.warehouseTaskId,
  });

  final NotificationTargetType type;
  final AppModule? module;
  final int? siteRequestId;
  final int? journalId;
  final int? journalEntryId;
  final int? scheduleId;
  final int? scheduleTaskId;
  final int? qualityDefectId;
  final int? paymentDocumentId;
  final int? actId;
  final int? purchaseRequestId;
  final int? warehouseId;
  final int? warehouseTaskId;

  bool get hasConcreteTarget {
    return switch (type) {
      NotificationTargetType.siteRequest => siteRequestId != null,
      NotificationTargetType.constructionJournalEntry =>
        journalId != null && journalEntryId != null,
      NotificationTargetType.schedule => scheduleId != null,
      NotificationTargetType.scheduleTask => scheduleTaskId != null,
      NotificationTargetType.qualityDefect => qualityDefectId != null,
      NotificationTargetType.paymentDocument => paymentDocumentId != null,
      NotificationTargetType.act => actId != null,
      NotificationTargetType.procurementPurchaseRequest =>
        purchaseRequestId != null,
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
    final explicitType = _resolveRecordType(merged);
    final targetType = explicitType ?? _resolveType(module);
    final resolvedModule = _moduleForType(explicitType) ?? module;

    return switch (targetType) {
      NotificationTargetType.siteRequest => NotificationNavigationTarget(
        type: targetType,
        module: resolvedModule,
        siteRequestId: _firstInt(merged, const [
          'site_request_id',
          'request_id',
          'entity_id',
          'target_id',
          'id',
        ]),
      ),
      NotificationTargetType.constructionJournalEntry =>
        NotificationNavigationTarget(
          type: targetType,
          module: resolvedModule,
          journalId: _firstInt(merged, const [
            'journal_id',
            'construction_journal_id',
          ]),
          journalEntryId: _firstInt(merged, const [
            'journal_entry_id',
            'construction_journal_entry_id',
            'entry_id',
            'entity_id',
            'target_id',
          ]),
        ),
      NotificationTargetType.schedule => NotificationNavigationTarget(
        type: targetType,
        module: resolvedModule,
        scheduleId: _firstInt(merged, const [
          'schedule_id',
          'work_schedule_id',
          'entity_id',
          'target_id',
          'id',
        ]),
      ),
      NotificationTargetType.scheduleTask => NotificationNavigationTarget(
        type: targetType,
        module: resolvedModule,
        scheduleTaskId: _firstInt(merged, const [
          'schedule_task_id',
          'task_id',
          'target_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.qualityDefect => NotificationNavigationTarget(
        type: targetType,
        module: resolvedModule,
        qualityDefectId: _firstInt(merged, const [
          'quality_defect_id',
          'defect_id',
          'issue_id',
          'target_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.paymentDocument => NotificationNavigationTarget(
        type: targetType,
        module: resolvedModule,
        paymentDocumentId: _firstInt(merged, const [
          'payment_document_id',
          'document_id',
          'payment_id',
          'target_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.act => NotificationNavigationTarget(
        type: targetType,
        module: resolvedModule,
        actId: _firstInt(merged, const [
          'act_id',
          'target_id',
          'entity_id',
          'id',
        ]),
      ),
      NotificationTargetType.procurementPurchaseRequest =>
        NotificationNavigationTarget(
          type: targetType,
          module: resolvedModule,
          purchaseRequestId: _firstInt(merged, const [
            'purchase_request_id',
            'target_id',
            'entity_id',
            'id',
          ]),
        ),
      NotificationTargetType.warehouseTask => NotificationNavigationTarget(
        type: targetType,
        module: resolvedModule,
        warehouseId: _firstInt(merged, const ['warehouse_id']),
        warehouseTaskId: _firstInt(merged, const [
          'warehouse_task_id',
          'task_id',
          'target_id',
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

NotificationTargetType? _resolveRecordType(Map<String, dynamic> data) {
  final raw =
      notificationAsNullableString(data['target_type']) ??
      notificationAsNullableString(data['entity_type']) ??
      notificationAsNullableString(data['related_type']) ??
      notificationAsNullableString(data['route']);
  final value = raw?.trim().toLowerCase().replaceAll('_', '-');
  if (value == null || value.isEmpty) {
    return null;
  }

  return switch (value) {
    'schedule-task' ||
    'schedule-management.task' => NotificationTargetType.scheduleTask,
    'quality-defect' ||
    'quality-control.defect' => NotificationTargetType.qualityDefect,
    'payment-document' ||
    'payments.document' => NotificationTargetType.paymentDocument,
    'act' ||
    'act-report' ||
    'handover-acceptance.act' ||
    'act-reporting.act' => NotificationTargetType.act,
    'purchase-request' || 'procurement.purchase-request' =>
      NotificationTargetType.procurementPurchaseRequest,
    _ => null,
  };
}

AppModule? _moduleForType(NotificationTargetType? type) {
  return switch (type) {
    NotificationTargetType.scheduleTask => AppModule.scheduleManagement,
    NotificationTargetType.qualityDefect => AppModule.qualityControl,
    NotificationTargetType.paymentDocument => AppModule.payments,
    NotificationTargetType.act => AppModule.actReporting,
    NotificationTargetType.procurementPurchaseRequest => AppModule.procurement,
    _ => null,
  };
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
    notification.type,
    notification.notificationType ?? '',
    notification.category,
    notificationAsNullableString(data['target_type']) ?? '',
    notificationAsNullableString(data['entity_type']) ?? '',
    notificationAsNullableString(data['related_type']) ?? '',
    notificationAsNullableString(data['route']) ?? '',
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
    String value when value.contains('site-request') || value == 'request' =>
      AppModule.siteRequests,
    String value
        when value.contains('journal-entry') ||
            value.contains('construction-journal') =>
      AppModule.constructionJournal,
    String value when value.contains('schedule') =>
      AppModule.scheduleManagement,
    String value when value.contains('warehouse') => AppModule.basicWarehouse,
    String value when value.contains('quality-defect') =>
      AppModule.qualityControl,
    String value when value.contains('payment-document') => AppModule.payments,
    String value when value.contains('purchase-request') =>
      AppModule.procurement,
    String value when value.contains('act') => AppModule.handoverAcceptance,
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

  if (data.containsKey('schedule_task_id') || data.containsKey('task_id')) {
    return AppModule.scheduleManagement;
  }

  if (data.containsKey('schedule_id')) {
    return AppModule.scheduleManagement;
  }

  if (data.containsKey('quality_defect_id') || data.containsKey('defect_id')) {
    return AppModule.qualityControl;
  }

  if (data.containsKey('payment_document_id') ||
      data.containsKey('document_id')) {
    return AppModule.payments;
  }

  if (data.containsKey('act_id')) {
    return AppModule.handoverAcceptance;
  }

  if (data.containsKey('purchase_request_id')) {
    return AppModule.procurement;
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
