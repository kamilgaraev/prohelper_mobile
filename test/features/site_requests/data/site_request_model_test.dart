import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';

void main() {
  Map<String, dynamic> basePayload() {
    return {
      'id': 42,
      'title': 'Аренда лесов',
      'status': 'pending',
      'status_label': 'На согласовании',
      'priority': 'medium',
      'priority_label': 'Средний',
      'request_type': 'equipment_request',
      'request_type_label': 'Техника',
    };
  }

  test(
    'SiteRequestModel.fromJson подставляет русский label и парсит контекст заявки',
    () {
      final model = SiteRequestModel.fromJson({
        ...basePayload(),
        'equipment_type': 'scaffolding',
        'user': {'name': 'Иван Петров'},
        'assigned_user': {'name': 'Снабжение'},
        'group_context': {
          'title': 'Материалы на фундамент',
          'request_count': 2,
          'items': [
            {
              'id': 42,
              'title': 'Арматура',
              'status': 'pending',
              'status_label': 'На согласовании',
              'request_type': 'material_request',
              'request_type_label': 'Материалы',
              'is_current': true,
            },
          ],
        },
        'history': [
          {
            'id': 1,
            'action': 'status_changed',
            'action_label': 'Статус изменен',
            'new_status_label': 'На согласовании',
            'user': {'name': 'Иван Петров'},
          },
        ],
      });

      expect(model.equipmentTypeLabel, 'Строительные леса');
      expect(model.userName, 'Иван Петров');
      expect(model.assignedUserName, 'Снабжение');
      expect(model.groupRequestCount, 2);
      expect(model.groupItems, hasLength(1));
      expect(model.history, hasLength(1));
    },
  );

  test('парсит закупочный контур только из актуальных snake_case полей', () {
    final model = SiteRequestModel.fromJson({
      ...basePayload(),
      'purchase_requests': [
        {
          'id': 501,
          'request_number': 'PR-501',
          'status': 'approved',
          'status_label': 'Согласована',
        },
      ],
      'purchase_orders': [
        {
          'id': 601,
          'order_number': 'PO-601',
          'status': 'sent',
          'status_label': 'Отправлен',
        },
      ],
      'delivery_summary': {
        'status': 'accepted',
        'status_label': 'Принято',
        'accepted_quantity': 12,
      },
    });

    expect(model.purchaseRequests.single.number, 'PR-501');
    expect(model.purchaseOrders.single.number, 'PO-601');
    expect(model.deliverySummary?.status, 'accepted');
  });

  test('parses list payload group summary without detail group items', () {
    final model = SiteRequestModel.fromJson({
      ...basePayload(),
      'group': {
        'id': 7,
        'title': 'Batch materials',
        'status': 'pending',
        'status_label': 'Pending',
        'status_color': 'warning',
      },
    });

    expect(model.groupTitle, 'Batch materials');
    expect(model.groupStatus, 'pending');
    expect(model.groupStatusLabel, 'Pending');
    expect(model.groupRequestCount, 0);
    expect(model.groupItems, isEmpty);
  });

  test('отклоняет старые camelCase поля закупочного контура', () {
    expect(
      () => SiteRequestModel.fromJson({
        ...basePayload(),
        'purchaseRequests': [
          {'id': 501, 'request_number': 'PR-501', 'status': 'approved'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('отклоняет неполную заявку без обязательного статуса', () {
    final payload = basePayload()..remove('status');

    expect(() => SiteRequestModel.fromJson(payload), throwsFormatException);
  });

  test('отклоняет неизвестный тип техники без человекочитаемого названия', () {
    expect(
      () => SiteRequestModel.fromJson({
        ...basePayload(),
        'equipment_type': 'unknown_machine',
      }),
      throwsFormatException,
    );
  });

  test('принимает кастомный workflow-переход только с названием действия', () {
    final model = SiteRequestModel.fromJson({
      ...basePayload(),
      'available_transitions': [
        {'status': 'manager_review', 'name': 'Передать руководителю'},
      ],
    });

    expect(model.availableTransitions.single.status, 'manager_review');
    expect(model.availableTransitions.single.name, 'Передать руководителю');
  });
}
