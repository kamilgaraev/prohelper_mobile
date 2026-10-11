import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/workflow_management/data/workflow_task_model.dart';

void main() {
  test(
    'prefers additive workflow fields while legacy response remains readable',
    () {
      final payload = _workflowTaskJson();
      final legacyHistory = Map<String, dynamic>.from(
        (payload['status_history'] as List).single as Map,
      )..['action'] = 'approve';
      payload['status_history'] = [legacyHistory];
      payload['workflow_actions'] = ['submit'];
      payload['workflow_status_history'] = [
        Map<String, dynamic>.from(legacyHistory)..['action'] = 'confirm',
        Map<String, dynamic>.from(legacyHistory)
          ..['id'] = 'submit-event'
          ..['action'] = 'submit',
      ];
      final current = WorkflowTaskModel.fromJson(payload);
      expect(current.canSubmit, isTrue);
      expect(current.canApprove, isFalse);
      expect(current.statusHistory.map((event) => event.action), [
        'confirm',
        'submit',
      ]);
      payload.remove('workflow_actions');
      payload.remove('workflow_status_history');
      final legacy = WorkflowTaskModel.fromJson(payload);
      expect(legacy.canSubmit, isFalse);
      expect(legacy.canApprove, isTrue);
      expect(legacy.statusHistory.single.action, 'approve');
    },
  );

  test(
    'explicit empty current workflow fields override legacy permissions and history',
    () {
      final payload =
          _workflowTaskJson()
            ..['workflow_actions'] = []
            ..['workflow_status_history'] = [];
      final task = WorkflowTaskModel.fromJson(payload);
      expect(task.availableActions, isEmpty);
      expect(task.statusHistory, isEmpty);
      expect(task.canApprove, isFalse);
    },
  );
  test(
    'accepts canonical admin confirm history without permitting confirm mutation',
    () {
      final payload = _workflowTaskJson();
      (payload['status_history'] as List).first['action'] = 'confirm';
      final task = WorkflowTaskModel.fromJson(payload);
      expect(task.statusHistory.single.action, 'confirm');
      expect(task.canApprove, isTrue);
      payload['available_actions'] = ['confirm'];
      expect(() => WorkflowTaskModel.fromJson(payload), throwsFormatException);
    },
  );

  test(
    'server submit capability and canonical history preserve the existing statuses',
    () {
      final payload =
          _workflowTaskJson()
            ..['available_actions'] = ['submit']
            ..['status'] = 'rejected'
            ..['status_label'] = 'Отклонено';
      (payload['status_history'] as List).first['action'] = 'submit';
      final summary = payload['workflow_summary'] as Map<String, dynamic>;
      summary['available_actions'] = ['submit'];
      summary['next_action'] = 'submit';
      final task = WorkflowTaskModel.fromJson(payload);
      expect(task.canSubmit, isTrue);
      expect(task.status, 'rejected');
      expect(task.statusHistory.single.action, 'submit');
      payload['work_origin_type'] = 'journal';
      expect(WorkflowTaskModel.fromJson(payload).canSubmit, isFalse);
    },
  );
  test('journal facts cannot expose ordinary approval actions', () {
    final task = WorkflowTaskModel.fromJson(
      _workflowTaskJson()..['work_origin_type'] = 'journal',
    );
    expect(task.isJournalWork, isTrue);
    expect(task.canApprove, isFalse);
    expect(task.canReject, isFalse);
    expect(task.canRequestChanges, isFalse);
  });
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

  test('prefers manual work name and keeps description optional', () {
    final json =
        _workflowTaskJson()
          ..['work_type_label'] = 'прочее'
          ..['work_name'] = 'QA: проверка кладки'
          ..['description'] = 'Ручная тестовая запись';

    final task = WorkflowTaskModel.fromJson(json);

    expect(task.title, 'QA: проверка кладки');
    expect(task.description, 'Ручная тестовая запись');

    json['work_name'] = '   ';
    json['description'] = null;

    final legacyTask = WorkflowTaskModel.fromJson(json);
    expect(legacyTask.title, 'прочее');
    expect(legacyTask.description, isNull);
  });

  test('uses review label fallback without changing the workflow status', () {
    final json =
        _workflowTaskJson()
          ..['status'] = 'in_review'
          ..remove('status_label')
          ..['available_actions'] = ['approve', 'reject', 'comment'];
    final summary = json['workflow_summary'] as Map<String, dynamic>;
    summary['status'] = 'in_review';
    summary['stage'] = 'in_review';
    summary['stage_label'] = 'На проверке';
    summary['available_actions'] = ['approve', 'reject', 'comment'];
    summary['next_action'] = 'approve';

    final task = WorkflowTaskModel.fromJson(json);

    expect(task.status, 'in_review');
    expect(task.statusLabel, 'На проверке');
    expect(task.statusHistory.single.action, 'request_changes');
    expect(task.statusHistory.single.toStatus, 'in_review');
    expect(task.canRequestChanges, isFalse);
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
