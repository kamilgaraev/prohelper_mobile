import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/app_environment.dart';

void main() {
  test('uses production mobile api by default', () {
    expect(
      AppEnvironment.apiBaseUrl,
      'https://api.1мост.рф/api/v1/mobile',
    );
  });
}
