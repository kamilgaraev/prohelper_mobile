import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/schedule/domain/schedule_provider.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

class _ScheduleTestAuthNotifier extends AuthNotifier {
  _ScheduleTestAuthNotifier(AuthSessionIdentity identity)
    : super(
        AuthRepository(Dio(), SecureStorageService()),
        SecureStorageService(),
        autoCheckAuth: false,
      ) {
    setIdentity(identity);
  }

  void setIdentity(AuthSessionIdentity? identity) {
    state =
        identity == null
            ? AuthUnauthenticated()
            : AuthAuthenticated(
              _scheduleTestUser(identity.userId),
              sessionIdentity: identity,
            );
  }
}

User _scheduleTestUser(int id) =>
    User()
      ..serverId = id
      ..email = 'schedule-test-$id@example.test'
      ..name = 'Schedule test'
      ..organizationsJson = '[]'
      ..roles = const []
      ..permissionsJson = '{}';

class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository({
    this.overviewError,
    this.dailyPlans = const [],
    this.plansAfterFact,
    this.dailyPlansErrorAfterFact,
    this.updatedAssignment,
    this.dailyPlanRequests = const {},
    this.recordFactCompleter,
    this.submitPlanCompleter,
  }) : super(Dio());

  final Object? overviewError;
  final List<DailyWorkPlanModel> dailyPlans;
  final List<DailyWorkPlanModel>? plansAfterFact;
  final Object? dailyPlansErrorAfterFact;
  final DailyWorkPlanAssignmentModel? updatedAssignment;
  final Map<int, Completer<List<DailyWorkPlanModel>>> dailyPlanRequests;
  final Completer<DailyWorkPlanAssignmentModel>? recordFactCompleter;
  final Completer<DailyWorkPlanModel>? submitPlanCompleter;
  DailyWorkFactInput? capturedFactInput;
  bool _factRecorded = false;

  @override
  Future<ScheduleOverviewModel> fetchSchedules({required int projectId}) async {
    final error = overviewError;
    if (error != null) {
      throw error;
    }

    return const ScheduleOverviewModel(
      project: ScheduleProjectModel(id: 15, name: 'Дом 300м Царево'),
      summary: ScheduleOverviewSummaryModel(
        totalSchedules: 0,
        activeSchedules: 0,
        completedSchedules: 0,
        averageProgressPercent: 0,
      ),
      schedules: [],
    );
  }

  @override
  Future<List<DailyWorkPlanModel>> fetchDailyWorkPlans({
    required int projectId,
  }) async {
    final request = dailyPlanRequests[projectId];
    if (request != null) return request.future;
    if (_factRecorded && dailyPlansErrorAfterFact != null) {
      throw dailyPlansErrorAfterFact!;
    }
    if (_factRecorded && plansAfterFact != null) {
      return plansAfterFact!;
    }
    if (_factRecorded && updatedAssignment != null) {
      return dailyPlans
          .map((plan) => _withAssignment(plan, updatedAssignment!))
          .toList();
    }
    return dailyPlans.where((plan) => plan.projectId == projectId).toList();
  }

  @override
  Future<DailyWorkPlanAssignmentModel> recordDailyWorkFact({
    required int assignmentId,
    required DailyWorkFactInput input,
  }) async {
    capturedFactInput = input;
    final completer = recordFactCompleter;
    if (completer != null) return completer.future;
    _factRecorded = true;
    return updatedAssignment!;
  }

  @override
  Future<DailyWorkPlanModel> submitDailyWorkPlan({
    required int dailyPlanId,
    String? summaryComment,
  }) async {
    return submitPlanCompleter!.future;
  }
}

