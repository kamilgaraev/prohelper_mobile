import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notification_navigation_target.dart';

void main() {
  test('maps notification module through AppModule registry', () {
    final notification = _notification(
      data: const <String, dynamic>{
        'module': 'site-requests',
        'site_request_id': 42,
      },
    );

    final target = NotificationNavigationTarget.fromNotification(notification);

    expect(target.module, AppModule.siteRequests);
    expect(target.type, NotificationTargetType.siteRequest);
    expect(target.siteRequestId, 42);
    expect(target.hasConcreteTarget, isTrue);
  });

  test('maps action params to construction journal entry target', () {
    final notification = _notification(
      data: const <String, dynamic>{
        'module': 'construction-journal',
        'actions': [
          {
            'label': 'Открыть',
            'params': {'journal_id': 7, 'journal_entry_id': 15},
          },
        ],
      },
    );

    final target = NotificationNavigationTarget.fromNotification(notification);

    expect(target.module, AppModule.constructionJournal);
    expect(target.type, NotificationTargetType.constructionJournalEntry);
    expect(target.journalId, 7);
    expect(target.journalEntryId, 15);
  });

  test('maps mobile push record payloads to their detail targets', () {
    final cases = <
      ({
        String type,
        int id,
        NotificationTargetType expectedType,
        AppModule expectedModule,
      })
    >[
      (
        type: 'schedule_task',
        id: 12,
        expectedType: NotificationTargetType.scheduleTask,
        expectedModule: AppModule.scheduleManagement,
      ),
      (
        type: 'quality_defect',
        id: 23,
        expectedType: NotificationTargetType.qualityDefect,
        expectedModule: AppModule.qualityControl,
      ),
      (
        type: 'payment_document',
        id: 34,
        expectedType: NotificationTargetType.paymentDocument,
        expectedModule: AppModule.payments,
      ),
      (
        type: 'act',
        id: 45,
        expectedType: NotificationTargetType.act,
        expectedModule: AppModule.actReporting,
      ),
      (
        type: 'purchase_request',
        id: 56,
        expectedType: NotificationTargetType.procurementPurchaseRequest,
        expectedModule: AppModule.procurement,
      ),
    ];

    for (final item in cases) {
      final target = NotificationNavigationTarget.fromNotification(
        _notification(
          data: <String, dynamic>{
            'target_type': item.type,
            'target_id': item.id,
            'route': item.type,
          },
        ),
      );

      expect(target.type, item.expectedType, reason: item.type);
      expect(target.module, item.expectedModule, reason: item.type);
      expect(target.hasConcreteTarget, isTrue, reason: item.type);
      expect(_recordId(target), item.id, reason: item.type);
    }
  });

  test('keeps known record type unavailable without a numeric target id', () {
    final target = NotificationNavigationTarget.fromNotification(
      _notification(
        data: const <String, dynamic>{'target_type': 'quality_defect'},
      ),
    );

    expect(target.type, NotificationTargetType.qualityDefect);
    expect(target.module, AppModule.qualityControl);
    expect(target.hasConcreteTarget, isFalse);
  });

  test('maps act report push payload to act detail', () {
    final target = NotificationNavigationTarget.fromNotification(
      _notification(
        data: const <String, dynamic>{
          'entity_type': 'act_report',
          'entity_id': 73,
        },
      ),
    );

    expect(target.type, NotificationTargetType.act);
    expect(target.actId, 73);
    expect(target.hasConcreteTarget, isTrue);
  });

  test('unknown linked resources stay unavailable', () {
    final notification = _notification(
      type: 'external_crm_event',
      category: 'external',
      data: const <String, dynamic>{'module': 'external-crm', 'entity_id': 99},
    );

    final target = NotificationNavigationTarget.fromNotification(notification);

    expect(target.module, isNull);
    expect(target.type, NotificationTargetType.unknown);
    expect(target.hasConcreteTarget, isFalse);
  });
}

int? _recordId(NotificationNavigationTarget target) {
  return switch (target.type) {
    NotificationTargetType.scheduleTask => target.scheduleTaskId,
    NotificationTargetType.qualityDefect => target.qualityDefectId,
    NotificationTargetType.paymentDocument => target.paymentDocumentId,
    NotificationTargetType.act => target.actId,
    NotificationTargetType.procurementPurchaseRequest =>
      target.purchaseRequestId,
    _ => null,
  };
}

NotificationModel _notification({
  String type = 'module_event',
  String category = 'general',
  required Map<String, dynamic> data,
}) {
  return NotificationModel(
    id: 'n1',
    type: type,
    notificationType: type,
    title: 'Уведомление',
    message: 'Проверьте событие',
    priority: 'normal',
    category: category,
    data: data,
    actions: notificationAsList(
      data['actions'],
    ).map(NotificationActionModel.fromJson).toList(growable: false),
    createdAt: DateTime(2026, 5, 22),
  );
}
