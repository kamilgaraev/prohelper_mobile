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
    expect(detail.result.single.value, 'Принято');
    expect(detail.files.single.uriFor('download')?.scheme, 'https');
    expect(detail.comments.single.body, 'Проверено');
    expect(detail.workflowHistory.single.title, 'Передано на проверку');
    expect(detail.relatedItems.single.actions.single.key, 'approve');
  });

  test('rejects malformed required fields', () {
    final payload = companionListJson()..remove('module');

    expect(
      () => CompanionModuleListModel.fromJson(payload),
      throwsFormatException,
    );
  });

  test('localizes executive result statuses without changing their codes', () {
    const labels = <String, String>{
      'draft': 'Черновик',
      'prepared': 'Подготовлено',
      'under_review': 'На проверке',
      'remarks': 'Есть замечания',
      'approved': 'Согласовано',
      'rejected': 'Отклонено',
      'transmitted': 'Передано',
      'archived': 'В архиве',
    };

    for (final entry in labels.entries) {
      final json = companionDetailJson(slug: 'executive-documentation');
      json['result'] = {'status': entry.key, 'custom_text': entry.key};
      final result = CompanionModuleDetailModel.fromJson(json).result;

      expect(result.first.label, 'Статус');
      expect(result.first.value, entry.key);
      expect(result.first.displayValue, entry.value);
      expect(result.last.value, entry.key);
      expect(result.last.displayValue, isNull);
    }

    final json = companionDetailJson();
    json['result'] = {'status': 'draft'};
    final result = CompanionModuleDetailModel.fromJson(json).result.single;
    expect(result.label, 'status');
    expect(result.value, 'draft');
    expect(result.displayValue, isNull);
  });

  test('localizes executive remark statuses while preserving comments', () {
    for (final entry
        in const {
          'open': 'Открыто',
          'answered': 'Есть ответ',
          'returned': 'Возвращено',
          'resolved': 'Устранено',
        }.entries) {
      final json = companionDetailJson(slug: 'executive-documentation');
      json['comments'] = [
        {'body': entry.key, 'status': entry.key},
      ];
      final comment = CompanionModuleDetailModel.fromJson(json).comments.single;

      expect(comment.body, entry.key);
      expect(comment.status, entry.key);
      expect(comment.statusLabel, entry.value);
    }

    final json = companionDetailJson(slug: 'executive-documentation');
    json['comments'] = [
      {'status': 'open', 'status_label': 'Подпись API'},
      {'status': 'custom_status'},
    ];
    final comments = CompanionModuleDetailModel.fromJson(json).comments;
    expect(comments.first.statusLabel, 'Подпись API');
    expect(comments.last.status, 'custom_status');
    expect(comments.last.statusLabel, isNull);
  });
}
