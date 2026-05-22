import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';

void main() {
  Map<String, dynamic> deliveryPayload() {
    return {
      'id': 10,
      'source_type': 'purchase_order',
      'status': 'in_transit',
      'status_label': 'В доставке',
      'status_color': 'info',
      'requested_quantity': 12,
      'reserved_quantity': 10,
      'shipped_quantity': 8,
      'accepted_quantity': 2,
      'used_quantity': 1,
      'available_quantity': 1,
      'remaining_to_ship': 4,
      'remaining_to_accept': 6,
      'can_receive': true,
      'project': {'id': 7, 'name': 'Дом 300м'},
      'material': {
        'id': 42,
        'name': 'Цемент М500',
        'measurement_unit': {'short_name': 'меш.'},
      },
      'warehouse': {'id': 3, 'name': 'Основной склад'},
      'linked_entities': {
        'site_request_id': 100,
        'purchase_request_id': 200,
        'purchase_order_id': 300,
      },
      'events': [
        {
          'id': 1,
          'event_type': 'status_changed',
          'quantity': 2,
          'user': {'name': 'Иван Петров'},
        },
      ],
    };
  }

  test('парсит поставку материала без локальных нулей по умолчанию', () {
    final delivery = ProjectMaterialDeliveryModel.fromJson(deliveryPayload());

    expect(delivery.id, 10);
    expect(delivery.statusLabel, 'В доставке');
    expect(delivery.projectName, 'Дом 300м');
    expect(delivery.materialName, 'Цемент М500');
    expect(delivery.remainingToAccept, 6);
    expect(delivery.events.single.userName, 'Иван Петров');
  });

  test('отклоняет поставку без обязательного количества', () {
    final payload = deliveryPayload()..remove('requested_quantity');

    expect(
      () => ProjectMaterialDeliveryModel.fromJson(payload),
      throwsFormatException,
    );
  });

  test('отклоняет поставку без проекта или материала', () {
    final withoutProject = deliveryPayload()..remove('project');
    final withoutMaterial = deliveryPayload()..remove('material');

    expect(
      () => ProjectMaterialDeliveryModel.fromJson(withoutProject),
      throwsFormatException,
    );
    expect(
      () => ProjectMaterialDeliveryModel.fromJson(withoutMaterial),
      throwsFormatException,
    );
  });

  test('отклоняет translation key вместо status_label', () {
    final payload =
        deliveryPayload()
          ..['status_label'] =
              'basic_warehouse.project_material_deliveries.statuses.in_transit';

    expect(
      () => ProjectMaterialDeliveryModel.fromJson(payload),
      throwsFormatException,
    );
  });

  test('требует summary и items в остатках материалов объекта', () {
    expect(
      () => ProjectMaterialStockModel.fromJson({'items': const []}),
      throwsFormatException,
    );
    expect(
      () => ProjectMaterialStockModel.fromJson({
        'summary': {
          'materials_count': 0,
          'deliveries_count': 0,
          'accepted_quantity': 0,
          'used_quantity': 0,
          'available_quantity': 0,
        },
      }),
      throwsFormatException,
    );
  });
}
