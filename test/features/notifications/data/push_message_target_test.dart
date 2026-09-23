import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/notifications/data/push_message_target.dart';

void main() {
  test('reads notification tap destination from push data', () {
    final target = PushMessageTarget.fromData({
      'notification_id': 42,
      'target_type': 'site_request',
      'target_id': '91',
      'route': '/requests/91',
    });

    expect(target.notificationId, '42');
    expect(target.targetType, 'site_request');
    expect(target.targetId, '91');
    expect(target.route, '/requests/91');
  });

  test('keeps missing tap destination empty', () {
    final target = PushMessageTarget.fromData({'route': '  '});

    expect(target.notificationId, isNull);
    expect(target.route, isNull);
  });

  test('resolves known push targets to protected record destinations', () {
    final siteRequest =
        PushMessageTarget.fromData({
          'target_type': 'site_request',
          'target_id': '23',
        }).destination;
    final journalEntry =
        PushMessageTarget.fromData({
          'target_type': 'journal-entry',
          'target_id': 41,
        }).destination;
    final schedule =
        PushMessageTarget.fromData({
          'target_type': 'work_schedule',
          'target_id': '52',
        }).destination;
    final warehouseTask =
        PushMessageTarget.fromData({
          'target_type': 'warehouse_task',
          'target_id': '8',
          'warehouse_id': '3',
        }).destination;

    expect(siteRequest?.type, PushDestinationType.siteRequest);
    expect(siteRequest?.id, 23);
    expect(journalEntry?.type, PushDestinationType.journalEntry);
    expect(journalEntry?.id, 41);
    expect(schedule?.type, PushDestinationType.schedule);
    expect(schedule?.id, 52);
    expect(warehouseTask?.type, PushDestinationType.warehouseTask);
    expect(warehouseTask?.id, 8);
    expect(warehouseTask?.parentId, 3);
    expect(
      PushMessageTarget.fromData({
        'target_type': 'site_request',
        'target_id': '23',
        'organization_id': '5',
        'project_id': 14,
      }).organizationId,
      5,
    );
    expect(
      PushMessageTarget.fromData({
        'target_type': 'site_request',
        'target_id': '23',
        'project_id': 14,
      }).projectId,
      14,
    );
  });

  test('returns no direct destination for unknown or incomplete targets', () {
    final unknownTarget = PushMessageTarget.fromData({
      'target_type': 'unknown',
      'target_id': '23',
      'notification_id': '77',
    });
    expect(unknownTarget.destination, isNull);
    expect(unknownTarget.notificationId, '77');
    expect(
      PushMessageTarget.fromData({
        'target_type': 'warehouse_task',
        'target_id': '8',
      }).destination,
      isNull,
    );
  });
}