void main() {
  test('marks schedule overview as permission denied on 403', () async {
    final notifier = ScheduleNotifier(
      _FakeScheduleRepository(
        overviewError: const ApiException('Нет прав', statusCode: 403),
      ),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isTrue);
    expect(notifier.state.error, 'Нет прав');
  });

  test('normalizes malformed schedule contract error', () async {
    final notifier = ScheduleNotifier(
      _FakeScheduleRepository(overviewError: const FormatException('bad')),
    );

    await notifier.load(projectId: 15);

    expect(notifier.state.permissionDenied, isFalse);
    expect(
      notifier.state.error,
      'Данные графика пришли неполными. Обновите экран и повторите попытку.',
    );
  });

  test(
    'recordFact forwards explicit fact input without planned defaults',
    () async {
      final assignment = _assignment(
        status: 'planned',
        statusLabel: 'Запланировано',
      );
      final updatedAssignment = _assignment(
        status: 'done',
        statusLabel: 'Выполнено',
        completedQuantity: 3,
        actualWorkHours: 2,
      );
      final plan = DailyWorkPlanModel(
        id: 41,
        projectId: 15,
        scheduleId: 7,
        lookaheadPlanId: 3,
        scheduleName: 'Tower schedule',
        workDate: '2026-06-08',
        status: 'published',
        statusLabel: 'Опубликован',
        availableActions: const [
          ScheduleActionModel(
            action: ScheduleActionKeys.recordFact,
            label: 'Зафиксировать факт',
          ),
        ],
        assignments: [assignment],
      );
      final repository = _FakeScheduleRepository(
        dailyPlans: [plan],
        updatedAssignment: updatedAssignment,
      );
      final notifier = DailyWorkPlansNotifier(repository);

      await notifier.load(projectId: 15);
      await notifier.recordFact(
        assignment,
        const DailyWorkFactInput(
          status: 'done',
          completedQuantity: 3,
          actualWorkHours: 2,
          factComment: 'Смонтировано по факту',
        ),
      );

      expect(repository.capturedFactInput?.completedQuantity, 3);
      expect(repository.capturedFactInput?.actualWorkHours, 2);
      expect(notifier.state.plans.single.assignments.single.status, 'done');
    },
  );

  test(
    'recordFact refreshes parent plan status after server acknowledgement',
    () async {
      final assignment = _assignment(
        status: 'planned',
        statusLabel: 'Запланировано',
      );
      final updatedAssignment = _assignment(
        status: 'done',
        statusLabel: 'Выполнено',
        completedQuantity: 0.001,
        actualWorkHours: 0.01,
      );
      final repository = _FakeScheduleRepository(
        dailyPlans: [
          _dailyPlan(
            status: 'published',
            statusLabel: 'Опубликован',
            assignment: assignment,
          ),
        ],
        plansAfterFact: [
          _dailyPlan(
            status: 'in_progress',
            statusLabel: 'В работе',
            assignment: updatedAssignment,
          ),
        ],
        updatedAssignment: updatedAssignment,
      );
      final notifier = DailyWorkPlansNotifier(repository);

      await notifier.load(projectId: 15);
      await notifier.recordFact(
        assignment,
        const DailyWorkFactInput(
          status: 'done',
          completedQuantity: 0.001,
          actualWorkHours: 0.01,
          factComment: 'QA confirmed fact',
        ),
      );

      expect(notifier.state.plans.single.status, 'in_progress');
      expect(notifier.state.plans.single.statusLabel, 'В работе');
      expect(
        notifier.state.plans.single.assignments.single.completedQuantity,
        0.001,
      );
      expect(
        notifier.state.plans.single.assignments.single.actualWorkHours,
        0.01,
      );
      expect(notifier.state.error, isNull);
    },
  );

  test(
    'recordFact keeps acknowledged assignment when follow-up GET fails',
    () async {
      final assignment = _assignment(
        status: 'planned',
        statusLabel: 'Запланировано',
      );
      final updatedAssignment = _assignment(
        status: 'done',
        statusLabel: 'Выполнено',
        completedQuantity: 0.001,
        actualWorkHours: 0.01,
      );
      final repository = _FakeScheduleRepository(
        dailyPlans: [
          _dailyPlan(
            status: 'published',
            statusLabel: 'Опубликован',
            assignment: assignment,
            submitBlockers: const [
              DailyWorkPlanSubmitBlockerModel(
                code: 'fact_pending',
                message: 'Дождитесь обновления факта',
              ),
            ],
          ),
        ],
        dailyPlansErrorAfterFact: const ApiException(
          'Нет связи',
          statusCode: 503,
        ),
        updatedAssignment: updatedAssignment,
      );
      final notifier = DailyWorkPlansNotifier(repository);

      await notifier.load(projectId: 15);
      await expectLater(
        notifier.recordFact(
          assignment,
          const DailyWorkFactInput(
            status: 'done',
            completedQuantity: 0.001,
            actualWorkHours: 0.01,
            factComment: 'QA confirmed fact',
          ),
        ),
        completes,
      );

      expect(notifier.state.plans.single.status, 'published');
      expect(notifier.state.plans.single.assignments.single.status, 'done');
      expect(
        notifier.state.plans.single.assignments.single.completedQuantity,
        0.001,
      );
      expect(
        notifier.state.plans.single.assignments.single.actualWorkHours,
        0.01,
      );
      expect(notifier.state.error, 'Нет связи');
      expect(
        notifier.state.plans.single.submitBlockers.single.code,
        'fact_pending',
      );
    },
  );

  test(
    'late daily plan load cannot replace the newly selected project',
    () async {
      final projectA = Completer<List<DailyWorkPlanModel>>();
      final projectB = Completer<List<DailyWorkPlanModel>>();
      final notifier = DailyWorkPlansNotifier(
        _FakeScheduleRepository(dailyPlanRequests: {1: projectA, 2: projectB}),
      );

      final loadA = notifier.load(projectId: 1);
      final loadB = notifier.load(projectId: 2);
      projectB.complete([
        _dailyPlan(
          projectId: 2,
          status: 'in_progress',
          statusLabel: 'Проект Б',
          assignment: _assignment(
            status: 'planned',
            statusLabel: 'Запланировано',
          ),
        ),
      ]);
      await loadB;
      projectA.complete([
        _dailyPlan(
          projectId: 1,
          status: 'published',
          statusLabel: 'Проект А',
          assignment: _assignment(
            status: 'planned',
            statusLabel: 'Запланировано',
          ),
        ),
      ]);
      await loadA;

      expect(notifier.state.projectId, 2);
      expect(notifier.state.plans.single.projectId, 2);
      expect(notifier.state.plans.single.statusLabel, 'Проект Б');
      notifier.dispose();
    },
  );

  test(
    'late daily plan error cannot clear or mark the new project failed',
    () async {
      final projectA = Completer<List<DailyWorkPlanModel>>();
      final projectB = Completer<List<DailyWorkPlanModel>>();
      final notifier = DailyWorkPlansNotifier(
        _FakeScheduleRepository(dailyPlanRequests: {1: projectA, 2: projectB}),
      );

      final loadA = notifier.load(projectId: 1);
      final loadB = notifier.load(projectId: 2);
      projectB.complete([
        _dailyPlan(
          projectId: 2,
          status: 'in_progress',
          statusLabel: 'Проект Б',
          assignment: _assignment(
            status: 'planned',
            statusLabel: 'Запланировано',
          ),
        ),
      ]);
      await loadB;
      projectA.completeError(
        const ApiException('Сбой проекта А', statusCode: 503),
      );
      await loadA;

      expect(notifier.state.projectId, 2);
      expect(notifier.state.plans.single.projectId, 2);
      expect(notifier.state.error, isNull);
      notifier.dispose();
    },
  );

  test('late fact acknowledgement after project switch is ignored', () async {
    final acknowledgement = Completer<DailyWorkPlanAssignmentModel>();
    final repository = _FakeScheduleRepository(
      dailyPlans: [
        _dailyPlan(
          status: 'published',
          statusLabel: 'Проект А',
          assignment: _assignment(
            status: 'planned',
            statusLabel: 'Запланировано',
          ),
        ),
      ],
      updatedAssignment: _assignment(status: 'done', statusLabel: 'Выполнено'),
      recordFactCompleter: acknowledgement,
    );
    final notifier = DailyWorkPlansNotifier(repository);
    await notifier.load(projectId: 15);

    final record = notifier.recordFact(
      _assignment(status: 'planned', statusLabel: 'Запланировано'),
      const DailyWorkFactInput(status: 'done', completedQuantity: 1),
    );
    await notifier.load(projectId: 16);
    acknowledgement.complete(
      _assignment(status: 'done', statusLabel: 'Выполнено'),
    );
    await record;

    expect(notifier.state.projectId, 16);
    expect(notifier.state.plans, isEmpty);
    expect(notifier.state.error, isNull);
    notifier.dispose();
  });

  test(
    'late fact acknowledgement after notifier disposal is ignored',
    () async {
      final acknowledgement = Completer<DailyWorkPlanAssignmentModel>();
      final notifier = DailyWorkPlansNotifier(
        _FakeScheduleRepository(
          dailyPlans: [
            _dailyPlan(
              status: 'published',
              statusLabel: 'План',
              assignment: _assignment(
                status: 'planned',
                statusLabel: 'Запланировано',
              ),
            ),
          ],
          updatedAssignment: _assignment(
            status: 'done',
            statusLabel: 'Выполнено',
          ),
          recordFactCompleter: acknowledgement,
        ),
      );
      await notifier.load(projectId: 15);

      final record = notifier.recordFact(
        _assignment(status: 'planned', statusLabel: 'Запланировано'),
        const DailyWorkFactInput(status: 'done', completedQuantity: 1),
      );
      notifier.dispose();
      acknowledgement.complete(
        _assignment(status: 'done', statusLabel: 'Выполнено'),
      );

      await expectLater(record, completes);
    },
  );

  test(
    'submit acknowledgement for a previous project cannot update its row',
    () async {
      final acknowledgement = Completer<DailyWorkPlanModel>();
      final projectAPlan = _dailyPlan(
        projectId: 1,
        status: 'in_progress',
        statusLabel: 'Проект А',
        assignment: _assignment(
          status: 'planned',
          statusLabel: 'Запланировано',
        ),
      );
      final projectBPlan = _dailyPlan(
        projectId: 2,
        status: 'in_progress',
        statusLabel: 'Проект Б',
        assignment: _assignment(
          status: 'planned',
          statusLabel: 'Запланировано',
        ),
      );
      final notifier = DailyWorkPlansNotifier(
        _FakeScheduleRepository(
          dailyPlans: [projectAPlan, projectBPlan],
          submitPlanCompleter: acknowledgement,
        ),
      );
      await notifier.load(projectId: 1);

      final submit = notifier.submit(projectAPlan);
      await notifier.load(projectId: 2);
      acknowledgement.complete(
        _dailyPlan(
          projectId: 1,
          status: 'submitted',
          statusLabel: 'Отправлен из проекта А',
          assignment: _assignment(
            status: 'planned',
            statusLabel: 'Запланировано',
          ),
        ),
      );
      await submit;

      expect(notifier.state.projectId, 2);
      expect(notifier.state.plans.single.projectId, 2);
      expect(notifier.state.plans.single.statusLabel, 'Проект Б');
      notifier.dispose();
    },
  );

  test(
    'submit acknowledgement updates the plan in its current project',
    () async {
      final acknowledgement = Completer<DailyWorkPlanModel>();
      final draft = _dailyPlan(
        projectId: 52,
        status: 'in_progress',
        statusLabel: 'В работе',
        assignment: _assignment(
          status: 'planned',
          statusLabel: 'Запланировано',
        ),
      );
      final submitted = _dailyPlan(
        projectId: 52,
        status: 'submitted',
        statusLabel: 'На проверке',
        assignment: _assignment(
          status: 'planned',
          statusLabel: 'Запланировано',
        ),
      );
      final notifier = DailyWorkPlansNotifier(
        _FakeScheduleRepository(
          dailyPlans: [draft],
          submitPlanCompleter: acknowledgement,
        ),
      );
      await notifier.load(projectId: 52);

      final submit = notifier.submit(draft, summaryComment: 'QA submit');
      acknowledgement.complete(submitted);
      await submit;

      expect(notifier.state.plans.single.status, 'submitted');
      expect(notifier.state.plans.single.statusLabel, 'На проверке');
      notifier.dispose();
    },
  );

  test(
    'adapter errors retain scoped rows but deny and empty clear them',
    () async {
      final plan = _dailyPlan(
        status: 'published',
        statusLabel: 'План',
        assignment: _assignment(
          status: 'planned',
          statusLabel: 'Запланировано',
        ),
      );
      final adapter = _FakeScheduleSnapshotAdapter([
        ScheduleDailyPlansRead(presence: SnapshotPresence.ready, data: [plan]),
        const ScheduleDailyPlansRead(
          presence: SnapshotPresence.error,
          error: 'HTTP 503',
          retainCurrentData: true,
        ),
        const ScheduleDailyPlansRead(
          presence: SnapshotPresence.permissionDenied,
          error: 'Нет доступа',
        ),
        ScheduleDailyPlansRead(presence: SnapshotPresence.ready, data: [plan]),
        const ScheduleDailyPlansRead(
          presence: SnapshotPresence.empty,
          data: [],
        ),
      ]);
      final notifier = DailyWorkPlansNotifier(
        _FakeScheduleRepository(),
        snapshotAdapter: adapter,
      );

      await notifier.load(projectId: 15);
      await notifier.load(projectId: 15);
      expect(notifier.state.plans.single.id, 41);
      expect(notifier.state.error, 'HTTP 503');
      await notifier.load(projectId: 15);
      expect(notifier.state.permissionDenied, isTrue);
      expect(notifier.state.plans, isEmpty);
      await notifier.load(projectId: 15);
      await notifier.load(projectId: 15);
      expect(notifier.state.permissionDenied, isFalse);
      expect(notifier.state.plans, isEmpty);
      notifier.dispose();
    },
  );

  test(
    'organization change isolates retained plans and ignores old owner responses',
    () async {
      const identityA = AuthSessionIdentity(
        userId: 7,
        organizationId: 10,
        sessionId: 'session-a',
      );
      const identityB = AuthSessionIdentity(
        userId: 7,
        organizationId: 11,
        sessionId: 'session-a',
      );
      final oldPlan = _dailyPlan(
        projectId: 52,
        status: 'in_progress',
        statusLabel: 'Данные профиля А',
        assignment: _assignment(
          status: 'planned',
          statusLabel: 'Запланировано',
        ),
      );
      final newPlan = _dailyPlan(
        projectId: 52,
        status: 'published',
        statusLabel: 'Данные профиля Б',
        assignment: _assignment(
          status: 'planned',
          statusLabel: 'Запланировано',
        ),
      );
      final adapter = _FakeScheduleSnapshotAdapter([
        ScheduleDailyPlansRead(
          presence: SnapshotPresence.ready,
          data: [oldPlan],
        ),
        const ScheduleDailyPlansRead(
          presence: SnapshotPresence.error,
          error: 'Нет связи',
          retainCurrentData: true,
        ),
        const ScheduleDailyPlansRead(
          presence: SnapshotPresence.error,
          error: 'HTTP 503',
          retainCurrentData: true,
        ),
        ScheduleDailyPlansRead(
          presence: SnapshotPresence.ready,
          data: [newPlan],
        ),
      ]);
      final auth = _ScheduleTestAuthNotifier(identityA);
      final factAcknowledgement = Completer<DailyWorkPlanAssignmentModel>();
      final submitAcknowledgement = Completer<DailyWorkPlanModel>();
      final repository = _FakeScheduleRepository(
        updatedAssignment: _assignment(
          status: 'done',
          statusLabel: 'Выполнено',
        ),
        recordFactCompleter: factAcknowledgement,
        submitPlanCompleter: submitAcknowledgement,
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          scheduleRepositoryProvider.overrideWithValue(repository),
          scheduleSnapshotAdapterProvider.overrideWithValue(adapter),
        ],
      );
      final subscription = container.listen<DailyWorkPlansState>(
        dailyWorkPlansProvider,
        (_, __) {},
      );
      final notifierA = container.read(dailyWorkPlansProvider.notifier);

      await notifierA.load(projectId: 52);
      await notifierA.load(projectId: 52);
      expect(
        identical(container.read(dailyWorkPlansProvider.notifier), notifierA),
        isTrue,
      );
      expect(notifierA.state.plans.single.statusLabel, 'Данные профиля А');

      final blockedRead = Completer<ScheduleDailyPlansRead>();
      adapter.blockedNextRead = blockedRead;
      final staleLoad = notifierA.load(projectId: 52);
      final staleAck = notifierA.recordFact(
        _assignment(status: 'planned', statusLabel: 'Запланировано'),
        const DailyWorkFactInput(status: 'done', completedQuantity: 1),
      );
      final staleSubmit = notifierA.submit(oldPlan);
      auth.setIdentity(identityB);
      final notifierB = container.read(dailyWorkPlansProvider.notifier);
      expect(identical(notifierB, notifierA), isFalse);

      await notifierB.load(projectId: 52);
      expect(notifierB.state.projectId, 52);
      expect(notifierB.state.plans, isEmpty);
      expect(notifierB.state.error, 'HTTP 503');
      await notifierB.load(projectId: 52);
      expect(notifierB.state.plans.single.statusLabel, 'Данные профиля Б');

      blockedRead.complete(
        ScheduleDailyPlansRead(
          presence: SnapshotPresence.ready,
          data: [oldPlan],
        ),
      );
      factAcknowledgement.complete(
        _assignment(status: 'done', statusLabel: 'Выполнено'),
      );
      submitAcknowledgement.complete(oldPlan);
      await Future.wait([staleLoad, staleAck, staleSubmit]);

      expect(notifierB.state.projectId, 52);
      expect(notifierB.state.plans.single.statusLabel, 'Данные профиля Б');
      subscription.close();
      container.dispose();
    },
  );
}

