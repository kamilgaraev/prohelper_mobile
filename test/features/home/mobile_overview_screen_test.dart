import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:prohelpers_mobile/features/home/presentation/mobile_overview_screen.dart';
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

void main() {
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

    expect(find.text('Сегодня на объекте'), findsOneWidget);
    expect(find.text('Следующие действия'), findsOneWidget);
    expect(find.text('Рабочая сводка'), findsOneWidget);
    expect(find.text('Все спокойно'), findsOneWidget);
  });
}
