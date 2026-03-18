import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';

void main() {
  test('SiteRequestModel.fromJson подставляет русский label и парсит контекст заявки', () {
    final model = SiteRequestModel.fromJson(const {
      'id': 42,
      'title': 'Аренда лесов',
      'status': 'pending',
      'priority': 'medium',
      'request_type': 'equipment_request',
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
  });
}
