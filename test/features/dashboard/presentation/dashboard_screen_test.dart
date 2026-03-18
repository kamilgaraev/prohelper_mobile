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
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _FakeSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio(), _FakeSecureStorageService());
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(User user)
      : super(_FakeAuthRepository(), _FakeSecureStorageService()) {
    state = AuthAuthenticated(user);
  }

  @override
  Future<void> checkAuth() async {}
}

class _FakeProjectsRepository extends ProjectsRepository {
  _FakeProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  _FakeProjectsNotifier(Project project) : super(_FakeProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
      error: null,
    );
  }
}

class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository(this._widgets) : super(Dio());

  final List<DashboardWidgetModel> _widgets;

  @override
  Future<List<DashboardWidgetModel>> fetchWidgets() async => _widgets;
}

class _FakeDashboardController extends DashboardController {
  _FakeDashboardController(List<DashboardWidgetModel> widgets)
      : super(_FakeDashboardRepository(widgets), canLoad: false) {
    state = DashboardState(
      isLoading: false,
      widgets: widgets,
      error: null,
    );
  }
}

void main() {
  User buildUser() {
    final user = User()
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
    return const [
      DashboardWidgetModel(
        type: DashboardWidgetType.projectOverview,
        order: 1,
        title: 'Обзор объекта',
        description: 'Текущий объект и ваша роль на нем.',
        payload: {},
      ),
      DashboardWidgetModel(
        type: DashboardWidgetType.warehouse,
        order: 2,
        title: 'Склад',
        description: 'Складов: 2. Низкий остаток: 1.',
        payload: {
          'summary': {
            'warehouse_count': 2,
            'low_stock_count': 1,
          },
        },
        badge: '1',
      ),
      DashboardWidgetModel(
        type: DashboardWidgetType.schedule,
        order: 3,
        title: 'График работ',
        description: 'Событий на 7 дней: 4. Блокирующих: 1.',
        payload: {
          'summary': {
            'upcoming_count': 4,
            'blocking_count': 1,
          },
        },
      ),
    ];
  }

  Widget createWidget() {
    final user = buildUser();
    final project = buildProject();
    final widgets = buildWidgets();

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuthNotifier(user)),
        projectsProvider.overrideWith((ref) => _FakeProjectsNotifier(project)),
        dashboardControllerProvider.overrideWith(
          (ref) => _FakeDashboardController(widgets),
        ),
        activeModulesProvider.overrideWith((ref) {
          return {
            AppModule.basicWarehouse,
            AppModule.scheduleManagement,
          };
        }),
        permissionServiceProvider.overrideWith((ref) {
          return PermissionService(
            context: UserContext.field,
            activeModules: {
              AppModule.basicWarehouse,
              AppModule.scheduleManagement,
            },
          );
        }),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
      ),
    );
  }

  testWidgets('показывает объект и основные карточки дашборда', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Текущий объект'), findsOneWidget);
    expect(find.text('ДОМ 300М ЦАРЕВО'), findsOneWidget);
    expect(find.text('ОБЗОР ОБЪЕКТА'), findsOneWidget);
    expect(find.text('Склад'), findsWidgets);
    expect(find.text('График работ'), findsWidgets);
    expect(find.text('Роль на объекте'), findsOneWidget);
    expect(find.text('Прораб'), findsOneWidget);
    expect(find.text('Складов: 2. Низкий остаток: 1.'), findsOneWidget);
  });
}
