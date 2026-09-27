import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/mobile_app_shell.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';
import 'package:prohelpers_mobile/features/my_actions/data/my_action.dart';
import 'package:prohelpers_mobile/features/my_actions/data/my_actions_repository.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/sync/domain/pending_sync_provider.dart';

class _TestSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}

  @override
  Future<List<String>> getPinnedMobileActionIds() async => const [];

  @override
  Future<void> savePinnedMobileActionIds(List<String> actionIds) async {}
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

class _TestModulesRepository extends ModulesRepository {
  _TestModulesRepository() : super(Dio());

  @override
  Future<List<MobileModuleModel>> fetchModules({int? projectId}) async =>
      const [];
}

class _TestModulesNotifier extends ModulesNotifier {
  _TestModulesNotifier(List<MobileModuleModel> modules)
    : super(_TestModulesRepository(), canLoad: false) {
    state = ModulesState(isLoading: false, modules: modules, error: null);
  }
}

class _TestMyActionsRepository extends MyActionsRepository {
  _TestMyActionsRepository() : super(Dio());

  @override
  Future<MyActionsPage> fetch({
    int? projectId,
    int page = 1,
    int perPage = 10,
  }) async => MyActionsPage(
    items: const [],
    currentPage: page,
    lastPage: page,
    total: 0,
  );
}

class _TestNotificationsRepository extends NotificationsRepository {
  _TestNotificationsRepository() : super(Dio());

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
  Future<int> fetchUnreadCount() async => 0;
}

class _EmptyPending extends PendingSyncNotifier {
  _EmptyPending(super.ref);

  @override
  Future<void> load() async {
    state = const PendingSyncState();
  }
}

void main() {
  testWidgets('shell keeps Главная, Разделы and Я available', (tester) async {
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

    final modules = const [
      MobileModuleModel(
        slug: 'quality-control',
        title: 'Контроль качества',
        description: 'Замечания',
        icon: 'quality',
        supportedOnMobile: true,
        order: 1,
        route: 'quality-control',
      ),
      MobileModuleModel(
        slug: 'catalog-management',
        title: 'Справочники',
        description: 'Данные компании',
        icon: 'catalog',
        supportedOnMobile: true,
        order: 2,
        route: 'catalog_management',
      ),
    ];

    final widgets = [
      DashboardWidgetModel(
        slug: 'quality_control',
        title: 'Контроль качества',
        status: DashboardWidgetStatus.attention,
        primaryMetric: const DashboardMetric(label: 'Открыто', value: 4),
        secondaryMetric: const DashboardMetric(label: 'Просрочено', value: 1),
        route: 'quality-control',
        updatedAt: DateTime.parse('2026-05-21T10:00:00+03:00'),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
          projectsProvider.overrideWith(
            (ref) => _TestProjectsNotifier(project),
          ),
          modulesProvider.overrideWith((ref) => _TestModulesNotifier(modules)),
          dashboardControllerProvider.overrideWith(
            (ref) => _TestDashboardController(widgets),
          ),
          notificationsRepositoryProvider.overrideWith(
            (ref) => _TestNotificationsRepository(),
          ),
          secureStorageProvider.overrideWithValue(_TestSecureStorageService()),
          myActionsRepositoryProvider.overrideWithValue(
            _TestMyActionsRepository(),
          ),
          pendingSyncProvider.overrideWith((ref) => _EmptyPending(ref)),
        ],
        child: const MaterialApp(home: MobileAppShell()),
      ),
    );

    await tester.pump();

    expect(find.text('Главная'), findsWidgets);
    expect(find.text('Разделы'), findsOneWidget);
    expect(find.text('Я'), findsOneWidget);
    expect(find.byTooltip('Действие'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    final navigationTheme = Theme.of(
      tester.element(find.byType(NavigationBar)),
    );
    final navigationHost = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(NavigationBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final navigationDecoration = navigationHost.decoration as BoxDecoration;

    expect(navigationBar.height, ProTouchTarget.comfortable + ProSpacing.lg);
    expect(navigationBar.backgroundColor, navigationTheme.colorScheme.surface);
    expect(navigationBar.elevation, 0);
    expect(navigationBar.shadowColor, Colors.transparent);
    expect(navigationBar.surfaceTintColor, Colors.transparent);
    expect(navigationDecoration.color, navigationTheme.colorScheme.surface);
    expect(navigationDecoration.boxShadow, isNotNull);
    expect(navigationDecoration.boxShadow, isNotEmpty);

    await tester.tap(find.text('Разделы'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Найти раздел'), findsOneWidget);
    expect(find.text('Доступно разделов: 2'), findsOneWidget);
    expect(find.text('Полевые работы'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Полевые работы'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Задачи на объекте, смены и контроль выполнения'),
      findsNothing,
    );
    expect(find.text('Следующие в работе'), findsNothing);

    await tester.tap(find.text('Я'));
    await tester.pumpAndSettle();

    expect(find.text('Профиль, объект и настройки'), findsOneWidget);

    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();

    expect(find.text('Ваши задачи и быстрые действия'), findsOneWidget);
  });

  testWidgets('shell meets core mobile accessibility guidelines', (
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

    final widgets = [
      DashboardWidgetModel(
        slug: 'quality_control',
        title: 'Контроль качества',
        status: DashboardWidgetStatus.attention,
        primaryMetric: const DashboardMetric(label: 'Открыто', value: 4),
        secondaryMetric: const DashboardMetric(label: 'Просрочено', value: 1),
        route: 'quality-control',
        updatedAt: DateTime.parse('2026-05-21T10:00:00+03:00'),
      ),
    ];

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
            projectsProvider.overrideWith(
              (ref) => _TestProjectsNotifier(project),
            ),
            modulesProvider.overrideWith(
              (ref) => _TestModulesNotifier(const []),
            ),
            dashboardControllerProvider.overrideWith(
              (ref) => _TestDashboardController(widgets),
            ),
            notificationsRepositoryProvider.overrideWith(
              (ref) => _TestNotificationsRepository(),
            ),
            secureStorageProvider.overrideWithValue(
              _TestSecureStorageService(),
            ),
            pendingSyncProvider.overrideWith((ref) => _EmptyPending(ref)),
          ],
          child: MaterialApp(
            theme: MostTheme.lightTheme,
            home: const MobileAppShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
