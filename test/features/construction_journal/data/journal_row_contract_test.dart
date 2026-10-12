import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/domain/journal_resource_suggestions.dart';

void main() {
  final payloads = [
    <String, dynamic>{
      'quantity': 3,
      'work_name': 'Работа',
      'measurement_unit_id': 1,
    },
    <String, dynamic>{
      'material_name': 'Бетон',
      'quantity': 3,
      'measurement_unit': 'м³',
    },
    <String, dynamic>{'specialty': 'Мастер', 'workers_count': 2},
    <String, dynamic>{'equipment_name': 'Кран', 'quantity': 1},
  ];
  final serializers = <Map<String, dynamic> Function(Map<String, dynamic>)>[
    (json) => ConstructionJournalWorkVolumeModel.fromJson(json).toJson(),
    (json) => ConstructionJournalMaterialUsageModel.fromJson(json).toJson(),
    (json) => ConstructionJournalWorkerModel.fromJson(json).toJson(),
    (json) => ConstructionJournalEquipmentModel.fromJson(json).toJson(),
  ];

  test(
    'legacy absence and explicit null survive recovery for every row type',
    () {
      for (var index = 0; index < serializers.length; index++) {
        final serialize = serializers[index];
        expect(
          serialize(serialize(payloads[index])).containsKey('contract_id'),
          isFalse,
        );
        final unassigned = serialize(
          serialize({...payloads[index], 'contract_id': null}),
        );
        expect(unassigned.containsKey('contract_id'), isTrue);
        expect(unassigned['contract_id'], isNull);
        expect(
          serialize(
            serialize({...payloads[index], 'contract_id': 23}),
          )['contract_id'],
          23,
        );
      }
    },
  );

  test(
    'resource forecasts are combined only within their selected contract',
    () {
      final item = ConstructionJournalEstimateItemOption.fromJson({
        'id': 19,
        'name': 'Работа',
        'measurement_unit_id': 6,
        'resources': [
          {
            'id': 201,
            'resource_type': 'labor',
            'name': 'Труд рабочих',
            'quantity_per_unit': 2,
            'unit_name': 'чел.-ч',
          },
        ],
      });
      final result = journalContractResourceSuggestions([
        (item: item, quantity: 2.0, contractId: 23),
        (item: item, quantity: 3.0, contractId: 24),
        (item: item, quantity: 1.0, contractId: 23),
        (item: item, quantity: 4.0, contractId: null),
      ]);
      expect(result.map((row) => row.contractId), [23, 24, null]);
      expect(result.map((row) => row.quantity), [6, 6, 8]);
      expect(result.map((row) => row.key).toSet(), hasLength(3));
    },
  );
}
