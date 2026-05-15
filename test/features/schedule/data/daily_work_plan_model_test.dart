import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';

void main() {
  test('parses daily work plan with assignment and constraints', () {
    final plan = DailyWorkPlanModel.fromJson({
      'id': 41,
      'project_id': 3,
      'schedule_id': 5,
      'schedule_name': 'Tower schedule',
      'work_date': '2026-06-08',
      'status': 'published',
      'status_label': 'Опубликован',
      'available_actions': ['record_fact', 'submit'],
      'assignments': [
        {
          'id': 51,
          'daily_work_plan_id': 41,
          'schedule_task_id': 7,
          'journal_entry_id': null,
          'status': 'planned',
          'planned_quantity': '10',
          'completed_quantity': null,
          'planned_work_hours': '8',
          'actual_work_hours': null,
          'schedule_task': {'id': 7, 'name': 'Foundation reinforcement'},
          'constraints': [
            {
              'id': 61,
              'title': 'Rebar delivery',
              'severity': 'hard',
              'status': 'open',
              'due_date': '2026-06-07',
              'constraint_type': 'material_missing',
              'available_actions': ['create_linked_action'],
              'linked_action': null,
            },
            {
              'id': 62,
              'title': 'Hot work permit missing',
              'severity': 'hard',
              'status': 'open',
              'due_date': '2026-06-07',
              'constraint_type': 'safety_permit_missing',
              'available_actions': [],
              'linked_action': {
                'type': 'safety_incident',
                'id': 88,
                'constraint_id': 62,
              },
            },
          ],
        },
      ],
    });

    expect(plan.id, 41);
    expect(plan.availableActions, contains('record_fact'));
    expect(plan.assignments.single.plannedQuantity, 10);
    expect(plan.assignments.single.scheduleTaskName, 'Foundation reinforcement');
    expect(plan.assignments.single.constraints.single.severity, 'hard');
    expect(plan.assignments.single.constraints.single.constraintType, 'material_missing');
    expect(
      plan.assignments.single.constraints.single.availableActions,
      contains('create_linked_action'),
    );
    expect(plan.assignments.single.constraints.last.constraintType, 'safety_permit_missing');
    expect(plan.assignments.single.constraints.last.linkedAction?.type, 'safety_incident');
    expect(plan.assignments.single.constraints.last.linkedAction?.id, 88);
  });
}