class _FakeScheduleSnapshotAdapter extends ScheduleSnapshotAdapter {
  _FakeScheduleSnapshotAdapter(this.reads)
    : super(
        repository: _FakeScheduleRepository(),
        snapshots: Future.value(
          EntitySnapshotService(
            store: MemoryEntitySnapshotStore(),
            resolveOwner: () => const EntitySnapshotOwner(userId: 7, orgId: 10),
          ),
        ),
      );

  final List<ScheduleDailyPlansRead> reads;
  var _next = 0;
  Completer<ScheduleDailyPlansRead>? blockedNextRead;

  @override
  Future<ScheduleDailyPlansRead> loadDailyPlans({
    required bool online,
    required int projectId,
  }) async {
    final blocked = blockedNextRead;
    if (blocked != null) {
      blockedNextRead = null;
      return blocked.future;
    }
    return reads[_next++];
  }
}

DailyWorkPlanModel _withAssignment(
  DailyWorkPlanModel plan,
  DailyWorkPlanAssignmentModel updatedAssignment,
) {
  return DailyWorkPlanModel(
    id: plan.id,
    projectId: plan.projectId,
    scheduleId: plan.scheduleId,
    lookaheadPlanId: plan.lookaheadPlanId,
    scheduleName: plan.scheduleName,
    workDate: plan.workDate,
    status: plan.status,
    statusLabel: plan.statusLabel,
    availableActions: plan.availableActions,
    assignments:
        plan.assignments
            .map(
              (item) =>
                  item.id == updatedAssignment.id ? updatedAssignment : item,
            )
            .toList(),
  );
}

