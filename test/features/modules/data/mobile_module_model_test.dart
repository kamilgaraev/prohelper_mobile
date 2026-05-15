import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';

void main() {
  group('MobileModuleModel.fromJson', () {
    test('подставляет читаемые тексты для складского модуля', () {
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

    test('подставляет читаемые тексты для охраны труда', () {
      final module = MobileModuleModel.fromJson({
        'slug': 'safety-management',
        'title': 'mobile_modules.modules.safety-management.title',
        'description': 'mobile_modules.modules.safety-management.description',
        'icon': 'shield-check',
        'supported_on_mobile': true,
        'order': 43,
      });

      expect(module.title, 'Охрана труда');
      expect(
        module.description,
        'Наряды-допуски, происшествия и нарушения на объекте.',
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
    test('подставляет тексты для техники и нарядов', () {
      final machinery = MobileModuleModel.fromJson({
        'slug': 'machinery-operations',
        'title': 'mobile_modules.modules.machinery-operations.title',
        'description':
            'mobile_modules.modules.machinery-operations.description',
        'icon': 'machinery',
        'supported_on_mobile': true,
        'order': 44,
      });
      final labor = MobileModuleModel.fromJson({
        'slug': 'production-labor',
        'title': 'mobile_modules.modules.production-labor.title',
        'description': 'mobile_modules.modules.production-labor.description',
        'icon': 'engineer',
        'supported_on_mobile': true,
        'order': 45,
      });

      expect(machinery.title, 'Техника');
      expect(
        machinery.description,
        'Сменные рапорты, простои и ГСМ по технике на объекте.',
      );
      expect(labor.title, 'Наряды');
      expect(
        labor.description,
        'Наряды, табели и выработка бригад на объекте.',
      );
    });
  });
}
