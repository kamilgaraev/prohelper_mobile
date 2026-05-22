import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_scan_model.dart';

void main() {
  Map<String, dynamic> taskPayload() {
    return {
      'id': 5,
      'warehouse_id': 1,
      'task_number': 'WH-5',
      'title': 'Переместить цемент',
      'task_type': 'transfer',
      'task_type_label': 'Перемещение',
      'status': 'queued',
      'status_label': 'В очереди',
      'priority': 'high',
      'priority_label': 'Высокий',
      'metadata': {},
      'available_transitions': [
        {'status': 'in_progress', 'name': 'Взять в работу'},
        {'status': 'cancelled', 'name': 'Отменить'},
      ],
    };
  }

  test('WarehouseTaskModel.fromJson берет workflow-действия из API', () {
    final task = WarehouseTaskModel.fromJson(taskPayload());

    expect(task.taskTypeLabel, 'Перемещение');
    expect(task.statusLabel, 'В очереди');
    expect(task.priorityLabel, 'Высокий');
    expect(task.availableTransitions, hasLength(2));
    expect(task.availableTransitions.first.status, 'in_progress');
    expect(task.availableTransitions.first.name, 'Взять в работу');
  });

  test('отклоняет задачу без available_transitions', () {
    final payload = taskPayload()..remove('available_transitions');

    expect(() => WarehouseTaskModel.fromJson(payload), throwsFormatException);
  });

  test('отклоняет action label, пришедший translation key', () {
    final payload =
        taskPayload()
          ..['available_transitions'] = [
            {
              'status': 'in_progress',
              'name': 'basic_warehouse.task.actions.in_progress',
            },
          ];

    expect(() => WarehouseTaskModel.fromJson(payload), throwsFormatException);
  });

  test('WarehouseScanResultModel требует списки действий и задач', () {
    expect(
      () => WarehouseScanResultModel.fromJson({
        'resolved': false,
        'available_actions': const [],
      }),
      throwsFormatException,
    );
    expect(
      () => WarehouseScanResultModel.fromJson({
        'resolved': false,
        'related_tasks': const [],
      }),
      throwsFormatException,
    );
  });

  test('WarehouseEntityRefModel отклоняет объект без имени', () {
    expect(
      () => WarehouseEntityRefModel.fromJson({'id': 1}),
      throwsFormatException,
    );
  });
}
