import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/widgets/industrial_card.dart';
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
  _DailyPlansNotifier(super._repository, {this.factError, this.plan})
    : super() {
    state = DailyWorkPlansState(plans: [plan ?? _dailyPlan]);
  }

  final Object? factError;
  final DailyWorkPlanModel? plan;

  @override
  Future<void> load({required int? projectId}) async {}

  @override
  Future<void> recordFact(
    DailyWorkPlanAssignmentModel assignment,
    DailyWorkFactInput input,
  ) async {
    if (factError != null) {
      throw factError!;
    }
    await super.recordFact(assignment, input);
  }
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
  quantity: 0.001,
  completedQuantity: 0.0001,
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
      plannedQuantity: 0.001,
      measurementUnit: 'шт',
      completedQuantity: 0.0001,
      plannedWorkHours: 8,
      actualWorkHours: 0,
      constraints: [],
      linkedBlockingEntities: [],
    ),
  ],
);

const _submittableDailyPlan = DailyWorkPlanModel(
  id: 22,
  projectId: 15,
  scheduleId: 8,
  lookaheadPlanId: 9,
  scheduleName:
      'График инженерных систем с длинным названием для узкого экрана',
  workDate: '2026-09-28',
  status: 'published',
  statusLabel: 'Опубликован',
  availableActions: [
    ScheduleActionModel(action: ScheduleActionKeys.recordFact, label: 'Факт'),
    ScheduleActionModel(action: ScheduleActionKeys.submit, label: 'На приемку'),
  ],
  assignments: [],
);

const _blockedDailyPlan = DailyWorkPlanModel(
  id: 23,
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
  assignments: [],
  submitBlockers: [
    DailyWorkPlanSubmitBlockerModel(
      code: 'open_hard_constraint',
      message: 'Сначала закройте блокирующее условие по материалам.',
    ),
  ],
);

const _narrowDailyPlan = DailyWorkPlanModel(
  id: 24,
  projectId: 15,
  scheduleId: 8,
  lookaheadPlanId: 9,
  scheduleName:
      'График инженерных систем и монтажа оборудования с оформлением исполнительной документации',
  workDate: '2026-09-28',
  status: 'published',
  statusLabel: 'Опубликован',
  availableActions: [
    ScheduleActionModel(action: ScheduleActionKeys.recordFact, label: 'Факт'),
  ],
  assignments: [
    DailyWorkPlanAssignmentModel(
      id: 46,
      dailyWorkPlanId: 24,
      lookaheadPlanTaskId: 12,
      scheduleTaskId: 71,
      status: 'planned',
      statusLabel: 'Запланировано',
      factStatusOptions: [
        DailyWorkFactStatusOptionModel(status: 'done', label: 'Выполнено'),
      ],
      scheduleTaskName:
          'Монтаж внутренних инженерных систем корпуса с испытанием оборудования и оформлением документации',
      plannedQuantity: 0.001,
      measurementUnit: 'шт',
      completedQuantity: 0,
      plannedWorkHours: 1,
      actualWorkHours: 0,
      constraints: [
        DailyWorkConstraintModel(
          id: 81,
          title: 'Нет допуска на выполнение работ',
          constraintType: 'safety_permit_missing',
          constraintTypeLabel: 'Нет допуска по охране труда',
          severity: 'hard',
          severityLabel: 'Жесткое',
          status: 'open',
          statusLabel: 'Открыто',
          availableActions: [
            ScheduleActionModel(
              action: ScheduleActionKeys.createLinkedAction,
              label: 'Создать связанную задачу',
            ),
          ],
        ),
      ],
      linkedBlockingEntities: [],
    ),
  ],
);

