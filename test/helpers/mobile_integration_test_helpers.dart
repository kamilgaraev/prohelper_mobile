import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';

class MemorySecureStorageService extends SecureStorageService {
  MemorySecureStorageService({String? token, int? selectedProjectId})
    : _token = token,
      _selectedProjectId = selectedProjectId;

  String? _token;
  int? _selectedProjectId;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<void> saveSelectedProjectId(int projectId) async {
    _selectedProjectId = projectId;
  }

  @override
  Future<int?> getSelectedProjectId() async => _selectedProjectId;

  @override
  Future<void> clearSelectedProjectId() async {
    _selectedProjectId = null;
  }
}

void configureProHelperIntegrationTestEnvironment() {}

class TestDioRequest {
  const TestDioRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.data,
  });

  final String method;
  final String path;
  final Map<String, dynamic> queryParameters;
  final Object? data;
}

class TestDioResponseQueue {
  final _routes = <String, Object?>{};
  final requests = <TestDioRequest>[];

  void respond(String method, String path, Object? data) {
    _routes[_key(method, path)] = data;
  }

  Dio buildDio() {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(
            TestDioRequest(
              method: options.method.toUpperCase(),
              path: options.path,
              queryParameters: Map<String, dynamic>.from(
                options.queryParameters,
              ),
              data: options.data,
            ),
          );

          final key = _key(options.method, options.path);
          if (!_routes.containsKey(key)) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Object?>(
                  requestOptions: options,
                  statusCode: 500,
                  data: {
                    'success': false,
                    'message': 'No test response registered for $key',
                    'data': null,
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }

          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: _routes[key],
            ),
          );
        },
      ),
    );

    return dio;
  }

  String _key(String method, String path) => '${method.toUpperCase()} $path';
}

class TestAuthRepository extends AuthRepository {
  TestAuthRepository(this._user, this._storage) : super(Dio(), _storage);

  final User _user;
  final MemorySecureStorageService _storage;

  @override
  Future<User> getMe() async => _user;

  @override
  Future<User> login(String email, String password) async {
    await _storage.saveToken('test-token');
    return _user;
  }

  @override
  Future<User> switchOrganization(int organizationId) async => _user;

  @override
  Future<void> logout() async {
    await _storage.clearToken();
  }
}

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier({
    required User user,
    required MemorySecureStorageService storage,
    required bool authenticated,
  }) : super(TestAuthRepository(user, storage), storage) {
    state = authenticated ? AuthAuthenticated(user) : AuthUnauthenticated();
  }

  @override
  Future<void> checkAuth() async {}
}

class TestProjectsRepository extends ProjectsRepository {
  TestProjectsRepository(this._projects) : super(Dio());

  final List<Project> _projects;

  @override
  Future<List<Project>> fetchProjects() async => _projects;
}

class TestProjectsNotifier extends ProjectsNotifier {
  TestProjectsNotifier({
    required List<Project> projects,
    Project? selectedProject,
    MemorySecureStorageService? storage,
  }) : _projects = projects,
       super(TestProjectsRepository(projects), storage: storage) {
    state = ProjectsState(
      isLoading: false,
      projects: projects,
      selectedProject: selectedProject,
      error: null,
    );
  }

  final List<Project> _projects;

  @override
  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: false, projects: _projects, error: null);
  }
}

class TestModulesRepository extends ModulesRepository {
  TestModulesRepository(this._modules) : super(Dio());

  final List<MobileModuleModel> _modules;

  @override
  Future<List<MobileModuleModel>> fetchModules() async => _modules;
}

class TestModulesNotifier extends ModulesNotifier {
  TestModulesNotifier(List<MobileModuleModel> modules)
    : _modules = modules,
      super(TestModulesRepository(modules), canLoad: false) {
    state = ModulesState(isLoading: false, modules: modules, error: null);
  }

  final List<MobileModuleModel> _modules;

  @override
  Future<void> loadModules() async {
    state = ModulesState(isLoading: false, modules: _modules, error: null);
  }
}