DailyWorkPlanModel _dailyPlan({
  int projectId = 15,
  required String status,
  required String statusLabel,
  required DailyWorkPlanAssignmentModel assignment,
  List<DailyWorkPlanSubmitBlockerModel> submitBlockers = const [],
}) {
  return DailyWorkPlanModel(
    id: 41,
    projectId: projectId,
    scheduleId: 7,
    lookaheadPlanId: 3,
    scheduleName: 'Tower schedule',
    workDate: '2026-06-08',
    status: status,
    statusLabel: statusLabel,
    availableActions: const [
      ScheduleActionModel(
        action: ScheduleActionKeys.recordFact,
        label: 'Зафиксировать факт',
      ),
    ],
    assignments: [assignment],
    submitBlockers: submitBlockers,
  );
}

DailyWorkPlanAssignmentModel _assignment({
  required String status,
  required String statusLabel,
  double? completedQuantity,
  double? actualWorkHours,
}) {
  return DailyWorkPlanAssignmentModel(
    id: 51,
    dailyWorkPlanId: 41,
    lookaheadPlanTaskId: 17,
    scheduleTaskId: 7,
    status: status,
    statusLabel: statusLabel,
    factStatusOptions: const [
      DailyWorkFactStatusOptionModel(status: 'done', label: 'Выполнено'),
      DailyWorkFactStatusOptionModel(
        status: 'partially_done',
        label: 'Выполнено частично',
      ),
      DailyWorkFactStatusOptionModel(status: 'not_done', label: 'Не выполнено'),
    ],
    scheduleTaskName: 'Foundation reinforcement',
    plannedQuantity: 10,
    completedQuantity: completedQuantity,
    plannedWorkHours: 8,
    actualWorkHours: actualWorkHours,
    constraints: const [],
    linkedBlockingEntities: const [],
  );
}
