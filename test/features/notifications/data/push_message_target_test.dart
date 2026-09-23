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
}
