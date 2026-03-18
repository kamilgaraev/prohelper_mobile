import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';

void main() {
  group('MobileModuleModel.fromJson', () {
    test('подставляет fallback-тексты для складского модуля', () {
      final module = MobileModuleModel.fromJson({
        'slug': 'basic-warehouse',
        'title': 'mobile_modules.modules.basic-warehouse.title',
        'description': 'mobile_modules.modules.basic-warehouse.description',
        'icon': 'warehouse',
        'supported_on_mobile': true,
        'order': 2,
      });

      expect(module.title, 'Склад');
      expect(
        module.description,
        'Остатки, движения и приемка материалов по организации.',
      );
    });

    test('сохраняет человекочитаемое описание без подмены', () {
      final module = MobileModuleModel.fromJson({
        'slug': 'schedule-management',
        'title': 'График работ',
        'description': 'Список графиков по объекту',
        'icon': 'calendar',
        'supported_on_mobile': true,
        'order': 3,
      });

      expect(module.title, 'График работ');
      expect(module.description, 'Список графиков по объекту');
    });
  });
}
