import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_custody_model.dart';

void main() {
  test('парсит остаток материала у ответственного', () {
    final balance = WarehouseCustodyBalanceModel.fromJson({
      'id': 55,
      'project_id': 10,
      'project': {'id': 10, 'name': 'Дом 300м'},
      'custody_warehouse_id': 50,
      'responsible_user_id': 7,
      'responsible_user': {'id': 7, 'name': 'Иван Прораб'},
      'material_id': 42,
      'material': {
        'id': 42,
        'name': 'Цемент М500',
        'measurement_unit': {'short_name': 'меш.'},
      },
      'available_quantity': 8.5,
      'last_movement_at': '2026-06-03T10:00:00+03:00',
    });

    expect(balance.projectId, 10);
    expect(balance.custodyWarehouseId, 50);
    expect(balance.responsibleUserId, 7);
    expect(balance.availableQuantity, 8.5);
    expect(balance.projectName, 'Дом 300м');
    expect(balance.materialName, 'Цемент М500');
    expect(balance.unit, 'меш.');
  });
}
