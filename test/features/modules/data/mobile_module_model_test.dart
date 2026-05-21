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

    test('подставляет тексты для качества и приемки', () {
      final quality = MobileModuleModel.fromJson({
        'slug': 'quality-control',
        'title': 'mobile_modules.modules.quality-control.title',
        'description': 'mobile_modules.modules.quality-control.description',
        'icon': 'quality',
        'route': 'quality-control',
        'supported_on_mobile': true,
        'order': 62,
      });
      final handover = MobileModuleModel.fromJson({
        'slug': 'handover-acceptance',
        'title': 'mobile_modules.modules.handover-acceptance.title',
        'description': 'mobile_modules.modules.handover-acceptance.description',
        'icon': 'handover',
        'route': 'handover-acceptance',
        'supported_on_mobile': true,
        'order': 72,
      });

      expect(quality.title, 'Контроль качества');
      expect(
        quality.description,
        'Замечания, дефекты и повторная проверка выполненных работ.',
      );
      expect(handover.title, 'Приемка зон');
      expect(
        handover.description,
        'Зоны, punch-list и передача готовых помещений заказчику.',
      );
    });

    test('разделяет журнал работ и сметный companion-контур', () {
      final journal = MobileModuleModel.fromJson({
        'slug': 'construction-journal',
        'title': 'mobile_modules.modules.construction-journal.title',
        'description':
            'mobile_modules.modules.construction-journal.description',
        'icon': 'journal',
        'route': 'construction_journal',
        'supported_on_mobile': true,
        'order': 58,
      });
      final budget = MobileModuleModel.fromJson({
        'slug': 'budget-estimates',
        'title': 'mobile_modules.modules.budget-estimates.title',
        'description': 'mobile_modules.modules.budget-estimates.description',
        'icon': 'calculate',
        'supported_on_mobile': false,
        'order': 60,
      });

      expect(journal.title, 'Журнал работ');
      expect(
        journal.description,
        'Ежедневные записи, объемы работ, согласование и экспорт КС-6 по объекту.',
      );
      expect(journal.supportedOnMobile, isTrue);
      expect(budget.title, 'Сметы и бюджет');
      expect(
        budget.description,
        'Сводка смет, лимитов бюджета, изменений и назначенных согласований.',
      );
      expect(budget.supportedOnMobile, isFalse);
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

    test('подставляет тексты для явки сотрудников', () {
      final workforce = MobileModuleModel.fromJson({
        'slug': 'workforce-management',
        'title': 'mobile_modules.modules.workforce-management.title',
        'description':
            'mobile_modules.modules.workforce-management.description',
        'icon': 'workforce',
        'route': 'workforce-management',
        'supported_on_mobile': true,
        'order': 70,
      });

      expect(workforce.title, 'Явка сотрудников');
      expect(
        workforce.description,
        'QR-подтверждение присутствия, табель и контроль сотрудников на объекте.',
      );
    });

    test('подставляет тексты для companion-модулей без мобильного экрана', () {
      final expectedTitles = {
        'procurement': 'Закупки',
        'contract-management': 'Договоры',
        'change-management': 'Изменения',
        'executive-documentation': 'Исполнительная документация',
        'project-management': 'Управление проектом',
        'catalog-management': 'Справочники',
        'brigades': 'Бригады',
        'video-monitoring': 'Видеонаблюдение',
      };

      for (final entry in expectedTitles.entries) {
        final module = MobileModuleModel.fromJson({
          'slug': entry.key,
          'title': 'mobile_modules.modules.${entry.key}.title',
          'description': 'mobile_modules.modules.${entry.key}.description',
          'icon': 'grid',
          'supported_on_mobile': false,
          'order': 100,
        });

        expect(module.title, entry.value);
        expect(module.description, isNotEmpty);
        expect(module.supportedOnMobile, isFalse);
      }
    });
  });
}
