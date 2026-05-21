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
import 'package:prohelpers_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _TestSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}
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
  User buildUser() {
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

    return user;
  }

  Project buildProject() {
    return Project()
      ..serverId = 15
      ..name = 'Дом 300м Царево'
      ..address = 'Лесная улица, 15'
      ..myRole = 'Прораб';
  }

  List<DashboardWidgetModel> buildWidgets() {
    final updatedAt = DateTime.parse('2026-05-21T10:00:00+03:00');

    return [
      DashboardWidgetModel(
        slug: 'project_overview',
        title: 'Обзор объекта',
        status: DashboardWidgetStatus.active,
        primaryMetric: const DashboardMetric(label: 'Разделов', value: 12),
        secondaryMetric: const DashboardMetric(label: 'Ролей', value: 1),
        route: 'project_selection',
        updatedAt: updatedAt,
      ),
      DashboardWidgetModel(
        slug: 'quality_control',
        title: 'Контроль качества',
        status: DashboardWidgetStatus.attention,
        primaryMetric: const DashboardMetric(label: 'Открыто', value: 4),
        secondaryMetric: const DashboardMetric(label: 'Просрочено', value: 1),
        route: 'quality-control',
        updatedAt: updatedAt,
      ),
      DashboardWidgetModel(
        slug: 'warehouse',
        title: 'Склад',
        status: DashboardWidgetStatus.ok,
        primaryMetric: const DashboardMetric(label: 'Складов', value: 2),
        secondaryMetric: const DashboardMetric(
          label: 'Низкий остаток',
          value: 0,
        ),
        route: 'warehouse',
        updatedAt: updatedAt,
      ),
    ];
  }

  Widget createWidget() {
    final user = buildUser();
    final project = buildProject();
    final widgets = buildWidgets();

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
        projectsProvider.overrideWith((ref) => _TestProjectsNotifier(project)),
        dashboardControllerProvider.overrideWith(
          (ref) => _TestDashboardController(widgets),
        ),
        notificationsRepositoryProvider.overrideWith(
          (ref) => _TestNotificationsRepository(),
        ),
        activeModulesProvider.overrideWith((ref) {
          return {
            AppModule.basicWarehouse,
            AppModule.qualityControl,
            AppModule.aiAssistant,
          };
        }),
        permissionServiceProvider.overrideWith((ref) {
          return PermissionService(
            context: UserContext.field,
            activeModules: {
              AppModule.basicWarehouse,
              AppModule.qualityControl,
              AppModule.aiAssistant,
            },
          );
        }),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    );
  }

  testWidgets('показывает карточки из backend-контракта', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pump();

    expect(find.text('Текущий объект'), findsOneWidget);
    expect(find.text('ДОМ 300М ЦАРЕВО'), findsOneWidget);
    expect(find.text('Обзор объекта'), findsOneWidget);
    expect(find.text('Контроль качества'), findsOneWidget);
    expect(find.text('Склад'), findsOneWidget);
    expect(find.text('Открыто'), findsOneWidget);
    expect(find.text('Просрочено'), findsOneWidget);
    expect(find.text('Складов'), findsOneWidget);
    expect(find.text('Низкий остаток'), findsOneWidget);
    expect(find.text('Ассистент'), findsNothing);
  });
}
