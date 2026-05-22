import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';

void main() {
  test('parses journal with readable status label and action objects', () {
    final journal = ConstructionJournalModel.fromJson(_journalPayload());

    expect(journal.id, 77);
    expect(journal.status, 'active');
    expect(journal.statusLabel, 'Активный');
    expect(
      journal.hasAction(ConstructionJournalActionKeys.createEntry),
      isTrue,
    );
    expect(journal.availableActions.first.label, 'Открыть');
  });

  test('rejects legacy scalar journal actions', () {
    final payload =
        _journalPayload()..['available_actions'] = ['view', 'create_entry'];

    expect(
      () => ConstructionJournalModel.fromJson(payload),
      throwsFormatException,
    );
  });

  test('rejects unreadable journal labels and unknown statuses', () {
    final payload =
        _journalPayload()
          ..['status'] = 'waiting'
          ..['status_label'] = 'construction_journal.statuses.waiting';

    expect(
      () => ConstructionJournalModel.fromJson(payload),
      throwsFormatException,
    );
  });

  test(
    'parses entry with workflow state, blockers and strict work volumes',
    () {
      final entry = ConstructionJournalEntryModel.fromJson(_entryPayload());

      expect(entry.status, 'submitted');
      expect(entry.statusLabel, 'На утверждении');
      expect(entry.workflowState, 'blocked');
      expect(entry.blockers.single.message, 'Нужна привязка к договору');
      expect(entry.workVolumes.single.title, 'Монтаж плит');
      expect(entry.workVolumes.single.measurementUnitName, 'м3');
      expect(entry.hasAction(ConstructionJournalActionKeys.approve), isTrue);
    },
  );

  test('rejects entry without required status label', () {
    final payload = _entryPayload()..remove('status_label');

    expect(
      () => ConstructionJournalEntryModel.fromJson(payload),
      throwsFormatException,
    );
  });

  test('rejects work volume without explicit quantity and title', () {
    final payload = _entryPayload();
    payload['workVolumes'] = [
      {'id': 5, 'journal_entry_id': 91, 'measurement_unit_name': 'м3'},
    ];

    expect(
      () => ConstructionJournalEntryModel.fromJson(payload),
      throwsFormatException,
    );
  });

  test('parses entry form options without hidden material defaults', () {
    final options = ConstructionJournalEntryFormOptions.fromJson({
      'estimates': [
        {
          'id': 8,
          'name': 'Смета СМР',
          'number': 'С-1',
          'items': [
            {
              'id': 81,
              'estimate_id': 8,
              'name': 'Монтаж плит',
              'item_type': 'work',
              'quantity': 12.5,
              'quantity_total': 12.5,
              'position_number': '1.1',
              'work_type_id': 13,
              'measurement_unit_id': 3,
              'workType': {
                'id': 13,
                'name': 'Монтаж',
                'measurement_unit_id': 3,
                'measurementUnit': {
                  'id': 3,
                  'name': 'кубический метр',
                  'short_name': 'м3',
                },
              },
              'measurementUnit': {
                'id': 3,
                'name': 'кубический метр',
                'short_name': 'м3',
              },
              'contract_links': [],
            },
          ],
        },
      ],
      'work_types': [
        {
          'id': 13,
          'name': 'Монтаж',
          'measurement_unit_id': 3,
          'measurementUnit': {
            'id': 3,
            'name': 'кубический метр',
            'short_name': 'м3',
          },
        },
      ],
      'project_materials': [
        {
          'delivery_id': 701,
          'material_id': 11,
          'name': 'Арматура',
          'available_quantity': 4.25,
          'measurement_unit': {'id': 4, 'name': 'тонна', 'short_name': 'т'},
          'accepted_at': '2026-05-20 09:15:00',
        },
      ],
    });

    expect(options.estimates.single.items.single.quantity, 12.5);
    expect(options.projectMaterials.single.availableQuantity, 4.25);
    expect(options.projectMaterials.single.measurementUnit, 'т');
  });

  test('rejects material option without measurement unit', () {
    expect(
      () => ConstructionJournalProjectMaterialOption.fromJson({
        'delivery_id': 701,
        'material_id': 11,
        'name': 'Арматура',
        'available_quantity': 4.25,
      }),
      throwsFormatException,
    );
  });

  test(
    'rejects missing list summary fields instead of using zero defaults',
    () {
      expect(
        () => ConstructionJournalSummary.fromJournalListJson({
          'total_journals': 3,
          'active_journals': 2,
        }),
        throwsFormatException,
      );
    },
  );
}

Map<String, dynamic> _journalPayload() {
  return {
    'id': 77,
    'organization_id': 4,
    'project_id': 15,
    'contract_id': null,
    'name': 'Журнал СМР',
    'journal_number': 'Ж-15',
    'start_date': '2026-05-20',
    'end_date': null,
    'status': 'active',
    'status_label': 'Активный',
    'created_by_user_id': 9,
    'created_at': '2026-05-20 09:00:00',
    'updated_at': '2026-05-20 09:30:00',
    'project': {'id': 15, 'name': 'Дом 300м Царево'},
    'contract': null,
    'createdBy': {'id': 9, 'name': 'Прораб', 'email': 'foreman@example.com'},
    'total_entries': 6,
    'approved_entries': 2,
    'submitted_entries': 3,
    'rejected_entries': 1,
    'available_actions': [
      {'action': 'view', 'label': 'Открыть'},
      {'action': 'create_entry', 'label': 'Создать запись'},
    ],
  };
}

Map<String, dynamic> _entryPayload() {
  return {
    'id': 91,
    'journal_id': 77,
    'schedule_task_id': null,
    'estimate_id': 8,
    'entry_date': '2026-05-21',
    'entry_number': 5,
    'work_description': 'Выполнен монтаж плит перекрытия',
    'status': 'submitted',
    'status_label': 'На утверждении',
    'created_by_user_id': 9,
    'approved_by_user_id': null,
    'approved_at': null,
    'rejection_reason': null,
    'weather_conditions': null,
    'problems_description': null,
    'safety_notes': 'Работы выполнены по наряду',
    'visitors_notes': null,
    'quality_notes': null,
    'created_at': '2026-05-21 10:00:00',
    'updated_at': '2026-05-21 11:00:00',
    'journal': _journalPayload(),
    'scheduleTask': null,
    'estimate': {
      'id': 8,
      'project_id': 15,
      'contract_id': null,
      'name': 'Смета СМР',
    },
    'createdBy': {'id': 9, 'name': 'Прораб', 'email': 'foreman@example.com'},
    'approvedBy': null,
    'workVolumes': [
      {
        'id': 5,
        'journal_entry_id': 91,
        'estimate_item_id': 81,
        'work_type_id': 13,
        'quantity': 3.5,
        'measurement_unit_id': 3,
        'notes': null,
        'title': 'Монтаж плит',
        'measurement_unit_name': 'м3',
      },
    ],
    'workers': [],
    'equipment': [],
    'materials': [],
    'completed_works_count': 0,
    'completed_works': [],
    'workflow_state': 'blocked',
    'blockers': [
      {
        'code': 'contract_missing',
        'message': 'Нужна привязка к договору',
        'target': 'manual_act_line',
        'can_override': true,
      },
    ],
    'available_actions': [
      {'action': 'view', 'label': 'Открыть'},
      {'action': 'approve', 'label': 'Утвердить'},
      {'action': 'reject', 'label': 'Отклонить'},
    ],
  };
}
