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

    test('parses incident immediate actions and flags', () {
      final incident = SafetyIncidentModel.fromJson({
        'id': 20,
        'project_id': 7,
        'incident_number': 'INC-7-001',
        'title': 'Опасное условие',
        'incident_type': 'unsafe_condition',
        'severity': 'high',
        'status': 'reported',
        'status_label': 'Зарегистрировано',
        'occurred_at': '2026-06-01T10:00:00Z',
        'immediate_actions': 'Зона ограждена',
        'problem_flags': [
          {
            'code': 'investigation_required',
            'severity': 'warning',
            'message': 'Требуется расследование',
          },
        ],
      });

      expect(incident.immediateActions, 'Зона ограждена');
      expect(incident.problemFlags.single.code, 'investigation_required');
    });

    test('rejects violation payload without explicit status', () {
      expect(
        () => SafetyViolationModel.fromJson({
          'id': 12,
          'project_id': 7,
          'violation_number': 'HSE-V-7-001',
          'title': 'Нет каски',
          'severity': 'major',
          'status_label': 'Открыто',
          'available_actions': ['resolve'],
        }),
        throwsFormatException,
      );
    });
  });
}
