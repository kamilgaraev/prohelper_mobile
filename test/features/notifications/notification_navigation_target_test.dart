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
