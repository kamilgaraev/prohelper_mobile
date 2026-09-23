import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/acts/data/act_model.dart';

void main() {
  test('exposes field confirmation only from backend capability', () {
    final permitted = ActModel.fromJson({
      'id': 21,
      'capabilities': {'can_field_confirm': true},
    });
    final denied = ActModel.fromJson({
      'id': 22,
      'capabilities': {'can_field_confirm': false},
    });

    expect(permitted.canFieldConfirm, isTrue);
    expect(denied.canFieldConfirm, isFalse);
  });

  test(
    'does not treat legal signature state as field confirmation capability',
    () {
      final act = ActModel.fromJson({'id': 23, 'signature_status': 'pending'});
      expect(act.canFieldConfirm, isFalse);
    },
  );
}
