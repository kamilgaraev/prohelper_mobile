import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/schedule/domain/schedule_provider.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_daily_plans_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_details_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_task_detail_screen.dart';
import '../../../helpers/mobile_integration_test_helpers.dart';

class _ScheduleRepository extends ScheduleRepository {
  _ScheduleRepository() : super(Dio());

  @override
  Future<ScheduleDetailsModel> fetchScheduleDetails(int scheduleId) async =>
      _details;

  @override
  Future<ScheduleTaskModel> fetchTask(int taskId) async => _task;
}

class _ProjectsRepository extends ProjectsRepository {
  _ProjectsRepository() : super(Dio());
}

class _ProjectsNotifier extends ProjectsNotifier {
  _ProjectsNotifier() : super(_ProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      hasLoaded: true,
      projects: [_selectedProject],
      selectedProject: _selectedProject,
    );
  }

  @override
  Future<void> loadProjects() async {}
}

class _DailyPlansNotifier extends DailyWorkPlansNotifier {
  _DailyPlansNotifier(super._repository) : super() {
    state = const DailyWorkPlansState(plans: [_dailyPlan]);
  }

  @override
  Future<void> load({required int? projectId}) async {}
}

class _DetailNotifier extends ScheduleDetailNotifier {
  _DetailNotifier(_ScheduleRepository repository)
    : super(repository, _details.schedule.id) {
    state = const ScheduleDetailState(detail: _details);
  }

  @override
  Future<void> load() async {}
}

const _project = ScheduleProjectModel(id: 15, name: 'Дом, корпус 1');

final _selectedProject =
    Project()
      ..serverId = 15
      ..name = 'Дом, корпус 1'
      ..address = 'Казань'
      ..myRole = 'Прораб';

const _schedule = ScheduleItemModel(
  id: 8,
  projectId: 15,
  name: 'График инженерных систем',
  description:
      'Монтаж внутренних инженерных систем с проверкой узлов, испытаниями и оформлением исполнительной документации.',
  status: 'active',
  statusLabel: 'В работе',
  statusColor: '#34C759',
  overallProgressPercent: 63,
  progressColor: '#34C759',
  healthStatus: 'healthy',
  plannedStartDate: '2026-03-01',
  plannedEndDate: '2026-09-30',
  plannedDurationDays: 214,
  actualStartDate: '2026-03-03',
  actualEndDate: null,
  criticalPathCalculated: true,
  criticalPathDurationDays: 198,
  tasksCount: 14,
  completedTasksCount: 8,
  overdueTasksCount: 1,
  createdAt: null,
  updatedAt: null,
);

const _task = ScheduleTaskModel(
  id: 71,
  name: 'Монтаж внутренних инженерных систем корпуса',
  description:
      'Прокладка инженерных коммуникаций с комплексной проверкой оборудования и подготовкой документации.',
  taskType: 'work',
  taskTypeLabel: 'Работа',
  status: 'in_progress',
  statusLabel: 'В работе',
  statusColor: '#34C759',
  progressPercent: 43,
  isCritical: true,
  level: 1,
  childrenCount: 0,
  plannedStartDate: '2026-03-01',
  plannedEndDate: '2026-09-30',
  plannedDurationDays: 214,
  actualStartDate: '2026-03-03',
  actualEndDate: null,
  quantity: 125.5,
  completedQuantity: 54.25,
  measurementUnit: 'погонный метр',
);

const _details = ScheduleDetailsModel(
  project: _project,
  schedule: _schedule,
  summary: ScheduleDetailsSummaryModel(
    tasksCount: 14,
    completedTasksCount: 8,
    inProgressTasksCount: 3,
    overdueTasksCount: 1,
  ),
  tasks: [_task],
);

