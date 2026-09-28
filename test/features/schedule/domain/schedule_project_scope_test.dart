import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/schedule/domain/schedule_provider.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_daily_plans_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_details_screen.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';
import '../../../helpers/mobile_integration_test_helpers.dart';

final _projectA =
    Project()
      ..serverId = 100
      ..name = 'Объект А';
final _projectB =
    Project()
      ..serverId = 52
      ..name = 'Объект Б';

const _constraint = DailyWorkConstraintModel(
  id: 81,
  title: 'Нет материалов',
  constraintType: 'material_missing',
  constraintTypeLabel: 'Материалы',
  severity: 'hard',
  severityLabel: 'Блокирующее',
  status: 'open',
  statusLabel: 'Открыто',
  availableActions: [],
);

const _assignment = DailyWorkPlanAssignmentModel(
  id: 51,
  dailyWorkPlanId: 41,
  lookaheadPlanTaskId: 17,
  scheduleTaskId: 7,
  status: 'planned',
  statusLabel: 'Запланировано',
  factStatusOptions: [],
  scheduleTaskName: 'Работа объекта А',
  plannedQuantity: 1,
  completedQuantity: null,
  plannedWorkHours: 1,
  actualWorkHours: null,
  constraints: [_constraint],
  linkedBlockingEntities: [],
);

DailyWorkPlanModel _plan(int projectId) => DailyWorkPlanModel(
  id: projectId == 100 ? 41 : 42,
  projectId: projectId,
  scheduleId: 7,
  lookaheadPlanId: 3,
  scheduleName: 'План объекта $projectId',
  workDate: projectId == 100 ? '2026-09-29' : '2026-09-28',
  status: 'published',
  statusLabel: 'Опубликован',
  availableActions: [],
  assignments: projectId == 100 ? [_assignment] : [],
);

ScheduleOverviewModel _overview(int projectId) => ScheduleOverviewModel(
  project: ScheduleProjectModel(id: projectId, name: 'Объект $projectId'),
  summary: const ScheduleOverviewSummaryModel(
    totalSchedules: 0,
    activeSchedules: 0,
    completedSchedules: 0,
    averageProgressPercent: 0,
  ),
  schedules: [],
);

const _details = ScheduleDetailsModel(
  project: ScheduleProjectModel(id: 100, name: 'Объект А'),
  schedule: ScheduleItemModel(
    id: 7,
    projectId: 100,
    name: 'График объекта А',
    status: 'active',
    statusLabel: 'В работе',
    statusColor: '#34C759',
    overallProgressPercent: 0,
    progressColor: '#34C759',
    criticalPathCalculated: false,
    tasksCount: 0,
    completedTasksCount: 0,
    overdueTasksCount: 0,
  ),
  summary: ScheduleDetailsSummaryModel(
    tasksCount: 0,
    completedTasksCount: 0,
    inProgressTasksCount: 0,
    overdueTasksCount: 0,
  ),
  tasks: [],
);

class _Repository extends ScheduleRepository {
  _Repository() : super(Dio());

  Completer<ScheduleOverviewModel>? blockedOverview;
  Completer<DailyWorkPlanAssignmentModel>? blockedFact;
  final writes = <String>[];

  @override
  Future<void> saveTask({
    required int scheduleId,
    int? taskId,
    required Map<String, dynamic> data,
  }) async {
    writes.add('task:$scheduleId');
  }

  @override
  Future<ScheduleOverviewModel> fetchSchedules({required int projectId}) {
    final blocked = blockedOverview;
    blockedOverview = null;
    return blocked?.future ?? Future.value(_overview(projectId));
  }

  @override
  Future<List<DailyWorkPlanModel>> fetchDailyWorkPlans({
    required int projectId,
  }) async => [_plan(projectId)];

  @override
  Future<DailyWorkPlanAssignmentModel> recordDailyWorkFact({
    required int assignmentId,
    required DailyWorkFactInput input,
  }) async {
    writes.add('fact:$assignmentId');
    return blockedFact?.future ?? _assignment;
  }

  @override
  Future<DailyWorkPlanModel> submitDailyWorkPlan({
    required int dailyPlanId,
    String? summaryComment,
  }) async {
    writes.add('submit:$dailyPlanId');
    return _plan(100);
  }

  @override
  Future<void> createLinkedConstraintAction({
    required int constraintId,
    String? comment,
  }) async {
    writes.add('constraint:$constraintId');
  }
}

class _Adapter extends ScheduleSnapshotAdapter {
  _Adapter(this.repository)
    : super(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(
            store: MemoryEntitySnapshotStore(),
            resolveOwner: () => const EntitySnapshotOwner(userId: 7, orgId: 10),
          ),
        ),
      );

  final _Repository repository;

  @override
  Future<ScheduleDailyPlansRead> loadDailyPlans({
    required bool online,
    required int projectId,
  }) async => ScheduleDailyPlansRead(
    presence: SnapshotPresence.ready,
    data: await repository.fetchDailyWorkPlans(projectId: projectId),
  );

  @override
  Future<SnapshotRead<ScheduleOverviewModel>> loadOverview({
    required bool online,
    required int projectId,
  }) async => SnapshotRead(
    presence: SnapshotPresence.ready,
    data: await repository.fetchSchedules(projectId: projectId),
  );

  @override
  Future<SnapshotRead<ScheduleDetailsModel>> loadDetail({
    required bool online,
    required int scheduleId,
    required int projectId,
  }) async =>
      const SnapshotRead(presence: SnapshotPresence.ready, data: _details);
}

