import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_draft.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/journal_entry_form_screen.dart';

void main() {
  testWidgets(
    'notes edit preserves saved resource ids counts and explicitly absent hours',
    (tester) async {
      Map<String, dynamic>? payload;
      const entry = ConstructionJournalEntryModel(
        id: 42,
        journalId: 7,
        entryDate: '2026-10-10',
        entryNumber: 1,
        workDescription: 'Монтаж',
        status: 'draft',
        statusLabel: 'Черновик',
        workflowState: 'ready',
        workVolumes: [],
        workers: [
          ConstructionJournalWorkerModel(
            id: 91,
            estimateItemId: 81,
            specialty: 'Монтажник',
            workersCount: 3,
          ),
        ],
        equipment: [
          ConstructionJournalEquipmentModel(
            id: 92,
            estimateItemId: 82,
            name: 'Кран',
            quantity: 2,
          ),
        ],
        materials: [
          ConstructionJournalMaterialUsageModel(
            id: 93,
            materialId: 11,
            estimateItemId: 83,
            projectMaterialDeliveryId: 54,
            custodyWarehouseId: 50,
            materialName: 'Арматура',
            quantity: 8,
            measurementUnit: 'кг',
            notes: 'Со склада ответственного',
          ),
        ],
        blockers: [],
        availableActions: [
          ConstructionJournalActionModel(
            action: 'update',
            label: 'Редактировать',
          ),
        ],
      );
      await _pumpJournalForm(
        tester,
        width: 360,
        textScale: 1,
        initialEntry: entry,
        onEntryCreate: (value) => payload = value,
      );
      final notes = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Замечания по качеству',
      );
      await tester.scrollUntilVisible(
        notes,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(notes, 'Проверено на участке А');
      await tester.scrollUntilVisible(
        find.text('Сохранить черновик'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      expect(payload!['quality_notes'], 'Проверено на участке А');
      final worker = (payload!['workers'] as List).single as Map;
      final machine = (payload!['equipment'] as List).single as Map;
      expect(worker['id'], 91);
      expect(worker['workers_count'], 3);
      expect(worker['estimate_item_id'], 81);
      expect(worker.containsKey('hours_worked'), isTrue);
      expect(worker['hours_worked'], isNull);
      expect(machine['id'], 92);
      expect(machine['quantity'], 2);
      expect(machine['estimate_item_id'], 82);
      expect(machine.containsKey('hours_used'), isTrue);
      expect(machine['hours_used'], isNull);
      final material = (payload!['materials'] as List).single as Map;
      expect(material['id'], 93);
      expect(material['material_id'], 11);
      expect(material['estimate_item_id'], 83);
      expect(material['project_material_delivery_id'], 54);
      expect(material['custody_warehouse_id'], 50);
      expect(material['quantity'], 8);
      expect(material['notes'], 'Со склада ответственного');
      expect(tester.takeException(), isNull);
    },
  );

  for (final manualOverride in [false, true, null]) {
    testWidgets(
      'resource hours use per-person and per-machine values; manual override=$manualOverride',
      (tester) async {
        Map<String, dynamic>? payload;
        await _pumpJournalForm(
          tester,
          width: 360,
          textScale: 1,
          includeLongEstimateOptions: true,
          includeResources: true,
          onEntryCreate: (value) => payload = value,
        );
        await tester.tap(find.text('Дата записи'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Описание работ',
          ),
          'Монтаж',
        );
        await tester.tap(find.text('Смета'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('СМ-2026-0003 - Журнал производства работ').last,
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Позиция сметы'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Позиция сметы'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.textContaining(
            'Устройство монолитной железобетонной фундаментной плиты',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Добавить из сметы'));
        await tester.pumpAndSettle();
        final actualQuantity =
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is TextField &&
                      widget.decoration?.labelText == 'Количество',
                )
                .first;
        await tester.enterText(actualQuantity, '1');
        await tester.pumpAndSettle();
        final workerHours = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Часов на человека',
        );
        await tester.scrollUntilVisible(
          workerHours,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final workerCount = find.descendant(
          of: find.ancestor(of: workerHours, matching: find.byType(Card)).first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Количество',
          ),
        );
        expect(tester.widget<TextField>(workerCount).controller!.text, isEmpty);
        expect(tester.widget<TextField>(workerHours).controller!.text, isEmpty);
        expect(find.text('По норме всего: 6 чел.-ч'), findsOneWidget);
        if (manualOverride != null) {
          await tester.enterText(workerCount, '3');
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(workerHours).controller!.text, '2');
        }
        if (manualOverride == true) {
          await tester.enterText(workerHours, '5');
          await tester.enterText(workerCount, '4');
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(workerHours).controller!.text, '5');
        }
        final machineHours = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Часов на единицу техники',
        );
        await tester.scrollUntilVisible(
          machineHours,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final machineCount = find.descendant(
          of:
              find
                  .ancestor(of: machineHours, matching: find.byType(Card))
                  .first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Количество',
          ),
        );
        expect(
          tester.widget<TextField>(machineCount).controller!.text,
          isEmpty,
        );
        expect(
          tester.widget<TextField>(machineHours).controller!.text,
          isEmpty,
        );
        expect(find.text('По норме всего: 8 маш.-ч'), findsOneWidget);
        if (manualOverride != null) {
          await tester.enterText(machineCount, '2');
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(machineHours).controller!.text, '4');
        }
        if (manualOverride == true) {
          await tester.enterText(machineHours, '7');
          await tester.enterText(machineCount, '3');
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(machineHours).controller!.text, '7');
          await tester.scrollUntilVisible(
            find.text('Объемы выполненных работ'),
            -350,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(actualQuantity, '2');
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(
          find.text('Сохранить черновик'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Сохранить черновик'));
        await tester.pumpAndSettle();
        final material = (payload!['materials'] as List).single as Map;
        expect(material.containsKey('id'), isFalse);
        expect(material['material_id'], 11);
        expect(material['estimate_item_id'], 81);
        if (manualOverride == null) {
          expect(payload!['workers'], isEmpty);
          expect(payload!['equipment'], isEmpty);
          expect(tester.takeException(), isNull);
          return;
        }
        final worker = (payload!['workers'] as List).single as Map;
        final machine = (payload!['equipment'] as List).single as Map;
        expect(worker['workers_count'], manualOverride ? 4 : 3);
        expect(worker['hours_worked'], manualOverride ? 5 : 2);
        expect(machine['quantity'], manualOverride ? 3 : 2);
        expect(machine['hours_used'], manualOverride ? 7 : 4);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'server hierarchy blocker disables submit while draft stays available',
    (tester) async {
      await _pumpJournalForm(
        tester,
        width: 360,
        textScale: 1,
        submissionBlocker: 'Настройте порядок согласования компаний проекта.',
      );
      expect(
        find.text('Настройте порядок согласования компаний проекта.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Отправить'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Отправить'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Сохранить черновик'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'manual work saves explicit name unit quantity and separate notes without estimate',
    (tester) async {
      Map<String, dynamic>? payload;
      await _pumpJournalForm(
        tester,
        width: 360,
        textScale: 1,
        onEntryCreate: (value) => payload = value,
      );
      await tester.tap(find.text('Дата записи'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final description = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Описание работ',
      );
      await tester.enterText(description, 'Работы на участке А');
      await tester.scrollUntilVisible(
        find.text('Добавить работу без сметы'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Добавить работу без сметы'));
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Наименование работы',
      );
      await tester.enterText(name, 'Укладка покрытия');
      await tester.tap(find.text('Ед. изм.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('кг').last);
      await tester.pumpAndSettle();
      final quantity = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Количество',
      );
      await tester.enterText(quantity, '2,5');
      final notes = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Примечание',
      );
      await tester.enterText(notes, 'Участок А');
      await tester.scrollUntilVisible(
        find.text('Сохранить черновик'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      final row = (payload!['work_volumes'] as List).single as Map;
      expect(row['estimate_item_id'], isNull);
      expect(row['work_name'], 'Укладка покрытия');
      expect(row['measurement_unit_id'], 6);
      expect(row['quantity'], 2.5);
      expect(row['notes'], 'Участок А');
      expect(row.containsKey('estimateItem'), isFalse);
      expect(payload!['materials'], isEmpty);
      expect(payload!['workers'], isEmpty);
      expect(payload!['equipment'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'work quantity suggests resource totals and preserves manually changed material',
    (tester) async {
      await _pumpJournalForm(
        tester,
        width: 360,
        textScale: 1,
        includeLongEstimateOptions: true,
        includeResources: true,
      );
      await tester.tap(find.text('Смета'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('СМ-2026-0003 - Журнал производства работ').last,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Позиция сметы'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Позиция сметы'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Устройство монолитной железобетонной фундаментной плиты',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить из сметы'));
      await tester.pumpAndSettle();
      final quantity =
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == 'Количество',
              )
              .first;
      expect(tester.widget<TextField>(quantity).controller!.text, isEmpty);
      await tester.enterText(quantity, '3');
      await tester.pumpAndSettle();
      expect(find.textContaining('По норме: Арматура — 6 кг'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Списано в работу'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      final material = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Списано в работу',
      );
      expect(tester.widget<TextField>(material).controller!.text, '6');
      await tester.enterText(material, '8');
      await tester.scrollUntilVisible(
        find.text('Объемы выполненных работ'),
        -350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(quantity, '4');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Списано в работу'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<TextField>(material).controller!.text, '8');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Списано в работу',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('journal form fits 240dp with large text', (tester) async {
    await _pumpJournalForm(tester, width: 240, textScale: 1.3);

    expect(find.text('Погодные условия'), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Температура, °C'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Ветер, м/с'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal form shows full temperature label at 360dp', (
    tester,
  ) async {
    await _pumpJournalForm(tester, width: 360, textScale: 1);

    expect(find.text('Погодные условия'), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Температура, °C'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Ветер, м/с'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal options error can retry without losing description', (
    tester,
  ) async {
    await _pumpJournalForm(
      tester,
      width: 360,
      textScale: 1,
      failFirstOptionsRequest: true,
    );

    final description = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Описание работ',
    );
    await tester.enterText(description, 'Сохранённое описание');
    expect(
      find.byKey(const ValueKey('journal-form-options-error')),
      findsOneWidget,
    );
    expect(find.text('Повторить загрузку'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Сохранить черновик'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.scrollUntilVisible(
      find.text('Повторить загрузку'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('journal-form-options-error')),
      findsNothing,
    );
    expect(
      tester.widget<TextField>(description).controller!.text,
      'Сохранённое описание',
    );
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    (width: 360.0, textScale: 1.0),
    (width: 240.0, textScale: 1.3),
  ]) {
    testWidgets(
      'long estimate item stays usable at ${viewport.width}dp × ${viewport.textScale}',
      (tester) async {
        await _pumpJournalForm(
          tester,
          width: viewport.width,
          textScale: viewport.textScale,
          includeLongEstimateOptions: true,
        );

        await tester.tap(find.text('Смета'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('СМ-2026-0003 - Журнал производства работ').last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('Объемы выполненных работ'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Позиция сметы'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Позиция сметы'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.textContaining(
            'Устройство монолитной железобетонной фундаментной плиты',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Добавить из сметы'));
        await tester.pumpAndSettle();
        expect(find.text('Вид работ'), findsOneWidget);
        expect(find.text('Ед. изм.'), findsOneWidget);
        expect(find.text('кг'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Количество',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('estimate item unit survives work type without a unit', (
    tester,
  ) async {
    Map<String, dynamic>? createPayload;
    await _pumpJournalForm(
      tester,
      width: 360,
      textScale: 1,
      includeLongEstimateOptions: true,
      onEntryCreate: (payload) => createPayload = payload,
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Описание работ',
      ),
      'Монтаж арматуры',
    );
    await tester.tap(find.text('Дата записи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Смета'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('СМ-2026-0003 - Журнал производства работ').last,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Объемы выполненных работ'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Позиция сметы'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining(
        'Устройство монолитной железобетонной фундаментной плиты',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить из сметы'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Арматурные работы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Арматурные работы').last);
    await tester.pumpAndSettle();
    expect(find.text('кг'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Количество',
      ),
      '12.5',
    );
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();

    expect(createPayload, isNotNull);
    final volume = (createPayload!['work_volumes'] as List).single as Map;
    expect(volume['estimate_item_id'], 19);
    expect(volume['work_type_id'], 91);
    expect(volume['measurement_unit_id'], 6);
    expect(volume['quantity'], 12.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saving a new draft returns to the journal without a pending-operation error',
    (tester) async {
      final store = _Store();
      var creates = 0;
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  final isOptions = options.path.endsWith(
                    '/entry-form-options',
                  );
                  if (!isOptions) creates++;
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'data':
                            isOptions
                                ? {
                                  'estimates': [],
                                  'work_types': [],
                                  'project_materials': [],
                                }
                                : {
                                  'id': 42,
                                  'journal_id': 7,
                                  'entry_number': 1,
                                  'entry_date': '2026-09-20',
                                  'work_description': 'Монтаж',
                                  'status': 'draft',
                                  'status_label': 'Черновик',
                                  'workflow_state': 'ready',
                                  'workVolumes': [],
                                  'workers': [],
                                  'equipment': [],
                                  'materials': [],
                                  'blockers': [],
                                  'available_actions': [],
                                },
                      },
                    ),
                  );
                },
              ),
            );
      final queue = SyncQueueService(store: store, dio: dio);
      final repository = ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            constructionJournalRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<bool>(
                              builder:
                                  (_) => const JournalEntryFormScreen(
                                    journalId: 7,
                                  ),
                            ),
                          ),
                      child: const Text('Открыть журнал'),
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть журнал'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Дата записи'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Описание работ',
        ),
        'Монтаж',
      );
      await tester.scrollUntilVisible(
        find.text('Сохранить черновик'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Сохранить черновик'));
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(find.text('Открыть журнал'), findsOneWidget);
      expect(await store.all(), isEmpty);
    },
  );

  testWidgets('queued draft is announced without an error notice', (
    tester,
  ) async {
    await _pumpJournalForm(
      tester,
      width: 360,
      textScale: 1,
      failCreateOffline: true,
    );

    await tester.tap(find.text('Дата записи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Описание работ',
      ),
      'Работы для очереди',
    );
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();

    expect(find.text('Восстановление записи'), findsOneWidget);
    expect(find.text('В очереди'), findsOneWidget);
    expect(
      find.text('Будет отправлено при восстановлении связи'),
      findsWidgets,
    );
    expect(find.text('Продолжить отправку'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-error-notice')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows notice when known ID cannot be checked offline', (
    tester,
  ) async {
    final store = _Store();
    var online = false;
    var writes = 0;
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path.endsWith('/entry-form-options')) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: const {
                        'data': {
                          'estimates': <dynamic>[],
                          'work_types': <dynamic>[],
                          'project_materials': <dynamic>[],
                        },
                      },
                    ),
                  );
                  return;
                }
                if (online) {
                  if (options.method != 'GET') writes++;
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {
                        'data': {
                          'id': 42,
                          'journal_id': 7,
                          'entry_number': 1,
                          'entry_date': '2026-09-20',
                          'work_description': 'Монтаж',
                          'status': 'submitted',
                          'status_label': 'На проверке',
                          'workflow_state': 'ready',
                          'workVolumes': [],
                          'workers': [],
                          'equipment': [],
                          'materials': [],
                          'blockers': [],
                          'available_actions': [],
                        },
                      },
                    ),
                  );
                  return;
                }
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
              },
            ),
          );
    final queue = SyncQueueService(store: store, dio: dio);
    await queue.enqueue(
      const SyncQueueDraft(
        moduleSlug: 'construction_journal',
        operationType: 'create_entry',
        method: 'POST',
        endpoint: '/construction-journals/7/entries',
        payload: {
          'idempotency_key': 'restart-key',
          'journal_id': 7,
          'created_entry_id': 42,
          'stage': 'created',
          'submit_intent': true,
          'entry_date': '2026-09-20',
          'work_description': 'Сохранённая запись',
        },
      ),
    );
    final repository = ConstructionJournalRepository(
      dio,
      syncQueueServiceFuture: Future.value(queue),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JournalEntryFormScreen(journalId: 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ожидает подтверждения сервера'),
      findsOneWidget,
    );
    online = true;
    await tester.scrollUntilVisible(
      find.text('Отправить'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();
    expect(await store.all(), isEmpty);
    expect(writes, 0);
  });

  testWidgets('shows server rejection and does not create a second entry', (
    tester,
  ) async {
    final store = _Store();
    var creates = 0;
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path.endsWith('/entry-form-options')) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: const {
                        'data': {
                          'estimates': <dynamic>[],
                          'work_types': <dynamic>[],
                          'project_materials': <dynamic>[],
                        },
                      },
                    ),
                  );
                  return;
                }
                creates++;
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 422,
                      data: {'message': 'Нет протокола для участка А'},
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
              },
            ),
          );
    final queue = SyncQueueService(store: store, dio: dio);
    final repository = ConstructionJournalRepository(
      dio,
      syncQueueServiceFuture: Future.value(queue),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constructionJournalRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: JournalEntryFormScreen(journalId: 7)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дата записи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Описание работ',
      ),
      'Монтаж',
    );
    await tester.scrollUntilVisible(
      find.text('Сохранить черновик'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();
    expect(creates, 1);
    expect(await store.all(), isEmpty);
    await tester.scrollUntilVisible(
      find.textContaining('Отклонено сервером'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Отклонено сервером'), findsWidgets);
    expect(find.textContaining('Нет протокола для участка А'), findsWidgets);
  });
}

Future<void> _pumpJournalForm(
  WidgetTester tester, {
  required double width,
  required double textScale,
  bool failFirstOptionsRequest = false,
  bool failCreateOffline = false,
  bool includeLongEstimateOptions = false,
  bool includeResources = false,
  String? submissionBlocker,
  ConstructionJournalEntryModel? initialEntry,
  void Function(Map<String, dynamic>)? onEntryCreate,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = _Store();
  var optionRequests = 0;
  final dio =
      Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/entries') ||
                  (initialEntry != null &&
                      options.path.endsWith(
                        '/journal-entries/${initialEntry.id}',
                      ))) {
                if (failCreateOffline) {
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.connectionError,
                    ),
                  );
                  return;
                }
                final payload = options.data;
                if (payload is Map) {
                  onEntryCreate?.call(Map<String, dynamic>.from(payload));
                }
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'data': {
                        'id': 42,
                        'journal_id': 7,
                        'entry_number': 1,
                        'entry_date': '2026-09-20',
                        'work_description': 'Монтаж арматуры',
                        'status': 'draft',
                        'status_label': 'Черновик',
                        'workflow_state': 'ready',
                        'workVolumes': <dynamic>[],
                        'workers': <dynamic>[],
                        'equipment': <dynamic>[],
                        'materials': <dynamic>[],
                        'blockers': <dynamic>[],
                        'available_actions': <dynamic>[],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path.endsWith('/entry-form-options') &&
                  failFirstOptionsRequest &&
                  optionRequests++ == 0) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 422,
                      data: const {'message': 'Invalid options request'},
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: _formOptionsResponse(
                    includeLongEstimateOptions,
                    includeResources: includeResources,
                  ),
                ),
              );
            },
          ),
        );
  final repository = ConstructionJournalRepository(
    dio,
    syncQueueServiceFuture: Future.value(
      SyncQueueService(store: store, dio: dio),
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        constructionJournalRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: JournalEntryFormScreen(
          journalId: 7,
          submissionBlocker: submissionBlocker,
          initialEntry: initialEntry,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _formOptionsResponse(
  bool includeLongEstimateOptions, {
  bool includeResources = false,
}) {
  return {
    'data': {
      'estimates':
          includeLongEstimateOptions
              ? [
                {
                  'id': 301,
                  'number': 'СМ-2026-0003',
                  'name': 'Журнал производства работ',
                  'items': [
                    {
                      'id': 19,
                      'estimate_id': 301,
                      'name':
                          'Устройство монолитной железобетонной фундаментной плиты толщиной 400 мм с армированием в два ряда и подготовкой основания',
                      'item_type': 'work',
                      'position_number': '12.1.3.004-0007',
                      'quantity': 25.0,
                      'quantity_total': 25.0,
                      'work_type_id': 91,
                      'measurement_unit_id': 6,
                      'workType': {
                        'id': 91,
                        'name': 'Арматурные работы',
                        'measurement_unit_id': null,
                        'measurementUnit': null,
                      },
                      'measurementUnit': {
                        'id': 6,
                        'name': 'килограмм',
                        'short_name': 'кг',
                      },
                      'contract_links': [],
                      'estimate_planned_quantity': 25,
                      'contract_agreed_quantity': 20,
                      'resources':
                          includeResources
                              ? [
                                {
                                  'id': 1,
                                  'resource_type': 'material',
                                  'name': 'Арматура',
                                  'quantity_per_unit': 2,
                                  'material_id': 11,
                                  'estimate_item_id': 81,
                                  'measurementUnit': {
                                    'id': 6,
                                    'name': 'килограмм',
                                    'short_name': 'кг',
                                  },
                                },
                                {
                                  'id': 2,
                                  'resource_type': 'labor',
                                  'name': 'Монтажник',
                                  'quantity_per_unit': 6,
                                },
                                {
                                  'id': 3,
                                  'resource_type': 'machine',
                                  'name': 'Кран',
                                  'quantity_per_unit': 8,
                                },
                              ]
                              : [],
                    },
                  ],
                },
              ]
              : <dynamic>[],
      'work_types':
          includeLongEstimateOptions
              ? [
                {
                  'id': 91,
                  'name': 'Арматурные работы',
                  'measurement_unit_id': null,
                  'measurementUnit': null,
                },
              ]
              : <dynamic>[],
      'project_materials': <dynamic>[],
      'measurement_units': [
        {'id': 6, 'name': 'килограмм', 'short_name': 'кг'},
      ],
    },
  };
}

class _Store implements SyncQueueStore {
  final operations = <QueuedSyncOperation>[];

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == 0) {
      operation.id = operations.length + 1;
      operations.add(operation);
    } else {
      final index = operations.indexWhere((item) => item.id == operation.id);
      if (index == -1) {
        operations.add(operation);
      } else {
        operations[index] = operation;
      }
    }
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => List.of(operations);

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async => all();

  @override
  Future<QueuedSyncOperation?> get(int id) async {
    for (final operation in operations) {
      if (operation.id == id) return operation;
    }
    return null;
  }

  @override
  Future<void> delete(int id) async {
    operations.removeWhere((item) => item.id == id);
  }
}
