import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/workflow_management/data/workflow_repository.dart';

void main() {
  test(
    'fetches workflow tasks through mobile route with explicit filters',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'message': null,
          'data': {
            'items': [_workflowTaskJson()],
            'meta': {
              'current_page': 1,
              'per_page': 20,
              'total': 1,
              'last_page': 1,
            },
            'summary': {
              'by_status': {'pending': 1},
              'project_id': 9,
              'status': 'pending',
              'assigned_to_me': true,
              'search': 'бетон',
            },
          },
        };
      });

      final repository = WorkflowRepository(dio);
      final result = await repository.fetchTasks(
        projectId: 9,
        status: 'pending',
        assignedToMe: true,
        search: ' бетон ',
      );

      expect(request.path, '/workflow-management/tasks');
      expect(request.queryParameters['project_id'], 9);
      expect(request.queryParameters['status'], 'pending');
      expect(request.queryParameters['assigned_to_me'], 1);
      expect(request.queryParameters['search'], 'бетон');
      expect(result.items.single.id, 17);
    },
  );

  test('posts reject action with trimmed reason', () async {
    late RequestOptions request;
    dynamic sentData;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      sentData = options.data;
      return {
        'success': true,
        'message': 'Отклонено',
        'data': _workflowTaskJson()..['status'] = 'rejected',
      };
    });

    final repository = WorkflowRepository(dio);
    final task = await repository.rejectTask(
      id: 17,
      reason: ' Нужно переделать ',
    );

    expect(request.method, 'POST');
    expect(request.path, '/workflow-management/tasks/17/reject');
    expect(sentData, {'reason': 'Нужно переделать'});
    expect(task.status, 'rejected');
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
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
    'comments': [],
    'status_history': [],
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