class _Harness {
  _Harness() {
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => TestAuthNotifier(
            user:
                User()
                  ..serverId = 7
                  ..email = 'scope@example.test'
                  ..name = 'QA'
                  ..roles = []
                  ..organizationsJson = '[]'
                  ..permissionsJson = '{"schedule":["edit"]}',
            storage: MemorySecureStorageService(),
            authenticated: true,
          ),
        ),
        projectsProvider.overrideWith((ref) => projects),
        scheduleRepositoryProvider.overrideWithValue(repository),
        scheduleSnapshotAdapterProvider.overrideWithValue(_Adapter(repository)),
      ],
    );
  }

  final repository = _Repository();
  final projects = TestProjectsNotifier(
    projects: [_projectA, _projectB],
    selectedProject: _projectA,
  );
  late final ProviderContainer container;
}

void main() {
  test(
    'selected project change reloads retained daily plans provider',
    () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      final subscription = h.container.listen(
        dailyWorkPlansProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      await h.container
          .read(dailyWorkPlansProvider.notifier)
          .load(projectId: 100);
      expect(
        h.container.read(dailyWorkPlansProvider).plans.single.projectId,
        100,
      );

      h.projects.selectProject(_projectB);
      expect(h.container.read(dailyWorkPlansProvider).plans, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(dailyWorkPlansProvider).projectId, 52);
      expect(
        h.container.read(dailyWorkPlansProvider).plans.single.projectId,
        52,
      );

      h.projects.clearSelection();
      expect(h.container.read(dailyWorkPlansProvider).plans, isEmpty);
    },
  );

  test(
    'old daily plan actions are rejected before repository writes',
    () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      final subscription = h.container.listen(
        dailyWorkPlansProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      await h.container
          .read(dailyWorkPlansProvider.notifier)
          .load(projectId: 100);
      final oldNotifier = h.container.read(dailyWorkPlansProvider.notifier);
      h.projects.selectProject(_projectB);
      await Future<void>.delayed(Duration.zero);
      final notifier = h.container.read(dailyWorkPlansProvider.notifier);
      await expectLater(
        oldNotifier.submit(_plan(100)),
        throwsA(isA<ApiException>()),
      );

      await expectLater(
        notifier.submit(_plan(100)),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        notifier.recordFact(
          _assignment,
          const DailyWorkFactInput(status: 'done', completedQuantity: 1),
        ),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        notifier.createLinkedConstraintAction(_constraint, null),
        throwsA(isA<ApiException>()),
      );
      expect(h.repository.writes, isEmpty);
    },
  );

  test('fact acknowledgement cannot reload old selected project', () async {
    final h = _Harness();
    addTearDown(h.container.dispose);
    final subscription = h.container.listen(dailyWorkPlansProvider, (_, __) {});
    addTearDown(subscription.close);
    final notifier = h.container.read(dailyWorkPlansProvider.notifier);
    await notifier.load(projectId: 100);
    h.repository.blockedFact = Completer<DailyWorkPlanAssignmentModel>();
    final fact = notifier.recordFact(
      _assignment,
      const DailyWorkFactInput(status: 'done', completedQuantity: 1),
    );
    h.projects.selectProject(_projectB);
    await Future<void>.delayed(Duration.zero);
    h.repository.blockedFact!.complete(_assignment);
    await fact;

    expect(h.container.read(dailyWorkPlansProvider).projectId, 52);
    expect(h.container.read(dailyWorkPlansProvider).plans.single.projectId, 52);
  });

  test(
    'selected project change clears overview and ignores old response',
    () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      final subscription = h.container.listen(scheduleProvider, (_, __) {});
      addTearDown(subscription.close);
      final notifier = h.container.read(scheduleProvider.notifier);
      await notifier.load(projectId: 100);
      final blocked = Completer<ScheduleOverviewModel>();
      h.repository.blockedOverview = blocked;
      final staleLoad = notifier.load(projectId: 100);
      h.projects.selectProject(_projectB);
      expect(h.container.read(scheduleProvider).overview, isNull);
      await Future<void>.delayed(Duration.zero);
      blocked.complete(_overview(100));
      await staleLoad;

      expect(h.container.read(scheduleProvider).projectId, 52);
      expect(h.container.read(scheduleProvider).overview!.project.id, 52);
    },
  );

  testWidgets(
    'retained daily screen resets date when selected object changes',
    (tester) async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(home: ScheduleDailyPlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '29.09.2026'));
      await tester.pumpAndSettle();
      expect(find.text('План объекта 100'), findsOneWidget);

      h.projects.selectProject(_projectB);
      await tester.pumpAndSettle();
      expect(find.text('Объект Б'), findsOneWidget);
      expect(find.text('План объекта 100'), findsNothing);
      expect(find.text('План объекта 52'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Все'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'retained schedule detail rejects data of the previous object',
    () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      final subscription = h.container.listen(
        scheduleDetailProvider(7),
        (_, __) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      expect(
        h.container.read(scheduleDetailProvider(7)).detail!.schedule.projectId,
        100,
      );

      h.projects.selectProject(_projectB);
      expect(h.container.read(scheduleDetailProvider(7)).detail, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(scheduleDetailProvider(7)).detail, isNull);
      expect(
        h.container.read(scheduleDetailProvider(7)).error,
        contains('другому объекту'),
      );
    },
  );

  testWidgets('task dialog cannot save after selected object changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = _Harness();
    addTearDown(h.container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const MaterialApp(home: ScheduleDetailsScreen(scheduleId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Добавить задачу'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.add_circle_outline_rounded),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Задача объекта А',
    );
    h.projects.selectProject(_projectB);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(h.repository.writes, isEmpty);
    expect(
      find.text('Объект или профиль изменился. Откройте задачу заново.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
