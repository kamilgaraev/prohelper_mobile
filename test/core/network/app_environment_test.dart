import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/app_environment.dart';

void main() {
  test('uses production mobile api by default', () {
    expect(
      AppEnvironment.apiBaseUrl,
      'https://api.prohelper.pro/api/v1/mobile',
    );
  });
}