class TestDashboardRepository extends DashboardRepository {
  TestDashboardRepository(this._widgets) : super(Dio());

  final List<DashboardWidgetModel> _widgets;

  @override
  Future<List<DashboardWidgetModel>> fetchWidgets() async => _widgets;
}

class TestDashboardController extends DashboardController {
  TestDashboardController(List<DashboardWidgetModel> widgets)
    : super(TestDashboardRepository(widgets), canLoad: false) {
    state = DashboardState(isLoading: false, widgets: widgets, error: null);
  }
}

class TestNotificationsRepository extends NotificationsRepository {
  TestNotificationsRepository(List<NotificationModel> notifications)
    : _notifications = [...notifications],
      super(Dio());

  final List<NotificationModel> _notifications;

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    final items =
        _notifications.where((notification) {
          return switch (filter) {
            NotificationFilter.all => true,
            NotificationFilter.unread => notification.isUnread,
            NotificationFilter.read => !notification.isUnread,
          };
        }).toList();

    return NotificationsPageResult(
      items: items,
      currentPage: page,
      lastPage: page,
      perPage: perPage,
      total: items.length,
    );
  }

  @override
  Future<NotificationModel> fetchNotification(String id) async {
    return _notifications.firstWhere((notification) => notification.id == id);
  }

  @override
  Future<int> fetchUnreadCount() async {
    return _notifications.where((notification) => notification.isUnread).length;
  }

  @override
  Future<NotificationModel> markAsRead(String id) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    final updated = _notifications[index].copyWith(readAt: DateTime.now());
    _notifications[index] = updated;
    return updated;
  }

  @override
  Future<int> markAllAsRead() async {
    var updated = 0;
    for (var index = 0; index < _notifications.length; index += 1) {
      if (_notifications[index].isUnread) {
        updated += 1;
      }
      _notifications[index] = _notifications[index].copyWith(
        readAt: DateTime.now(),
      );
    }
    return updated;
  }
}

List<Override> proHelperCoreOverrides({
  MemorySecureStorageService? storage,
  bool authenticated = true,
  User? user,
  List<Project>? projects,
  Project? selectedProject,
  Set<AppModule>? activeModules,
  List<DashboardWidgetModel>? dashboardWidgets,
  List<NotificationModel>? notifications,
  Dio? dio,
  UserContext userContext = UserContext.field,
}) {
  final resolvedStorage =
      storage ??
      MemorySecureStorageService(
        token: authenticated ? 'test-token' : null,
        selectedProjectId: selectedProject?.serverId,
      );
  final resolvedUser = user ?? ProHelperTestData.user();
  final resolvedProjects = projects ?? [ProHelperTestData.project()];
  final resolvedSelectedProject = selectedProject;
  final resolvedModules = activeModules ?? ProHelperTestData.allAppModules;
  final resolvedDashboardWidgets =
      dashboardWidgets ?? ProHelperTestData.dashboardWidgets();
  final resolvedNotifications =
      notifications ?? [ProHelperTestData.siteRequestNotification()];
  final resolvedDio = dio ?? TestDioResponseQueue().buildDio();

  return [
    dioProvider.overrideWithValue(resolvedDio),
    secureStorageProvider.overrideWithValue(resolvedStorage),
    authProvider.overrideWith(
      (ref) => TestAuthNotifier(
        user: resolvedUser,
        storage: resolvedStorage,
        authenticated: authenticated,
      ),
    ),
    projectsProvider.overrideWith(
      (ref) => TestProjectsNotifier(
        projects: resolvedProjects,
        selectedProject: resolvedSelectedProject,
        storage: resolvedStorage,
      ),
    ),
    modulesProvider.overrideWith(
      (ref) =>
          TestModulesNotifier(ProHelperTestData.mobileModules(resolvedModules)),
    ),
    activeModulesProvider.overrideWith((ref) => resolvedModules),
    permissionServiceProvider.overrideWith(
      (ref) => PermissionService(
        context: userContext,
        activeModules: resolvedModules,
      ),
    ),
    dashboardControllerProvider.overrideWith(
      (ref) => TestDashboardController(resolvedDashboardWidgets),
    ),
    notificationsRepositoryProvider.overrideWith(
      (ref) => TestNotificationsRepository(resolvedNotifications),
    ),
  ];
}

