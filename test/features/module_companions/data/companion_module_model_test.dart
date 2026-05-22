import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_model.dart';

import '../companion_module_test_data.dart';

void main() {
  test('parses list contract for every remaining companion module', () {
    for (final slug in remainingCompanionSlugs) {
      final list = CompanionModuleListModel.fromJson(
        companionListJson(slug: slug),
      );

      expect(list.module.slug, slug);
      expect(list.items.single.title, 'C-001');
      expect(list.statuses.first.value, 'active');
      expect(list.meta.total, 1);
    }
  });

  test('parses detail sections related items and actions', () {
    final detail = CompanionModuleDetailModel.fromJson(companionDetailJson());

    expect(detail.item.id, 42);
    expect(detail.item.actions.single.key, 'submit');
    expect(detail.sections.single.rows.first.label, 'Номер');
    expect(detail.relatedItems.single.statusLabel, 'Активно');
  });

  test('rejects malformed required fields', () {
    final payload = companionListJson()..remove('module');

    expect(
      () => CompanionModuleListModel.fromJson(payload),
      throwsFormatException,
    );
  });
}