const _dailyPlan = DailyWorkPlanModel(
  id: 22,
  projectId: 15,
  scheduleId: 8,
  lookaheadPlanId: 9,
  scheduleName: 'График инженерных систем',
  workDate: '2026-09-28',
  status: 'published',
  statusLabel: 'Опубликован',
  availableActions: [
    ScheduleActionModel(action: ScheduleActionKeys.recordFact, label: 'Факт'),
  ],
  assignments: [
    DailyWorkPlanAssignmentModel(
      id: 45,
      dailyWorkPlanId: 22,
      lookaheadPlanTaskId: 11,
      scheduleTaskId: 71,
      status: 'planned',
      statusLabel: 'Запланировано',
      factStatusOptions: [
        DailyWorkFactStatusOptionModel(status: 'done', label: 'Выполнено'),
        DailyWorkFactStatusOptionModel(
          status: 'partially_done',
          label: 'Выполнено частично',
        ),
        DailyWorkFactStatusOptionModel(
          status: 'not_done',
          label: 'Не выполнено',
        ),
      ],
      scheduleTaskName:
          'Монтаж внутренних инженерных систем корпуса с испытанием оборудования',
      plannedQuantity: 125.5,
      completedQuantity: 0,
      plannedWorkHours: 8,
      actualWorkHours: 0,
      constraints: [],
      linkedBlockingEntities: [],
    ),
  ],
);

void main() {
  for (final width in [240.0, 360.0]) {
    testWidgets('schedule details fit ${width.toInt()}dp at text scale 1.3', (
      tester,
    ) async {
      await _setViewport(tester, width);
      final repository = _ScheduleRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDetailProvider.overrideWith(
              (ref, scheduleId) => _DetailNotifier(repository),
            ),
            authProvider.overrideWith(
              (ref) => TestAuthNotifier(
                user: _testUser(),
                storage: MemorySecureStorageService(),
                authenticated: false,
              ),
            ),
          ],
          child: _scaledApp(const ScheduleDetailsScreen(scheduleId: 8)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Параметры графика'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Параметры графика'), findsOneWidget);
      expect(find.text('Критический путь'), findsOneWidget);
      expect(
        find.textContaining('Монтаж внутренних инженерных систем'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'schedule task details fit ${width.toInt()}dp at text scale 1.3',
      (tester) async {
        await _setViewport(tester, width);
        final repository = _ScheduleRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scheduleRepositoryProvider.overrideWithValue(repository),
              projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
              activeModulesProvider.overrideWithValue(const <AppModule>{}),
              permissionServiceProvider.overrideWithValue(
                PermissionService(
                  context: UserContext.office,
                  activeModules: const <AppModule>{},
                ),
              ),
              authProvider.overrideWith(
                (ref) => TestAuthNotifier(
                  user: _testUser(),
                  storage: MemorySecureStorageService(),
                  authenticated: false,
                ),
              ),
            ],
            child: _scaledApp(const ScheduleTaskDetailScreen(taskId: 71)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Сроки и выполнение'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Сроки и выполнение'), findsOneWidget);
        expect(find.text('Окончание'), findsOneWidget);
        expect(find.textContaining('погонный метр'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('daily fact form fits ${width.toInt()}dp at text scale 1.3', (
      tester,
    ) async {
      await _setViewport(tester, width);
      final repository = _ScheduleRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
            dailyWorkPlansProvider.overrideWith(
              (ref) => _DailyPlansNotifier(repository),
            ),
          ],
          child: _scaledApp(const ScheduleDailyPlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Факт выполнен'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Факт выполнен'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Факт выполнен'));
      await tester.pumpAndSettle();

      expect(find.text('Результат'), findsOneWidget);
      expect(find.text('Фактические часы'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Результат'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выполнено частично'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _setViewport(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _scaledApp(Widget child) => MaterialApp(
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(1.3)),
        child: child!,
      ),
  home: child,
);

User _testUser() =>
    User()
      ..serverId = 1
      ..email = 'schedule@test.local'
      ..name = 'Пользователь'
      ..organizationName = 'МОСТ'
      ..organizationsJson = '[]'
      ..roles = const []
      ..permissionsJson = '{}';
