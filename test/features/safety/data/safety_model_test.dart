import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_model.dart';

void main() {
  group('Safety models', () {
    test('parses active permit with project and problem flags', () {
      final permit = SafetyWorkPermitModel.fromJson({
        'id': 10,
        'project_id': 7,
        'permit_number': 'HSE-P-7-001',
        'title': 'Высотные работы',
        'permit_type': 'height_work',
        'risk_level': 'critical',
        'status': 'active',
        'status_label': 'Действует',
        'valid_from': '2026-06-01T00:00:00Z',
        'valid_until': '2026-06-02T00:00:00Z',
        'project': {'id': 7, 'name': 'Башня'},
        'problem_flags': [
          {
            'code': 'permit_expired',
            'severity': 'critical',
            'message': 'Срок истек',
          },
        ],
      });

      expect(permit.id, 10);
      expect(permit.projectName, 'Башня');
      expect(permit.problemFlags.single.code, 'permit_expired');
    });

    test('parses violation actions and optional fields', () {
      final violation = SafetyViolationModel.fromJson({
        'id': 12,
        'project_id': 7,
        'violation_number': 'HSE-V-7-001',
        'title': 'Нет каски',
        'severity': 'major',
        'status': 'open',
        'status_label': 'Открыто',
        'available_actions': ['resolve'],
        'corrective_action': 'Выдать СИЗ',
      });

      expect(violation.availableActions, ['resolve']);
      expect(violation.correctiveAction, 'Выдать СИЗ');
    });
  });
}
