import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/notifications/data/push_device_registration.dart';

void main() {
  test('serializes RuStore registration with backend contract fields', () {
    const registration = PushDeviceRegistration(
      installationId: 'install-1',
      platform: 'android',
      provider: 'rustore',
      token: 'push-token',
    );

    expect(registration.toJson(), {
      'installation_id': 'install-1',
      'platform': 'android',
      'provider': 'rustore',
      'token': 'push-token',
    });
  });
}
