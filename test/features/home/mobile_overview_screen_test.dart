import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/widgets/pro_status_banner.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_next_actions.dart';
import 'package:prohelpers_mobile/features/home/presentation/mobile_overview_screen.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_project_header.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_today_status.dart';
import 'package:prohelpers_mobile/features/home/presentation/widgets/overview_work_summary.dart';
import 'package:prohelpers_mobile/features/my_actions/data/my_action.dart';
import 'package:prohelpers_mobile/features/my_actions/data/my_actions_repository.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _TestSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<List<String>> getPinnedMobileActionIds() async => const [];

  @override
  Future<void> savePinnedMobileActionIds(List<String> actionIds) async {}
}

class _TestMyActionsRepository extends MyActionsRepository {
  _TestMyActionsRepository() : super(Dio());

  @override
  Future<MyActionsPage> fetch({
    int? projectId,
    int page = 1,
    int perPage = 10,
  }) async {
    return MyActionsPage(
      items: const [],
      currentPage: page,
      lastPage: page,
      total: 0,
    );
  }
}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository() : super(Dio(), _TestSecureStorageService());
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(User user)
    : super(_TestAuthRepository(), _TestSecureStorageService()) {
    state = AuthAuthenticated(user);
  }

  @override
  Future<void> checkAuth() async {}
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project project) : super(_TestProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
      error: null,
    );
  }
}

class _TestDashboardRepository extends DashboardRepository {
  _TestDashboardRepository(this._widgets) : super(Dio());

  final List<DashboardWidgetModel> _widgets;

  @override
  Future<List<DashboardWidgetModel>> fetchWidgets() async => _widgets;
}

class _TestDashboardController extends DashboardController {
  _TestDashboardController(List<DashboardWidgetModel> widgets)
    : super(_TestDashboardRepository(widgets), canLoad: false) {
    state = DashboardState(isLoading: false, widgets: widgets, error: null);
  }
}

class _TestNotificationsRepository extends NotificationsRepository {
  _TestNotificationsRepository({this.unreadCount = 0}) : super(Dio());

  final int unreadCount;

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    return NotificationsPageResult(
      items: const [],
      currentPage: page,
      lastPage: page,
      perPage: perPage,
      total: 0,
    );
  }

  @override
  Future<int> fetchUnreadCount() async => unreadCount;
}

