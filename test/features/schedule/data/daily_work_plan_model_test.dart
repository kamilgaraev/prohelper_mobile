import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';

void main() {
  test('parses daily work plan with assignment and constraints', () {
    final plan = DailyWorkPlanModel.fromJson({
      'id': 41,
      'project_id': 3,
      'schedule_id': 5,
      'schedule_name': 'Tower schedule',
      'lookahead_plan_id': 9,
      'work_date': '2026-06-08',
      'status': 'published',
      'status_label': 'Опубликован',
      'available_actions': [
        {'action': 'record_fact', 'label': 'Зафиксировать факт'},
        {'action': 'submit', 'label': 'На приемку'},
      ],
      'assignments': [
        {
          'id': 51,
          'daily_work_plan_id': 41,
          'lookahead_plan_task_id': 17,
          'schedule_task_id': 7,
          'journal_entry_id': null,
          'status': 'planned',
          'status_label': 'Запланировано',
          'planned_quantity': '10',
          'completed_quantity': null,
          'planned_work_hours': '8',
          'actual_work_hours': null,
          'fact_status_options': [
            {'status': 'done', 'label': 'Выполнено'},
            {'status': 'partially_done', 'label': 'Выполнено частично'},
            {'status': 'not_done', 'label': 'Не выполнено'},
          ],
          'schedule_task': {'id': 7, 'name': 'Foundation reinforcement'},
          'linked_blocking_entities': [],
          'constraints': [
            {
              'id': 61,
              'title': 'Rebar delivery',
              'severity': 'hard',
              'severity_label': 'Жесткое',
              'status': 'open',
              'status_label': 'Открыто',
              'due_date': '2026-06-07',
              'constraint_type': 'material_missing',
              'constraint_type_label': 'Не хватает материала',
              'available_actions': [
                {
                  'action': 'create_linked_action',
                  'label': 'Создать связанную задачу',
                },
              ],
              'linked_action': null,
            },
            {
              'id': 62,
              'title': 'Hot work permit missing',
              'severity': 'hard',
              'severity_label': 'Жесткое',
              'status': 'open',
              'status_label': 'Открыто',
              'due_date': '2026-06-07',
              'constraint_type': 'safety_permit_missing',
              'constraint_type_label': 'Нет допуска по охране труда',
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
    expect(plan.hasAction(ScheduleActionKeys.recordFact), isTrue);
    expect(plan.availableActions.first.label, 'Зафиксировать факт');
    expect(plan.assignments.single.plannedQuantity, 10);
    expect(plan.assignments.single.statusLabel, 'Запланировано');
    expect(plan.assignments.single.factStatusOptions.first.status, 'done');
    expect(
      plan.assignments.single.scheduleTaskName,
      'Foundation reinforcement',
    );
    expect(plan.assignments.single.constraints.first.severity, 'hard');
    expect(plan.assignments.single.constraints.first.severityLabel, 'Жесткое');
    expect(
      plan.assignments.single.constraints.first.constraintType,
      'material_missing',
    );
    expect(
      plan.assignments.single.constraints.first.hasAction(
        ScheduleActionKeys.createLinkedAction,
      ),
      isTrue,
    );
    expect(
      plan.assignments.single.constraints.last.constraintType,
      'safety_permit_missing',
    );
    expect(
      plan.assignments.single.constraints.last.linkedAction?.type,
      'safety_incident',
    );
    expect(plan.assignments.single.constraints.last.linkedAction?.id, 88);
  });

  test('rejects legacy scalar daily plan actions', () {
    expect(
      () => DailyWorkPlanModel.fromJson({
        'id': 41,
        'project_id': 3,
        'schedule_id': 5,
        'schedule_name': 'Tower schedule',
        'lookahead_plan_id': 9,
        'work_date': '2026-06-08',
        'status': 'published',
        'status_label': 'Опубликован',
        'available_actions': ['record_fact'],
        'assignments': [],
      }),
      throwsFormatException,
    );
  });

  test('rejects unreadable labels and missing task names', () {
    final payload = {
      'id': 41,
      'project_id': 3,
      'schedule_id': 5,
      'schedule_name': 'Tower schedule',
      'lookahead_plan_id': 9,
      'work_date': '2026-06-08',
      'status': 'published',
      'status_label': 'schedule_management.daily_plan_statuses.published',
      'available_actions': [
        {'action': 'record_fact', 'label': 'Зафиксировать факт'},
      ],
      'assignments': [
        {
          'id': 51,
          'daily_work_plan_id': 41,
          'lookahead_plan_task_id': 17,
          'schedule_task_id': 7,
          'status': 'planned',
          'status_label': 'Запланировано',
          'fact_status_options': [
            {'status': 'done', 'label': 'Выполнено'},
          ],
          'linked_blocking_entities': [],
          'constraints': [],
        },
      ],
    };

    expect(() => DailyWorkPlanModel.fromJson(payload), throwsFormatException);
  });
}
