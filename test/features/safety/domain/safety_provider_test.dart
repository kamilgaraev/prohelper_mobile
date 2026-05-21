import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_model.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';
import 'package:prohelpers_mobile/features/safety/domain/safety_provider.dart';

class _FakeSafetyRepository extends SafetyRepository {
  _FakeSafetyRepository() : super(Dio());

  int? loadedProjectId;
  int? resolvedViolationId;
  Map<String, dynamic>? incidentData;
  Map<String, dynamic>? violationData;

  @override
  Future<List<SafetyWorkPermitModel>> fetchActivePermits({
    int? projectId,
  }) async {
    loadedProjectId = projectId;
    return [_permit];
  }

  @override
  Future<List<SafetyIncidentModel>> fetchIncidents({int? projectId}) async {
    return [_incident];
  }

  @override
  Future<List<SafetyViolationModel>> fetchViolations({int? projectId}) async {
    return [_violation];
  }

  @override
  Future<SafetyIncidentModel> createIncident(Map<String, dynamic> data) async {
    incidentData = data;
    return _incident;
  }

  @override
  Future<SafetyViolationModel> createViolation(
    Map<String, dynamic> data,
  ) async {
    violationData = data;
    return _violation;
  }

  @override
  Future<SafetyViolationModel> resolveViolation(int id, String comment) async {
    resolvedViolationId = id;
    return _violation;
  }
}

const _permit = SafetyWorkPermitModel(
  id: 1,
  projectId: 15,
  permitNumber: 'HSE-P-1',
  title: 'Высотные работы',
  permitType: 'height_work',
  riskLevel: 'high',
  status: 'active',
  statusLabel: 'Активен',
  validFrom: '2026-06-01',
  validUntil: '2026-06-02',
);

const _incident = SafetyIncidentModel(
  id: 2,
  projectId: 15,
  incidentNumber: 'HSE-I-2',
  title: 'Опасное условие',
  incidentType: 'unsafe_condition',
  severity: 'major',
  status: 'reported',
  statusLabel: 'Зарегистрировано',
  occurredAt: '2026-06-01T10:00:00Z',
);

const _violation = SafetyViolationModel(
  id: 3,
  projectId: 15,
  violationNumber: 'HSE-V-3',
  title: 'Нет каски',
  severity: 'major',
  status: 'open',
  statusLabel: 'Открыто',
  availableActions: ['resolve'],
);

void main() {
  group('SafetyState', () {
    test('copyWith can clear project filter', () {
      const state = SafetyState(projectFilter: 9);

      final updated = state.copyWith(projectFilter: null);

      expect(updated.projectFilter, isNull);
    });

    test('загружает данные охраны труда по выбранному проекту', () async {
      final repository = _FakeSafetyRepository();
      final notifier = SafetyNotifier(repository);

      notifier.syncProject(15);
      await notifier.load();

      expect(repository.loadedProjectId, 15);
      expect(notifier.state.activePermits.single.id, 1);
      expect(notifier.state.incidents.single.id, 2);
      expect(notifier.state.violations.single.id, 3);
      expect(notifier.state.error, isNull);
    });

    test('после write actions обновляет состояние', () async {
      final repository = _FakeSafetyRepository();
      final notifier = SafetyNotifier(repository)..syncProject(15);

      await notifier.createIncident({'project_id': 15, 'title': 'Инцидент'});
      await notifier.createViolation({'project_id': 15, 'title': 'Нарушение'});
      await notifier.resolveViolation(3, 'Устранено');

      expect(repository.incidentData?['title'], 'Инцидент');
      expect(repository.violationData?['title'], 'Нарушение');
      expect(repository.resolvedViolationId, 3);
      expect(notifier.state.violations, hasLength(1));
    });
  });
}
