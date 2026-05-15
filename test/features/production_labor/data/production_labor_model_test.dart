import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_model.dart';

void main() {
  group('Production labor models', () {
    test('parses work order with lines and actions', () {
      final workOrder = LaborWorkOrderModel.fromJson({
        'id': 5,
        'project_id': 9,
        'order_number': 'PL-1',
        'title': 'Монтаж',
        'status': 'issued',
        'status_label': 'Выдан',
        'available_actions': ['start', 'submit'],
        'assignee_name': 'Бригада 1',
        'lines': [
          {
            'id': 7,
            'work_order_id': 5,
            'name': 'Стены',
            'unit': 'м2',
            'planned_quantity': '10.5',
            'accepted_quantity': 3,
            'remaining_quantity': 7.5,
            'requires_safety_permit': true,
          },
        ],
        'problem_flags': [
          {'code': 'underproduction', 'severity': 'warning', 'message': 'Ниже плана'},
        ],
      });

      expect(workOrder.canRecordFact, isTrue);
      expect(workOrder.lines.single.remainingQuantity, 7.5);
      expect(workOrder.lines.single.requiresSafetyPermit, isTrue);
      expect(workOrder.problemFlags.single.code, 'underproduction');
    });

    test('parses output and timesheet date aliases', () {
      final output = LaborOutputModel.fromJson({
        'id': 21,
        'work_order_id': 5,
        'work_order_line_id': 7,
        'output_date': '2026-06-01',
        'quantity': '2',
        'hours': '8',
        'status_label': 'Принята',
      });
      final timesheet = LaborTimesheetModel.fromJson({
        'id': 31,
        'work_order_id': 5,
        'work_date': '2026-06-01',
        'status_label': 'Отправлен',
        'total_hours': '8',
      });

      expect(output.workDate, '2026-06-01');
      expect(output.quantity, 2);
      expect(timesheet.shiftDate, '2026-06-01');
      expect(timesheet.totalHours, 8);
    });
  });
}
