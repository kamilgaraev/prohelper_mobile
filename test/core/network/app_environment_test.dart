import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/app_environment.dart';

void main() {
  test('uses production mobile api by default', () {
    expect(
      AppEnvironment.apiBaseUrl,
      'https://api.xn--1-xtbgmf.xn--p1ai/api/v1/mobile',
    );
  });
}
