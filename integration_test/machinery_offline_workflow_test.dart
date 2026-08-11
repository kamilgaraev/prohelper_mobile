import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_action.dart';

void main() {
  testWidgets('offline retry reuses the original mutation identity', (
    tester,
  ) async {
    final original = FinishShiftAction(
      10,
      shiftId: 42,
      actualHours: 8,
      fuelConsumed: 12,
      meterEnd: 108,
      idempotencyKey: 'offline-shift-42',
    );
    final restored = FinishShiftAction(
      10,
      shiftId: 42,
      actualHours: 8,
      fuelConsumed: 12,
      meterEnd: 108,
      idempotencyKey: original.idempotencyKey,
    );

    expect(restored.idempotencyKey, original.idempotencyKey);
    expect(restored.endpoint, original.endpoint);
    expect(restored.payload, original.payload);
  });
}
