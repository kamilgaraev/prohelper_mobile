import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/journal_resource_suggestions.dart';

void main() {
  test(
    'saved material row id remains separate from material estimate and delivery ids',
    () {
      final material = ConstructionJournalMaterialUsageModel.fromJson({
        'id': 93,
        'material_id': 11,
        'estimate_item_id': 83,
        'project_material_delivery_id': 54,
        'custody_warehouse_id': 50,
        'material_name': 'Арматура',
        'quantity': 8,
        'measurement_unit': 'кг',
      });
      final reopened = ConstructionJournalMaterialUsageModel.fromJson(
        material.toJson(),
      );
      expect(reopened.id, 93);
      expect(reopened.materialId, 11);
      expect(reopened.estimateItemId, 83);
      expect(reopened.projectMaterialDeliveryId, 54);
      expect(reopened.custodyWarehouseId, 50);
      const fresh = ConstructionJournalMaterialUsageModel(
        materialId: 11,
        estimateItemId: 83,
        projectMaterialDeliveryId: 54,
        materialName: 'Арматура',
        quantity: 8,
        measurementUnit: 'кг',
      );
      expect(fresh.id, isNull);
      expect(fresh.toJson().containsKey('id'), isFalse);
    },
  );
  test(
    'explicitly absent saved actual hours round trip without becoming zero',
    () {
      final worker = ConstructionJournalWorkerModel.fromJson({
        'id': 91,
        'specialty': 'Монтажник',
        'workers_count': 3,
        'hours_worked': null,
      });
      final machine = ConstructionJournalEquipmentModel.fromJson({
        'id': 92,
        'equipment_name': 'Кран',
        'quantity': 2,
        'hours_used': null,
      });
      expect(worker.toJson()['id'], 91);
      expect(worker.toJson()['hours_worked'], isNull);
      expect(worker.toJson().containsKey('hours_worked'), isTrue);
      expect(machine.toJson()['id'], 92);
      expect(machine.toJson()['hours_used'], isNull);
      expect(machine.toJson().containsKey('hours_used'), isTrue);
    },
  );
  test('norm hours divide by actual people and equipment counts', () {
    expect(journalNormHoursPerUnit(6, '3'), '2');
    expect(journalNormHoursPerUnit(8, '2'), '4');
    expect(journalNormHoursPerUnit(6, ''), isNull);
    expect(journalNormHoursPerUnit(6, '0'), isNull);
  });

  test('unknown estimate plan stays absent after offline round trip', () {
    final item = ConstructionJournalEstimateItemOption.fromJson({
      'id': 4,
      'name': 'Работа',
    });
    expect(item.estimatePlannedQuantity, isNull);
    final reopened = ConstructionJournalEstimateItemOption.fromJson(
      item.toJson(),
    );
    expect(reopened.estimatePlannedQuantity, isNull);
    expect(reopened.quantityTotal, isNull);
  });
  test('actual work quantity scales canonical resources once', () {
    final item = ConstructionJournalEstimateItemOption.fromJson(_itemJson());
    expect(journalResourceSuggestions([(item: item, quantity: 0)]), isEmpty);
    final suggestions = journalResourceSuggestions([(item: item, quantity: 3)]);
    expect(suggestions.map((item) => item.quantity), [6, 12, 1.5]);
    expect(suggestions.first.resource.estimateItemId, 81);
    expect(suggestions.first.resource.measurementUnit?.displayName, 'кг');
  });

  test('saved estimate metadata survives queued payload and reopen', () {
    final item = ConstructionJournalEstimateItemOption.fromJson(_itemJson());
    final model = ConstructionJournalWorkVolumeModel(
      estimateItemId: item.id,
      quantity: 3,
      measurementUnitId: 6,
      measurementUnitName: 'кг',
      title: item.name,
      estimateItem: item,
    );
    final restored = ConstructionJournalWorkVolumeModel.fromJson(
      model.toJson(),
    );
    expect(restored.title, 'Монтаж');
    expect(restored.measurementUnitName, 'кг');
    expect(restored.estimateItem?.estimatePlannedQuantity, 50);
    expect(restored.estimateItem?.contractAgreedQuantity, 20);
    expect(restored.estimateItem?.resources.length, 4);
    expect(restored.quantity, 3);
  });

  test(
    'shared unrepresented resources aggregate actual totals without duplicate rows',
    () {
      final first = ConstructionJournalEstimateItemOption.fromJson({
        'id': 1,
        'name': 'Монтаж А',
        'resources': [
          {
            'id': 8,
            'resource_type': 'labor',
            'name': 'Монтажник',
            'quantity_per_unit': 2,
          },
        ],
      });
      final second = ConstructionJournalEstimateItemOption.fromJson({
        'id': 2,
        'name': 'Монтаж Б',
        'resources': [
          {
            'id': 9,
            'resource_type': 'labor',
            'name': 'Монтажник',
            'quantity_per_unit': 3,
          },
        ],
      });
      final totals = journalResourceSuggestions([
        (item: first, quantity: 3),
        (item: second, quantity: 2),
      ]);
      expect(totals.length, 1);
      expect(totals.single.quantity, 12);
    },
  );

  test('manual work retains explicit name independently of notes', () {
    const model = ConstructionJournalWorkVolumeModel(
      quantity: 2.5,
      measurementUnitId: 6,
      workName: 'Укладка покрытия',
      notes: 'Участок А',
    );
    final payload = model.toJson();
    expect(payload['estimate_item_id'], isNull);
    expect(payload['work_name'], 'Укладка покрытия');
    expect(payload.containsKey('estimateItem'), isFalse);
    final restored = ConstructionJournalWorkVolumeModel.fromJson(payload);
    expect(restored.workName, 'Укладка покрытия');
    expect(restored.title, 'Укладка покрытия');
    expect(restored.notes, 'Участок А');
    expect(restored.measurementUnitName, isNull);
  });

  test('legacy options tolerate missing rich fields and units', () {
    final options = ConstructionJournalEntryFormOptions.fromJson({
      'estimates': [],
      'work_types': [],
      'project_materials': [],
    });
    expect(options.measurementUnits, isEmpty);
    final item = ConstructionJournalEstimateItemOption.fromJson({
      'id': 4,
      'name': 'Работа',
      'quantity': 7,
    });
    expect(item.resources, isEmpty);
    expect(item.estimatePlannedQuantity, 7);
    expect(item.contractAgreedQuantity, isNull);
  });

  test('automatic update protects manual and saved values', () {
    expect(canUpdateJournalSuggestion('6', '6'), isTrue);
    expect(canUpdateJournalSuggestion('8', '6'), isFalse);
    expect(canUpdateJournalSuggestion('6', null), isFalse);
  });

  test(
    'approval history keeps reviewing organization, including legacy null',
    () {
      final event = ConstructionJournalApprovalEvent.fromJson({
        'event': 'approved',
        'actor': {'id': 7, 'name': 'Инженер'},
        'actor_organization_id': 9,
        'actor_organization': {'id': 9, 'name': 'Генподрядчик'},
        'occurred_at': '2026-10-10T12:00:00Z',
      });
      expect(event.actorOrganizationId, 9);
      expect(event.actorOrganizationName, 'Генподрядчик');
      expect(event.actorName, 'Инженер');
      expect(
        ConstructionJournalApprovalEvent.fromJson({
          'event': 'approved',
        }).actorOrganizationName,
        isNull,
      );
    },
  );
}

