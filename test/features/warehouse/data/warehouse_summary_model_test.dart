import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';

void main() {
  group('WarehouseMovementModel.fromJson', () {
    test('парсит человекочитаемый label движения из backend-контракта', () {
      final movement = WarehouseMovementModel.fromJson({
        'id': 1,
        'movement_type': 'write_off',
        'movement_type_label': 'Списание',
        'quantity': 5,
        'price': 1200,
        'warehouse_name': 'Основной склад',
        'material_name': 'Цемент',
        'photo_gallery': [],
      });

      expect(movement.movementType, 'write_off');
      expect(movement.movementTypeLabel, 'Списание');
    });

    test('подставляет русскую подпись вместо ключа перевода', () {
      final movement = WarehouseMovementModel.fromJson({
        'id': 1,
        'movement_type': 'write_off',
        'movement_type_label': 'mobile_warehouse.movement_types.write_off',
        'quantity': 5,
        'price': 1200,
        'warehouse_name': 'Основной склад',
        'material_name': 'Цемент',
        'photo_gallery': [],
      });

      expect(movement.movementTypeLabel, 'Списание');
    });

    test('сохраняет фото галереи движения', () {
      final movement = WarehouseMovementModel.fromJson({
        'id': 2,
        'movement_type': 'receipt',
        'movement_type_label': 'Приход',
        'quantity': 3,
        'price': 450,
        'warehouse_name': 'Основной склад',
        'material_name': 'Цемент',
        'photo_gallery': [
          {
            'id': 10,
            'url': 'https://example.com/photo-1.jpg',
            'original_name': 'photo-1.jpg',
          },
        ],
      });

      expect(movement.photoGallery, hasLength(1));
      expect(movement.photoGallery.first.id, 10);
      expect(
        movement.photoGallery.first.url,
        'https://example.com/photo-1.jpg',
      );
    });

    test('показывает движение при отсутствующих связанных именах', () {
      final movement = WarehouseMovementModel.fromJson({
        'id': 2,
        'movement_type': 'reserved_issue',
        'movement_type_label': 'mobile_warehouse.movement_types.reserved_issue',
        'quantity': 3,
        'price': 450,
        'warehouse_name': null,
        'photo_gallery': [],
      });

      expect(movement.movementTypeLabel, 'Выдача из резерва');
      expect(movement.warehouseName, isNull);
      expect(movement.materialName, isNull);
    });

    test('читает резервирование и снятие резерва', () {
      for (final (type, label) in [
        ('reservation', 'Резервирование'),
        ('unreservation', 'Снятие резерва'),
      ]) {
        final movement = WarehouseMovementModel.fromJson({
          'id': 3,
          'movement_type': type,
          'movement_type_label': 'mobile_warehouse.movement_types.$type',
          'quantity': 2,
          'price': 100,
          'photo_gallery': [],
        });

        expect(movement.movementTypeLabel, label);
      }
    });
  });

  group('WarehouseBalanceModel.fromJson', () {
    test('использует gallery остатка с приоритетом над фото позиции', () {
      final balance = WarehouseBalanceModel.fromJson({
        'warehouse_id': 1,
        'warehouse_name': 'Основной склад',
        'material_id': 7,
        'material_name': 'Цемент',
        'available_quantity': 15,
        'reserved_quantity': 2,
        'total_quantity': 17,
        'average_price': 320,
        'total_value': 4800,
        'is_low_stock': false,
        'photo_gallery': [
          {'id': 1, 'url': 'https://example.com/balance.jpg'},
        ],
        'asset_photo_gallery': [
          {'id': 2, 'url': 'https://example.com/asset.jpg'},
        ],
      });

      expect(balance.effectivePhotoGallery, hasLength(1));
      expect(balance.effectivePhotoGallery.first.id, 1);
    });
  });
}
