import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_property_presentation.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/bim_properties_panel.dart';

void main() {
  final dictionary = <String, dynamic>{
    'schema_version': 1,
    'locale': 'ru',
    'empty_value': 'Не указано в модели',
    'boolean_true': 'Да',
    'boolean_false': 'Нет',
    'labels': {
      'globalid': 'Глобальный идентификатор',
      'category': 'Категория',
      'name': 'Название',
      'properties': 'Свойства',
      'materials': 'Материалы',
      'teklacommon': 'Общие свойства Tekla',
      'class': 'Класс',
      'topelevation': 'Верхняя отметка',
      'bottomelevation': 'Нижняя отметка',
      'isexternal': 'Наружный элемент',
      'reference': 'Обозначение',
    },
    'categories': {'ifcbeam': 'Балка'},
    'material_values': {'steel': 'Сталь'},
    'values': {'new': 'Новый'},
    'value_fields': ['materials', 'isexternal'],
  };
  final payload = <String, dynamic>{
    'global_id': '1gl6sY0004b34tEJ0tCpKp',
    'category': 'IFCBEAM',
    'name': 'Steel Grade 345',
    'properties': {
      'materials': [
        {'name': 'Steel', 'Reference': 'NEW'},
      ],
      'Tekla Common': {
        'Class': 0,
        'Top elevation': '+13.913',
        'Bottom elevation': '+13.775',
        'IsExternal': false,
        'CustomProperty': 'Custom English',
        'Empty': [],
      },
    },
  };

  test(
    'offline translation uses the server dictionary and preserves source data',
    () {
      final display = bimLocalizedDisplay(payload, dictionary)!;
      final fields = {
        for (final field in display['fields']) field['label']: field['value'],
      };
      expect(fields['Категория'], 'Балка');
      expect(fields['Название'], 'Steel Grade 345');
      expect(fields['Глобальный идентификатор'], payload['global_id']);
      expect(fields['Свойства · Общие свойства Tekla · Класс'], '0');
      expect(
        fields['Свойства · Общие свойства Tekla · Верхняя отметка'],
        '+13.913',
      );
      expect(
        fields['Свойства · Общие свойства Tekla · Нижняя отметка'],
        '+13.775',
      );
      expect(
        fields['Свойства · Общие свойства Tekla · Наружный элемент'],
        'Нет',
      );
      expect(fields['Свойства · Материалы · 0 · Название'], 'Сталь');
      expect(fields['Свойства · Материалы · 0 · Обозначение'], 'NEW');
      expect(
        fields['Свойства · Общие свойства Tekla · CustomProperty'],
        'Custom English',
      );
      expect(
        fields['Свойства · Общие свойства Tekla · Empty'],
        'Не указано в модели',
      );
      expect(payload['category'], 'IFCBEAM');
      expect(payload.containsKey('display'), isFalse);
    },
  );

  test('old packages without a dictionary remain readable', () {
    expect(bimLocalizedDisplay(payload, {}), isNull);
    expect(
      bimLocalizedDisplay(payload, {'schema_version': 2, 'labels': {}}),
      isNull,
    );
  });

  test(
    'custom material names and arbitrary nested values remain unchanged',
    () {
      final display =
          bimLocalizedDisplay({
            'materials': [
              {'name': 'Steel®', 'CustomValue': 'NEW'},
              {'name': 'Steel-А', 'Description': 'steel'},
              {'name': 'Сталь Steel', 'CustomId': 'steel'},
            ],
          }, dictionary)!;
      expect(
        [for (final field in display['fields']) field['value']],
        ['Steel®', 'NEW', 'Steel-А', 'steel', 'Сталь Steel', 'steel'],
      );
    },
  );

  testWidgets('property panel renders server display fields without raw keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BimPropertiesPanel(
              properties: {
                ...payload,
                'display': bimLocalizedDisplay(payload, dictionary),
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Категория'), findsOneWidget);
    expect(find.text('Балка'), findsOneWidget);
    expect(
      find.text('Свойства · Общие свойства Tekla · Верхняя отметка'),
      findsOneWidget,
    );
    expect(find.text('+13.913'), findsOneWidget);
    expect(find.text('global_id'), findsNothing);
    expect(find.text('IFCBEAM'), findsNothing);
    expect(find.text('display'), findsNothing);
  });

  testWidgets(
    'legacy response stays readable and hides presentation metadata',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BimPropertiesPanel(
              properties: {'name': 'Прогон', 'category_label': 'Балка'},
            ),
          ),
        ),
      );
      expect(find.text('Прогон'), findsOneWidget);
      expect(find.text('category_label'), findsNothing);
    },
  );
}