Future<void> pumpProHelperWidget(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Size surfaceSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ProHelperTheme.lightTheme,
        darkTheme: ProHelperTheme.darkTheme,
        home: child,
      ),
    ),
  );
  await tester.pump();
}

class ProHelperTestData {
  static final allAppModules = Set<AppModule>.from(AppModule.values);

  static User user() {
    return User()
      ..serverId = 1
      ..email = 'foreman@test.local'
      ..name = 'Ivan Foreman'
      ..currentOrganizationId = 10
      ..organizationName = 'Test Build'
      ..organizationsJson = '[]'
      ..roles = ['foreman']
      ..permissionsJson = '{}';
  }

  static Project project({int id = 15, String name = 'Tower A'}) {
    return Project()
      ..serverId = id
      ..name = name
      ..address = 'Main street, 15'
      ..myRole = 'Foreman';
  }

  static List<MobileModuleModel> mobileModules(Set<AppModule> modules) {
    return modules.map((module) {
      return MobileModuleModel(
        slug: module.backendSlug,
        title: module.backendSlug,
        description: '${module.backendSlug} mobile module',
        icon: 'grid',
        supportedOnMobile: true,
        order: module.index,
        route: module.backendSlug,
      );
    }).toList();
  }

  static List<DashboardWidgetModel> dashboardWidgets() {
    final updatedAt = DateTime.parse('2026-05-22T10:00:00+03:00');
    const routes = <String>[
      'project_selection',
      'site_requests',
      'site_request_approvals',
      'warehouse',
      'schedule',
      'ai_assistant',
      'construction_journal',
      'quality-control',
      'safety-management',
      'machinery-operations',
      'production-labor',
      'workforce-management',
      'handover-acceptance',
      'workflow-management',
      'time-tracking',
      'budget-estimates',
      'procurement',
      'contract-management',
      'change-management',
      'executive-documentation',
      'project-management',
      'catalog-management',
      'brigades',
      'video-monitoring',
    ];

    return [
      for (final route in routes)
        DashboardWidgetModel(
          slug: route.replaceAll('-', '_'),
          title: 'Module $route',
          status: DashboardWidgetStatus.active,
          primaryMetric: const DashboardMetric(label: 'Open', value: 1),
          secondaryMetric: const DashboardMetric(label: 'Ready', value: 1),
          route: route,
          updatedAt: updatedAt,
        ),
    ];
  }

  static NotificationModel siteRequestNotification() {
    return NotificationModel(
      id: 'notification-1',
      type: 'site_requests',
      notificationType: 'site_requests',
      title: 'Site request needs attention',
      message: 'Open the linked site request.',
      priority: 'high',
      category: 'site_requests',
      data: const {
        'module': 'site-requests',
        'site_request_id': 1001,
        'title': 'Site request needs attention',
        'message': 'Open the linked site request.',
      },
      actions: const [
        NotificationActionModel(
          label: 'Open',
          params: {'site_request_id': 1001},
        ),
      ],
      createdAt: DateTime(2026, 5, 22, 10),
    );
  }

  static SiteRequestModel siteRequest({
    int id = 1001,
    String title = 'Concrete delivery',
  }) {
    return SiteRequestModel()
      ..serverId = id
      ..title = title
      ..description = 'Concrete delivery for foundation works'
      ..status = 'draft'
      ..statusLabel = 'Draft'
      ..priority = 'medium'
      ..priorityLabel = 'Medium'
      ..requestType = 'material_request'
      ..requestTypeLabel = 'Materials'
      ..projectId = 15
      ..projectName = 'Tower A'
      ..materialName = 'Concrete M300'
      ..materialQuantity = 12
      ..materialUnit = 'm3'
      ..canBeEdited = true
      ..availableTransitions = const [
        SiteRequestTransition(status: 'pending', name: 'Submit'),
      ];
  }
}
