import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_action.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/machinery_operations_screen.dart';

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

  test('canonical server grants expose only their matching actions', () {
    expect(
      machineryOperationsDestinationsFor([
        'machinery-operations.shifts.create',
      ]),
      [MachineryOperationsDestination.shift],
    );
    expect(
      machineryOperationsDestinationsFor([
        'machinery-operations.downtime.manage',
      ]),
      [MachineryOperationsDestination.maintenance],
    );
    expect(
      machineryOperationsDestinationsFor([
        'machinery-operations.shifts.approve',
      ]),
      [MachineryOperationsDestination.shiftReview],
    );
  });

  test('view-only grant opens the fleet without exposing actions', () {
    for (final permission in [
      '*',
      'view',
      'machinery-operations.view',
      'machinery-operations.*',
    ]) {
      expect(machineryOperationsDestinationsFor([permission]), [
        MachineryOperationsDestination.fleet,
      ]);
    }
  });

  test('wildcard and view grants do not imply action permissions', () {
    expect(
      machineryOperationsDestinationsFor([
        '*',
        'view',
        'shift.create',
        'machinery-operations.shifts.approve-extra',
      ]),
      [MachineryOperationsDestination.fleet],
    );
  });

  test('view remains available alongside maintenance access', () {
    expect(
      machineryOperationsDestinationsFor([
        'machinery-operations.view',
        'machinery-operations.downtime.manage',
      ]),
      [
        MachineryOperationsDestination.fleet,
        MachineryOperationsDestination.maintenance,
      ],
    );
  });

  test('view and review share one screen destination', () {
    expect(
      machineryOperationsDestinationsFor([
        'machinery-operations.view',
        'machinery-operations.shifts.approve',
      ]),
      [MachineryOperationsDestination.fleetAndReview],
    );
  });

  test('noncanonical grants do not expose destinations', () {
    expect(
      machineryOperationsDestinationsFor([
        'shift.create',
        'machinery-operations.shifts.created',
        'other-module.view',
      ]),
      isEmpty,
    );
  });
}
