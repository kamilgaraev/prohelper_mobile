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
      postShiftInspection: const <String, dynamic>{'result': 'serviceable'},
      idempotencyKey: 'offline-shift-42',
    );
    final restored = FinishShiftAction(
      10,
      shiftId: 42,
      actualHours: 8,
      fuelConsumed: 12,
      meterEnd: 108,
      postShiftInspection: const <String, dynamic>{'result': 'serviceable'},
      idempotencyKey: original.idempotencyKey,
    );

    expect(restored.idempotencyKey, original.idempotencyKey);
    expect(restored.endpoint, original.endpoint);
    expect(restored.payload, original.payload);
  });

  testWidgets('fuel command carries the canonical shift and warehouse links', (
    tester,
  ) async {
    final action = RecordFuelAction(
      10,
      shiftId: 42,
      projectId: 7,
      warehouseId: 3,
      materialId: 9,
      fuelType: 'diesel',
      quantity: 50,
      unit: 'l',
      issuedAt: DateTime.utc(2026, 8, 23, 7),
      idempotencyKey: 'fuel-shift-42',
    );

    expect(action.payload['shift_report_id'], 42);
    expect(action.payload['warehouse_id'], 3);
    expect(action.payload['material_id'], 9);
    expect(action.idempotencyKey, 'fuel-shift-42');
  });
}