void main() {
  testWidgets(
    'daily assignment keeps complete readable actions in a narrow viewport',
    (tester) async {
      await _setViewport(tester, 240);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
            dailyWorkPlansProvider.overrideWith(
              (ref) => _DailyPlansNotifier(
                _ScheduleRepository(),
                plan: _narrowDailyPlan,
              ),
            ),
          ],
          child: _scaledApp(const ScheduleDailyPlansScreen()),
        ),
      );
      await tester.pumpAndSettle();

      const taskTitle =
          'Монтаж внутренних инженерных систем корпуса с испытанием оборудования и оформлением документации';
      final titleFinder = find.text(taskTitle);
      expect(titleFinder, findsOneWidget);
      final title = tester.widget<Text>(titleFinder);
      expect(title.maxLines, 3);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.semanticsLabel, taskTitle);
      expect(tester.getSize(titleFinder).width, greaterThanOrEqualTo(140));

      final planTitle =
          'График инженерных систем и монтажа оборудования с оформлением исполнительной документации';
      final planTitleFinder = find.text(planTitle);
      final planTitleWidget = tester.widget<Text>(planTitleFinder);
      expect(planTitleWidget.maxLines, 3);
      expect(planTitleWidget.overflow, TextOverflow.ellipsis);
      expect(planTitleWidget.semanticsLabel, planTitle);
      final planCard = find.ancestor(
        of: planTitleFinder,
        matching: find.byType(IndustrialCard),
      );
      expect(tester.getSize(planCard).width, greaterThanOrEqualTo(200));
      expect(tester.getSize(planTitleFinder).width, greaterThanOrEqualTo(160));

      await tester.ensureVisible(find.text('Внести факт'));
      final factButton = find.ancestor(
        of: find.text('Внести факт'),
        matching: find.byType(FilledButton),
      );
      expect(factButton, findsOneWidget);
      final actionWidth =
          tester.getSize(find.byKey(const ValueKey('daily-fact-action'))).width;
      expect(actionWidth, greaterThanOrEqualTo(145));
      final factLabel = tester.renderObject<RenderParagraph>(
        find.text('Внести факт'),
      );
      final factWord = factLabel.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );
      final quantityWord = factLabel.getBoxesForSelection(
        const TextSelection(baseOffset: 7, extentOffset: 11),
      );
      expect(factWord, hasLength(1));
      expect(quantityWord, hasLength(1));
      expect(find.text('Зафиксировать'), findsOneWidget);
      final obstacleActionWidth =
          tester
              .getSize(find.byKey(const ValueKey('daily-obstacle-action')))
              .width;
      expect(obstacleActionWidth, greaterThanOrEqualTo(145));
      expect(
        tester.widget<Text>(find.text('Зафиксировать')).semanticsLabel,
        'Зафиксировать препятствие',
      );
      final obstacleLabel = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Зафиксировать'),
          matching: find.byType(RichText),
        ),
      );
      final obstacleTextBoxes = obstacleLabel.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 25),
      );
      expect(obstacleTextBoxes, isNotEmpty);
      expect(
        obstacleTextBoxes.first.right - obstacleTextBoxes.first.left,
        lessThanOrEqualTo(obstacleActionWidth),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [240.0, 360.0]) {
    testWidgets(
      'daily plan shows blockers without submit action at ${width.toInt()}dp text scale 1.3',
      (tester) async {
        await _setViewport(tester, width);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
              dailyWorkPlansProvider.overrideWith(
                (ref) => _DailyPlansNotifier(
                  _ScheduleRepository(),
                  plan: _blockedDailyPlan,
                ),
              ),
            ],
            child: _scaledApp(const ScheduleDailyPlansScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Сначала закройте блокирующее условие по материалам.'),
          findsOneWidget,
        );
        expect(find.text('На приемку'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy daily plan keeps submit action and wraps long title', (
    tester,
  ) async {
    await _setViewport(tester, 240);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
          dailyWorkPlansProvider.overrideWith(
            (ref) => _DailyPlansNotifier(
              _ScheduleRepository(),
              plan: _submittableDailyPlan,
            ),
          ),
        ],
        child: _scaledApp(const ScheduleDailyPlansScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'График инженерных систем с длинным названием для узкого экрана',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('На приемку'));
    expect(find.text('На приемку'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      await tester.scrollUntilVisible(
        find.text('0.0001/0.001 погонный метр'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('0.0001/0.001 погонный метр'), findsOneWidget);
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
      expect(
        find.textContaining('План: 0.001 шт, 8 ч. · Факт: 0.0001 шт'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Внести факт'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Внести факт'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Внести факт'));
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

  testWidgets(
    'queued daily fact stays pending without a server success notice',
    (tester) async {
      await _setViewport(tester, 360);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith((ref) => _ProjectsNotifier()),
            dailyWorkPlansProvider.overrideWith(
              (ref) => _DailyPlansNotifier(
                _ScheduleRepository(),
                factError: const SyncQueuedException(),
              ),
            ),
          ],
          child: _scaledApp(const ScheduleDailyPlansScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Внести факт'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Внести факт'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Результат'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выполнено'));
      await tester.pumpAndSettle();
      final quantityField = find.ancestor(
        of: find.text('Выполненный объем'),
        matching: find.byType(TextFormField),
      );
      final hoursField = find.ancestor(
        of: find.text('Фактические часы'),
        matching: find.byType(TextFormField),
      );
      final commentField = find.ancestor(
        of: find.text('Комментарий'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(quantityField, '0.001');
      await tester.enterText(hoursField, '0.01');
      await tester.enterText(commentField, 'QA queued fact');
      await tester.ensureVisible(find.text('Сохранить факт'));
      await tester.tap(find.text('Сохранить факт'));
      await tester.pumpAndSettle();

      expect(find.text('Факт дневного задания'), findsOneWidget);
      expect(find.text('Сохранить факт'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(quantityField).controller!.text,
        '0.001',
      );
      expect(tester.widget<TextFormField>(hoursField).controller!.text, '0.01');
      expect(
        tester.widget<TextFormField>(commentField).controller!.text,
        'QA queued fact',
      );
      expect(find.text('Факт дневного задания зафиксирован'), findsNothing);
      expect(find.byKey(const ValueKey('app-error-notice')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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