Map<String, dynamic> _itemJson() => {
  'id': 19,
  'estimate_id': 3,
  'name': 'Монтаж',
  'item_type': 'work',
  'quantity': 50,
  'quantity_total': 50,
  'estimate_planned_quantity': 50,
  'contract_agreed_quantity': 20,
  'measurement_unit_id': 6,
  'measurementUnit': {'id': 6, 'name': 'килограмм', 'short_name': 'кг'},
  'resources': [
    {
      'id': 1,
      'resource_type': 'material',
      'name': 'Арматура',
      'quantity_per_unit': 2,
      'total_quantity': 100,
      'estimate_item_id': 81,
      'material_id': 11,
      'measurementUnit': {'id': 6, 'name': 'килограмм', 'short_name': 'кг'},
    },
    {
      'id': 1,
      'resource_type': 'material',
      'name': 'Арматура',
      'quantity_per_unit': 2,
      'total_quantity': 100,
    },
    {
      'id': 2,
      'resource_type': 'labor',
      'name': 'Монтажник',
      'quantity_per_unit': 4,
      'total_quantity': 200,
    },
    {
      'id': 3,
      'resource_type': 'machine',
      'name': 'Кран',
      'quantity_per_unit': 0.5,
      'total_quantity': 25,
    },
  ],
};
