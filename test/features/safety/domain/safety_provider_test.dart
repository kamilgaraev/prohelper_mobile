import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/safety/domain/safety_provider.dart';

void main() {
  group('SafetyState', () {
    test('copyWith can clear project filter', () {
      const state = SafetyState(projectFilter: 9);

      final updated = state.copyWith(projectFilter: null);

      expect(updated.projectFilter, isNull);
    });
  });
}
