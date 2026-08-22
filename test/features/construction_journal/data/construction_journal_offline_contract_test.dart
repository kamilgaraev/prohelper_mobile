import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create intent is persisted and replayed as one idempotent request', () {
    final repository =
        File(
          'lib/features/construction_journal/data/construction_journal_repository.dart',
        ).readAsStringSync();
    final form =
        File(
          'lib/features/construction_journal/presentation/journal_entry_form_screen.dart',
        ).readAsStringSync();

    expect(repository, contains("'idempotency_key': idempotencyKey"));
    expect(repository, contains("'submit_after_create': submitAfterCreate"));
    expect(repository, contains("'create_and_submit_entry'"));
    expect(form, contains('submitAfterCreate: !isDraft'));
    expect(form, isNot(contains('await repository.submitEntry(entry.id)')));
  });

  test(
    'mobile entry preserves the complete field record in online and offline payloads',
    () {
      final repository =
          File(
            'lib/features/construction_journal/data/construction_journal_repository.dart',
          ).readAsStringSync();
      final models =
          File(
            'lib/features/construction_journal/data/construction_journal_models.dart',
          ).readAsStringSync();
      final form =
          File(
            'lib/features/construction_journal/presentation/journal_entry_form_screen.dart',
          ).readAsStringSync();

      for (final field in [
        "'weather_conditions': weatherConditions?.toJson()",
        "'workers': workers.map((worker) => worker.toJson()).toList()",
        "'equipment': equipment.map((item) => item.toJson()).toList()",
        "'materials': materials.map((material) => material.toJson()).toList()",
      ]) {
        expect(repository, contains(field));
      }
      expect(models, contains("json['weather_conditions']"));
      expect(models, contains("'workers',"));
      expect(models, contains("'equipment',"));
      expect(models, contains("'materials',"));
      expect(form, contains('Погодные условия'));
      expect(form, contains('Работники'));
      expect(form, contains('Техника'));
      expect(form, isNot(contains("label: const Text('Добавить вручную')")));
    },
  );

  test('exports use an idempotency key and poll the background result', () {
    final repository =
        File(
          'lib/features/construction_journal/data/construction_journal_repository.dart',
        ).readAsStringSync();

    expect(repository, contains("'Idempotency-Key': _newIdempotencyKey()"));
    expect(repository, contains("'/construction-journal-exports/\$exportId'"));
    expect(repository, contains("state['status'] == 'completed'"));
    expect(repository, contains("state['status'] == 'failed'"));
    expect(repository, contains("state['error_code'] == 'export_too_large'"));
  });

  test('editing preserves estimate item links for every resource row', () {
    final form =
        File(
          'lib/features/construction_journal/presentation/journal_entry_form_screen.dart',
        ).readAsStringSync();

    expect(
      RegExp(r'estimateItemId: model\.estimateItemId').allMatches(form),
      hasLength(3),
    );
    expect(
      RegExp(
        r'estimateItemId: (material|worker|item)\.estimateItemId',
      ).allMatches(form),
      hasLength(4),
    );
  });
}
