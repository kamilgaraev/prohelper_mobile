import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_action.dart';

void main() {
  test('typed action keeps a stable idempotency key and server contract', () {
    final action = StartShiftAction(
      10,
      assignmentId: 20,
      projectId: 30,
      meterStart: 125.5,
      preShiftInspection: const <String, dynamic>{'result': 'serviceable'},
      idempotencyKey: 'stable-key',
    );

    expect(action.idempotencyKey, 'stable-key');
    expect(action.endpoint, '/machinery-operations/shift-reports');
    expect(action.payload['assignment_id'], 20);
    expect(action.payload['meter_start'], 125.5);
    expect(action.payload['pre_shift_inspection'], <String, dynamic>{
      'result': 'serviceable',
    });
  });
}
