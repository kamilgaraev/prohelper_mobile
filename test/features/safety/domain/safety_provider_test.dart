import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_model.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';
import 'package:prohelpers_mobile/features/safety/domain/safety_provider.dart';

class _FakeSafetyRepository extends SafetyRepository {
  _FakeSafetyRepository() : super(Dio());

  int? loadedProjectId;
  int? resolvedViolationId;
  int? submittedPermitId;
  int? approvedPermitId;
  int? activatedPermitId;
  int? suspendedPermitId;
  int? resumedPermitId;
  int? rejectedPermitId;
  int? closedPermitId;
  String? approvalComment;
  String? suspendReason;
  String? rejectReason;
  String? closeComment;
  Map<String, dynamic>? incidentData;
  Map<String, dynamic>? violationData;

  @override
  Future<List<SafetyWorkPermitModel>> fetchPermits({
    int? projectId,
    String? status,
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

  @override
  Future<SafetyWorkPermitModel> submitPermit(int id) async {
    submittedPermitId = id;
    return _permit;
  }

  @override
  Future<SafetyWorkPermitModel> approvePermit(
    int id, {
    String? approvalComment,
  }) async {
    approvedPermitId = id;
    this.approvalComment = approvalComment;
    return _permit;
  }

  @override
  Future<SafetyWorkPermitModel> activatePermit(int id) async {
    activatedPermitId = id;
    return _permit;
  }

  @override
  Future<SafetyWorkPermitModel> suspendPermit(
    int id, {
    required String reason,
  }) async {
    suspendedPermitId = id;
    suspendReason = reason;
    return _permit;
  }

  @override
  Future<SafetyWorkPermitModel> resumePermit(int id) async {
    resumedPermitId = id;
    return _permit;
  }

  @override
  Future<SafetyWorkPermitModel> rejectPermit(
    int id, {
    required String reason,
  }) async {
    rejectedPermitId = id;
    rejectReason = reason;
    return _permit;
  }

  @override
  Future<SafetyWorkPermitModel> closePermit(
    int id, {
    required String closeComment,
  }) async {
    closedPermitId = id;
    this.closeComment = closeComment;
    return _permit;
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
  availableActions: ['suspend', 'close'],
  validFrom: '2026-06-01',
  validUntil: '2026-06-02',
  requiredControls: ['Ограждение', 'Страховка'],
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
      expect(notifier.state.permits.single.id, 1);
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
      await notifier.submitPermit(1);
      await notifier.approvePermit(1, approvalComment: 'Проверено');
      await notifier.activatePermit(1);
      await notifier.suspendPermit(1, reason: 'Ветер');
      await notifier.resumePermit(1);
      await notifier.rejectPermit(1, reason: 'Нет мер контроля');
      await notifier.closePermit(1, closeComment: 'Работы завершены');

      expect(repository.incidentData?['title'], 'Инцидент');
      expect(repository.violationData?['title'], 'Нарушение');
      expect(repository.resolvedViolationId, 3);
      expect(repository.submittedPermitId, 1);
      expect(repository.approvedPermitId, 1);
      expect(repository.approvalComment, 'Проверено');
      expect(repository.activatedPermitId, 1);
      expect(repository.suspendedPermitId, 1);
      expect(repository.suspendReason, 'Ветер');
      expect(repository.resumedPermitId, 1);
      expect(repository.rejectedPermitId, 1);
      expect(repository.rejectReason, 'Нет мер контроля');
      expect(repository.closedPermitId, 1);
      expect(repository.closeComment, 'Работы завершены');
      expect(notifier.state.violations, hasLength(1));
    });
  });
}