void main() {
  testWidgets('today status shows retryable error instead of calm state', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewTodayStatus(
            widgets: const [],
            unreadCount: 0,
            isLoading: false,
            error: 'Сервер не ответил вовремя. Попробуйте еще раз.',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Сводка недоступна'), findsOneWidget);
    expect(
      find.text('Сервер не ответил вовремя. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.text('Не удалось обновить состояние объекта'), findsNothing);
    expect(find.text('Все спокойно'), findsNothing);
    expect(
      tester.widget<ProStatusBanner>(find.byType(ProStatusBanner)).compact,
      isTrue,
    );

    await tester.tap(find.text('Повторить'));

    expect(retried, isTrue);
  });

  testWidgets('today status makes notification-only warning actionable', (
    tester,
  ) async {
    var openedNotifications = false;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 390,
              child: OverviewTodayStatus(
                widgets: const [],
                unreadCount: 2,
                isLoading: false,
                error: null,
                onRetry: () {},
                onOpenNotifications: () => openedNotifications = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Новые события'), findsOneWidget);
    expect(find.text('Новые уведомления'), findsNothing);
    expect(
      find.text('Непрочитанных: 2. Проверьте обновления по объекту.'),
      findsOneWidget,
    );
    expect(
      find.text('Требуют внимания: 0. Непрочитанных уведомлений: 2.'),
      findsNothing,
    );
    final notificationAction = find.descendant(
      of: find.byType(ProStatusBanner),
      matching: find.byTooltip('Открыть уведомления'),
    );

    expect(notificationAction, findsOneWidget);
    expect(find.bySemanticsLabel('Открыть уведомления'), findsOneWidget);
    expect(find.text('К уведомлениям'), findsNothing);
    expect(find.text('Открыть уведомления'), findsNothing);
    expect(find.text('Открыть'), findsNothing);

    final banner = tester.widget<ProStatusBanner>(find.byType(ProStatusBanner));
    final titleText = tester.widget<Text>(find.text('Новые события'));
    final descriptionText = tester.widget<Text>(
      find.text('Непрочитанных: 2. Проверьте обновления по объекту.'),
    );

    expect(banner.surfaceTone, ProSurfaceTone.elevated);
    expect(banner.compact, isTrue);
    expect(titleText.maxLines, 1);
    expect(descriptionText.maxLines, 2);

    await tester.tap(notificationAction);

    expect(openedNotifications, isTrue);

    semantics.dispose();
  });

  testWidgets('work summary counts attention widgets inside their own group', (
    tester,
  ) async {
    MobileModuleGroup? openedGroup;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OverviewWorkSummary(
              widgets: [
                _dashboardWidget(
                  slug: 'site_requests',
                  route: 'site_requests',
                  status: DashboardWidgetStatus.critical,
                ),
                _dashboardWidget(
                  slug: 'warehouse',
                  route: 'warehouse',
                  status: DashboardWidgetStatus.attention,
                ),
              ],
              onOpenGroup: (group) => openedGroup = group,
            ),
          ),
        ),
      ),
    );

    expect(find.text('В поле · требуют внимания'), findsOneWidget);
    expect(find.text('Склад · требуют внимания'), findsOneWidget);
    expect(find.text('Согласования'), findsOneWidget);
    expect(find.text('Управление'), findsOneWidget);
    expect(find.text('Без критики'), findsNWidgets(2));
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('OK'), findsNothing);

    await tester.tap(find.text('В поле · требуют внимания'));

    expect(openedGroup, MobileModuleGroup.fieldWork);
  });

  testWidgets('work summary rows expose semantic buttons', (tester) async {
    final semantics = tester.ensureSemantics();
    MobileModuleGroup? openedGroup;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OverviewWorkSummary(
              widgets: const [],
              onOpenGroup: (group) => openedGroup = group,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('В поле\nСигналов нет\nБез критики'),
      ),
      matchesSemantics(
        label: 'В поле\nСигналов нет\nБез критики',
        hasEnabledState: true,
        isEnabled: true,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.text('В поле'));

    expect(openedGroup, MobileModuleGroup.fieldWork);
    semantics.dispose();
  });

  testWidgets('work summary uses compact status rows without empty KPI tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OverviewWorkSummary(widgets: const [], onOpenGroup: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('OK'), findsNothing);
    expect(find.text('Без критики'), findsNWidgets(4));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(4));
    expect(
      tester
          .getSize(find.bySemanticsLabel('В поле\nСигналов нет\nБез критики'))
          .height,
      lessThanOrEqualTo(60),
    );
  });

  testWidgets('overview section headers stay inside card surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                OverviewNextActions(
                  actions: const [],
                  onOpen: (_) {},
                  onOpenActionCenter: () {},
                ),
                OverviewWorkSummary(widgets: const [], onOpenGroup: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.ancestor(
        of: find.text('Следующие действия'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Рабочая сводка'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('next actions subtitle reflects the visible action count', (
    tester,
  ) async {
    final action = MobileActionRecommendation(
      destination: MobileModuleDestination(
        route: '/workflow-test',
        slug: 'workflow-test',
        title: 'Рабочие процессы',
        shortTitle: 'Процессы',
        icon: Icons.account_tree_outlined,
        group: MobileModuleGroup.approvalsAndDocs,
        builder: (_) => const SizedBox.shrink(),
      ),
      score: 10,
      reason: 'Проверить согласования',
      source: MobileActionSource.system,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewNextActions(
            actions: [action],
            onOpen: (_) {},
            onOpenActionCenter: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('Пять быстрых входов под вашу роль и текущий объект.'),
      findsNothing,
    );
    expect(
      find.text('1 быстрый вход по вашим правам и текущему объекту.'),
      findsOneWidget,
    );
  });

  testWidgets('next actions all button exposes action center context', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var openedActionCenter = false;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewNextActions(
              actions: const [],
              onOpen: (_) {},
              onOpenActionCenter: () => openedActionCenter = true,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Открыть все действия'), findsOneWidget);
      expect(find.bySemanticsLabel('Все'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Открыть все действия'));

      expect(openedActionCenter, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('project header keeps long object context readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var switchedProject = false;
    final project =
        Project()
          ..serverId = 56
          ..name = 'Строительство склада Литер А'
          ..address = '420054, Казань, ул 2-я Гаражная, д 4';
    final user =
        User()
          ..serverId = 61
          ..email = 'owner@test.local'
          ..name = 'Иван Иванов'
          ..organizationName = 'СТРОЙ-ТУР';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OverviewProjectHeader(
                project: project,
                user: user,
                onSwitchProject: () => switchedProject = true,
              ),
            ),
          ),
        ),
      ),
    );

    final projectTitle = tester.widget<Text>(
      find.text('Строительство склада Литер А'),
    );
    final headerSize = tester.getSize(
      find
          .descendant(
            of: find.byKey(const ValueKey('overview_project_header_surface')),
            matching: find.byType(InkWell),
          )
          .first,
    );

    expect(projectTitle.maxLines, 2);
    expect(projectTitle.style?.fontSize, lessThanOrEqualTo(18));
    expect(headerSize.height, lessThanOrEqualTo(128));
    expect(find.text('420054, Казань, ул 2-я Гаражная, д 4'), findsOneWidget);
    expect(find.text('Сменить'), findsOneWidget);
    expect(find.text('Сменить объект'), findsNothing);

    await tester.tap(find.text('Сменить'));

    expect(switchedProject, isTrue);
  });

  testWidgets('project header exposes whole card as switch action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var switchedProject = false;
    final project =
        Project()
          ..serverId = 56
          ..name = 'Строительство склада Литер А'
          ..address = '420054, Казань, ул 2-я Гаражная, д 4';
    final user =
        User()
          ..serverId = 61
          ..email = 'owner@test.local'
          ..name = 'Иван Иванов'
          ..organizationName = 'СТРОЙ-ТУР';
    const semanticLabel =
        'Сменить текущий объект: Строительство склада Литер А. '
        'Организация: СТРОЙ-ТУР. '
        'Адрес: 420054, Казань, ул 2-я Гаражная, д 4';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OverviewProjectHeader(
                project: project,
                user: user,
                onSwitchProject: () => switchedProject = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel(semanticLabel)),
      matchesSemantics(
        label: semanticLabel,
        hasEnabledState: true,
        isEnabled: true,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('Сменить'));

    expect(switchedProject, isTrue);
    semantics.dispose();
  });

  testWidgets('renders overview as object command center', (tester) async {
    final user =
        User()
          ..serverId = 1
          ..email = 'foreman@test.local'
          ..name = 'Иван Прораб'
          ..currentOrganizationId = 10
          ..organizationName = 'Тест Строй'
          ..organizationsJson = '[]'
          ..roles = ['foreman']
          ..permissionsJson = '{}';

    final project =
        Project()
          ..serverId = 15
          ..name = 'Дом 300м Царево'
          ..address = 'Лесная улица, 15'
          ..myRole = 'Прораб';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myActionsRepositoryProvider.overrideWithValue(
            _TestMyActionsRepository(),
          ),
          authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
          projectsProvider.overrideWith(
            (ref) => _TestProjectsNotifier(project),
          ),
          dashboardControllerProvider.overrideWith(
            (ref) => _TestDashboardController(const []),
          ),
          permissionServiceProvider.overrideWithValue(
            PermissionService(
              context: UserContext.field,
              activeModules: const <AppModule>{},
            ),
          ),
          notificationsRepositoryProvider.overrideWith(
            (ref) => _TestNotificationsRepository(),
          ),
          secureStorageProvider.overrideWithValue(_TestSecureStorageService()),
        ],
        child: const MaterialApp(home: MobileOverviewScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Операционный день'), findsOneWidget);
    expect(find.text('Дом 300м Царево'), findsOneWidget);
    expect(find.textContaining('Текущий объект'), findsOneWidget);
    expect(find.text('Следующие действия'), findsOneWidget);
    expect(find.text('Рабочая сводка'), findsOneWidget);
    expect(find.text('Все спокойно'), findsOneWidget);
  });

  testWidgets('overview keeps sections out of a merged semantic button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final user =
        User()
          ..serverId = 1
          ..email = 'foreman@test.local'
          ..name = 'Иван Прораб'
          ..currentOrganizationId = 10
          ..organizationName = 'Тест Строй'
          ..organizationsJson = '[]'
          ..roles = ['foreman']
          ..permissionsJson = '{}';

    final project =
        Project()
          ..serverId = 15
          ..name = 'Дом 300м Царево'
          ..address = 'Лесная улица, 15'
          ..myRole = 'Прораб';

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myActionsRepositoryProvider.overrideWithValue(
              _TestMyActionsRepository(),
            ),
            authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
            projectsProvider.overrideWith(
              (ref) => _TestProjectsNotifier(project),
            ),
            dashboardControllerProvider.overrideWith(
              (ref) => _TestDashboardController(const []),
            ),
            permissionServiceProvider.overrideWithValue(
              PermissionService(
                context: UserContext.field,
                activeModules: const <AppModule>{},
              ),
            ),
            notificationsRepositoryProvider.overrideWith(
              (ref) => _TestNotificationsRepository(),
            ),
            secureStorageProvider.overrideWithValue(
              _TestSecureStorageService(),
            ),
          ],
          child: const MaterialApp(home: MobileOverviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final nodes = _collectSemanticsNodes(tester.binding.rootPipelineOwner);

      expect(nodes.where(_isMergedOverviewButton), isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('overview keeps sections out of one merged semantic node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final user =
        User()
          ..serverId = 1
          ..email = 'foreman@test.local'
          ..name = 'Иван Прораб'
          ..currentOrganizationId = 10
          ..organizationName = 'Тест Строй'
          ..organizationsJson = '[]'
          ..roles = ['foreman']
          ..permissionsJson = '{}';

    final project =
        Project()
          ..serverId = 15
          ..name = 'Дом 300м Царево'
          ..address = 'Лесная улица, 15'
          ..myRole = 'Прораб';

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myActionsRepositoryProvider.overrideWithValue(
              _TestMyActionsRepository(),
            ),
            authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
            projectsProvider.overrideWith(
              (ref) => _TestProjectsNotifier(project),
            ),
            dashboardControllerProvider.overrideWith(
              (ref) => _TestDashboardController(const []),
            ),
            permissionServiceProvider.overrideWithValue(
              PermissionService(
                context: UserContext.field,
                activeModules: const <AppModule>{},
              ),
            ),
            notificationsRepositoryProvider.overrideWith(
              (ref) => _TestNotificationsRepository(),
            ),
            secureStorageProvider.overrideWithValue(
              _TestSecureStorageService(),
            ),
          ],
          child: const MaterialApp(home: MobileOverviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final nodes = _collectSemanticsNodes(tester.binding.rootPipelineOwner);

      expect(nodes.where(_isMergedOverviewNode), isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('overview does not merge action and summary sections', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final user =
        User()
          ..serverId = 1
          ..email = 'foreman@test.local'
          ..name = 'Иван Прораб'
          ..currentOrganizationId = 10
          ..organizationName = 'Тест Строй'
          ..organizationsJson = '[]'
          ..roles = ['foreman']
          ..permissionsJson = '{}';
    final project =
        Project()
          ..serverId = 11
          ..name = 'Дом 300м Царево'
          ..address = 'Казань'
          ..myRole = 'Прораб';

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myActionsRepositoryProvider.overrideWithValue(
              _TestMyActionsRepository(),
            ),
            authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
            projectsProvider.overrideWith(
              (ref) => _TestProjectsNotifier(project),
            ),
            dashboardControllerProvider.overrideWith(
              (ref) => _TestDashboardController(const []),
            ),
            permissionServiceProvider.overrideWithValue(
              PermissionService(
                context: UserContext.field,
                activeModules: const <AppModule>{},
              ),
            ),
            notificationsRepositoryProvider.overrideWith(
              (ref) => _TestNotificationsRepository(unreadCount: 2),
            ),
            secureStorageProvider.overrideWithValue(
              _TestSecureStorageService(),
            ),
          ],
          child: const MaterialApp(home: MobileOverviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final nodes = _collectSemanticsNodes(tester.binding.rootPipelineOwner);

      expect(nodes.where(_isMergedOverviewSectionNode), isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('notification action announces unread count and action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final user =
        User()
          ..serverId = 1
          ..email = 'foreman@test.local'
          ..name = 'Иван Прораб'
          ..currentOrganizationId = 10
          ..organizationName = 'Тест Строй'
          ..organizationsJson = '[]'
          ..roles = ['foreman']
          ..permissionsJson = '{}';

    final project =
        Project()
          ..serverId = 15
          ..name = 'Дом 300м Царево'
          ..address = 'Лесная улица, 15'
          ..myRole = 'Прораб';

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myActionsRepositoryProvider.overrideWithValue(
              _TestMyActionsRepository(),
            ),
            authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
            projectsProvider.overrideWith(
              (ref) => _TestProjectsNotifier(project),
            ),
            dashboardControllerProvider.overrideWith(
              (ref) => _TestDashboardController(const []),
            ),
            permissionServiceProvider.overrideWithValue(
              PermissionService(
                context: UserContext.field,
                activeModules: const <AppModule>{},
              ),
            ),
            notificationsRepositoryProvider.overrideWith(
              (ref) => _TestNotificationsRepository(unreadCount: 2),
            ),
            secureStorageProvider.overrideWithValue(
              _TestSecureStorageService(),
            ),
          ],
          child: const MaterialApp(home: MobileOverviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Открыть уведомления, непрочитанных: 2'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('2'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}

DashboardWidgetModel _dashboardWidget({
  required String slug,
  required String route,
  required DashboardWidgetStatus status,
}) {
  return DashboardWidgetModel(
    slug: slug,
    title: slug,
    status: status,
    primaryMetric: const DashboardMetric(label: 'Открыто', value: 1),
    secondaryMetric: const DashboardMetric(label: 'Сегодня', value: 0),
    route: route,
    updatedAt: DateTime(2026, 7, 2),
  );
}

List<SemanticsNode> _collectSemanticsNodes(PipelineOwner owner) {
  final roots = <SemanticsNode>[];
  final root = owner.semanticsOwner?.rootSemanticsNode;
  if (root != null) {
    roots.add(root);
  }
  owner.visitChildren((child) {
    roots.addAll(_collectSemanticsNodes(child));
  });

  final nodes = <SemanticsNode>[];
  for (final root in roots) {
    _visitSemanticsNode(root, nodes);
  }
  return nodes;
}

void _visitSemanticsNode(SemanticsNode node, List<SemanticsNode> nodes) {
  nodes.add(node);
  node.visitChildren((child) {
    _visitSemanticsNode(child, nodes);
    return true;
  });
}

bool _isMergedOverviewButton(SemanticsNode node) {
  final data = node.getSemanticsData();

  return node.hasFlag(SemanticsFlag.isButton) &&
      data.label.contains('Текущий объект') &&
      data.label.contains('Следующие действия') &&
      data.label.contains('Рабочая сводка');
}

bool _isMergedOverviewNode(SemanticsNode node) {
  final data = node.getSemanticsData();

  return data.label.contains('Текущий объект') &&
      data.label.contains('Следующие действия') &&
      data.label.contains('Рабочая сводка');
}

bool _isMergedOverviewSectionNode(SemanticsNode node) {
  final data = node.getSemanticsData();

  return data.label.contains('Следующие действия') &&
      data.label.contains('Рабочая сводка');
}
