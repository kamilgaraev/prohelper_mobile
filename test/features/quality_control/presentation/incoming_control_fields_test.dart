import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/quality_control/data/incoming_control_model.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/incoming_control_fields.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_photo_picker.dart';

void main() {
  testWidgets(
    'подтверждённая область паспорта из ответа сохраняется при пересмотре',
    (tester) async {
      final key = GlobalKey<IncomingControlFieldsState>();
      await tester.pumpWidget(
        _testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomingControlFields(
                key: key,
                quantity: 1,
                materialId: 1,
                projectId: 4,
                initial: const {
                  'serial_number': 'SERIAL-12',
                  'location_name': 'Склад',
                  'inspection_result': 'compliant',
                  'documents_result': 'compliant',
                  'quality_document_versions': [
                    {
                      'document_id': 5,
                      'version_id': 6,
                      'coverage': {
                        'organization_id': 2,
                        'project_id': 4,
                        'material_id': 1,
                        'batch_number': '',
                        'serial_number': 'SERIAL-12',
                        'confirmed_by': 9,
                        'confirmed_at': '2026-11-03T10:00:00Z',
                      },
                    },
                  ],
                },
                references: const IncomingControlReferences({
                  'policy': {'mandatory_documents': true},
                }),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.payload()['quality_document_versions'], [
        {
          'document_id': 5,
          'version_id': 6,
          'coverage_confirmed': true,
          'coverage_material_id': 1,
          'coverage_batch_number': 'SERIAL-12',
        },
      ]);
      await tester.ensureVisible(_field('Серийный номер оборудования'));
      await tester.enterText(
        _field('Серийный номер оборудования'),
        'OTHER-SERIAL',
      );
      expect(() => key.currentState!.payload(), throwsFormatException);
    },
  );

  testWidgets('фото осмотра не заменяет паспорт партии', (tester) async {
    final key = GlobalKey<IncomingControlFieldsState>();
    await tester.pumpWidget(
      _testApp(
        picker: _PhotoPicker(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: IncomingControlFields(
              key: key,
              quantity: 1,
              initial: const {
                'location_name': 'Склад',
                'inspection_result': 'compliant',
                'documents_result': 'compliant',
              },
              references: const IncomingControlReferences({
                'policy': {'mandatory_documents': true},
              }),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Фото осмотра'));
    await tester.tap(find.text('Фото осмотра'));
    await tester.pump();
    expect(key.currentState!.files.single.kind, 'inspection_photo');
    expect(
      () => key.currentState!.payload(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('паспорт'),
        ),
      ),
    );
  });

  testWidgets(
    'сохранение незавершённой проверки полностью переводит количество в ожидание',
    (tester) async {
      final key = GlobalKey<IncomingControlFieldsState>();
      await tester.pumpWidget(
        _testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomingControlFields(
                key: key,
                quantity: 10,
                initial: const {
                  'location_name': 'Склад',
                  'custodian_name': 'Иванов',
                  'inspection_result': 'compliant',
                  'documents_result': 'compliant',
                },
                references: const IncomingControlReferences({}),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.text('Завершить проверку и принять решение'),
      );
      await tester.tap(find.text('Завершить проверку и принять решение'));
      await tester.pump();
      final payload = key.currentState!.payload();
      expect(payload['complete'], false);
      expect(payload['accepted_quantity'], 0);
      expect(payload['rejected_quantity'], 0);
      expect(payload['pending_quantity'], 10);
    },
  );

  testWidgets(
    'ограниченный допуск сохраняет разрешённые виды работ и требует область применения',
    (tester) async {
      final key = GlobalKey<IncomingControlFieldsState>();
      await tester.pumpWidget(
        _testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomingControlFields(
                key: key,
                quantity: 1,
                initial: const {
                  'location_name': 'Склад',
                  'inspection_result': 'compliant',
                  'documents_result': 'compliant',
                  'restrictions': 'Только подготовительные работы',
                  'permitted_work_type_ids': [7],
                },
                references: const IncomingControlReferences({
                  'work_types': [
                    {'id': 7, 'name': 'Подготовительные работы'},
                  ],
                }),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.payload()['permitted_work_type_ids'], [7]);
      await tester.ensureVisible(find.text('Подготовительные работы'));
      await tester.tap(find.text('Подготовительные работы'));
      await tester.pump();
      expect(
        () => key.currentState!.payload(),
        throwsA(isA<FormatException>()),
      );
    },
  );
  testWidgets(
    'приёмщик выбирает точную версию паспорта и завершает обычную приёмку',
    (tester) async {
      final key = GlobalKey<IncomingControlFieldsState>();
      await tester.pumpWidget(
        _testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomingControlFields(
                key: key,
                quantity: 1000,
                materialId: 1,
                references: const IncomingControlReferences({
                  'policy': {
                    'enabled': true,
                    'mandatory_documents': true,
                    'require_batch_number': true,
                  },
                  'quality_documents': [
                    {
                      'document_id': 5,
                      'title': 'Паспорт',
                      'versions': [
                        {'version_id': 6, 'version_number': '1.0'},
                      ],
                    },
                  ],
                }),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(_field('Место приёмки'), 'Склад объекта');
      await tester.enterText(_field('Партия изготовителя'), 'Партия 12');
      await tester.ensureVisible(find.text('Паспорт · версия 1.0'));
      await tester.tap(find.text('Паспорт · версия 1.0'));
      await tester.pump();
      await tester.ensureVisible(
        find.text('Документ относится к этому материалу и партии'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Документ относится к этому материалу и партии'),
      );
      await tester.pump();
      for (final label in [
        'Сверка документов',
        'Осмотр, маркировка и комплектность',
      ]) {
        final select = find.ancestor(
          of: find.text(label),
          matching: find.byType(DropdownButtonFormField<String>),
        );
        await tester.ensureVisible(select);
        await tester.pumpAndSettle();
        await tester.tap(select);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Соответствует').last);
        await tester.pumpAndSettle();
      }
      final payload = key.currentState!.payload();
      expect(payload['accepted_quantity'], 1000);
      expect(payload['inspection_result'], 'compliant');
      expect(payload['testing_required'], false);
      expect(payload['complete'], true);
      expect(payload['quality_document_versions'], [
        {
          'document_id': 5,
          'version_id': 6,
          'coverage_confirmed': true,
          'coverage_material_id': 1,
          'coverage_batch_number': 'Партия 12',
        },
      ]);
      await tester.ensureVisible(_field('Партия изготовителя'));
      await tester.enterText(_field('Партия изготовителя'), 'Другая партия');
      expect(
        () => key.currentState!.payload(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Подтвердите'),
          ),
        ),
      );
    },
  );

  testWidgets(
    'без полномочий сохраняется ожидание решения, отдельный дефект не создаётся',
    (tester) async {
      final key = GlobalKey<IncomingControlFieldsState>();
      await tester.pumpWidget(
        _testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IncomingControlFields(
                key: key,
                quantity: 5,
                canComplete: false,
                initial: const {'accepted_quantity': 5, 'pending_quantity': 0},
                references: const IncomingControlReferences({
                  'policy': {'mandatory_documents': true},
                }),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(_field('Место приёмки'), 'Площадка');
      await tester.ensureVisible(_field('Замечания и основание решения'));
      await tester.enterText(
        _field('Замечания и основание решения'),
        'Нужна проверка уполномоченного',
      );
      await tester.ensureVisible(_field('Ответственный за хранение'));
      await tester.enterText(_field('Ответственный за хранение'), 'Иванов');
      final payload = key.currentState!.payload();
      expect(payload['accepted_quantity'], 0);
      expect(payload['pending_quantity'], 5);
      expect(payload['complete'], false);
      expect(find.text('Завершить проверку и принять решение'), findsNothing);
    },
  );

  testWidgets('сумма распределения проверяется до отправки', (tester) async {
    final key = GlobalKey<IncomingControlFieldsState>();
    await tester.pumpWidget(
      _testApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IncomingControlFields(
              key: key,
              quantity: 1000,
              references: const IncomingControlReferences({}),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(_field('Принято'));
    await tester.enterText(_field('Принято'), '900');
    expect(() => key.currentState!.payload(), throwsA(isA<FormatException>()));
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Widget _testApp({required Widget home, QualityPhotoPicker? picker}) =>
    ProviderScope(
      overrides: [
        if (picker != null)
          qualityPhotoPickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp(home: home),
    );

class _PhotoPicker extends QualityPhotoPicker {
  @override
  Future<String?> pickInitialPhoto() async => '/tmp/inspection.jpg';
}
