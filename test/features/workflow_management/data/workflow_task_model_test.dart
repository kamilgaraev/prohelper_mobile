import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/workflow_management/data/workflow_task_model.dart';

void main() {
  test('parses workflow list contract with status history and actions', () {
    final result = WorkflowTaskListResult.fromJson({
      'items': [_workflowTaskJson()],
      'meta': {'current_page': 1, 'per_page': 20, 'total': 1, 'last_page': 1},
      'summary': {
        'by_status': {'pending': 1},
        'project_id': 9,
        'status': 'pending',
        'assigned_to_me': true,
        'search': 'бетон',
      },
    });

    final task = result.items.single;

    expect(task.id, 17);
    expect(task.title, 'Бетонирование');
    expect(task.status, 'pending');
    expect(task.canApprove, isTrue);
    expect(task.canRequestChanges, isTrue);
    expect(task.workflowSummary.nextAction, 'approve');
    expect(task.comments.single.comment, 'Проверить объем');
    expect(task.statusHistory.single.action, 'request_changes');
    expect(result.summary.byStatus['pending'], 1);
  });

  test('rejects malformed workflow status', () {
    final json = _workflowTaskJson()..['status'] = 'waiting';

    expect(() => WorkflowTaskModel.fromJson(json), throwsFormatException);
  });

  test('requires action arrays in backend contract', () {
    final json = _workflowTaskJson()..remove('available_actions');

    expect(() => WorkflowTaskModel.fromJson(json), throwsFormatException);
  });
}

Map<String, dynamic> _workflowTaskJson() {
  return {
    'id': 17,
    'organization_id': 4,
    'project_id': 9,
    'project_label': 'Башня',
    'work_type_id': 3,
    'work_type_label': 'Бетонирование',
    'contract_id': 6,
    'contract_label': 'Д-12',
    'contractor_id': 7,
    'contractor_label': 'Монолит Строй',
    'assigned_user_id': 8,
    'assigned_user_label': 'Иван Петров',
    'schedule_task_id': 11,
    'schedule_task_label': 'Заливка секции А',
    'schedule_label': 'Основной график',
    'estimate_item_id': 12,
    'estimate_item_label': 'Бетон М300',
    'work_origin_type': 'manual',
    'work_origin_label': 'Ручной ввод',
    'planning_status': 'planned',
    'planning_status_label': 'Запланировано',
    'quantity': 10,
    'completed_quantity': 9.5,
    'measurement_unit_label': 'м3',
    'price': 1000,
    'total_amount': 9500,
    'completion_date': '2026-05-22',
    'notes': 'Проверить опалубку',
    'status': 'pending',
    'status_label': 'Ожидает согласования',
    'comments': [
      {
        'id': 'comment-1',
        'action': 'comment',
        'from_status': 'pending',
        'to_status': 'pending',
        'comment': 'Проверить объем',
        'user_id': 8,
        'created_at': '2026-05-22T10:00:00Z',
      },
    ],
    'status_history': [
      {
        'id': 'history-1',
        'action': 'request_changes',
        'from_status': 'draft',
        'to_status': 'in_review',
        'comment': 'Уточнить',
        'user_id': 8,
        'created_at': '2026-05-22T09:00:00Z',
      },
    ],
    'available_actions': ['approve', 'reject', 'request_changes', 'comment'],
    'workflow_summary': {
      'stage': 'pending',
      'status': 'pending',
      'stage_label': 'Ожидает согласования',
      'next_action': 'approve',
      'next_action_label': 'Согласовать',
      'available_actions': ['approve', 'reject', 'request_changes', 'comment'],
      'blockers': [],
      'warnings': [],
    },
    'problem_flags': [],
    'linked_entities': {
      'project_id': 9,
      'contract_id': 6,
      'schedule_task_id': 11,
      'estimate_item_id': 12,
    },
    'created_at': '2026-05-22T08:00:00Z',
    'updated_at': '2026-05-22T10:00:00Z',
  };
}
