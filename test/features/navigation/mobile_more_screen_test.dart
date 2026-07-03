import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/navigation/presentation/mobile_more_screen.dart';

class _TestSecureStorageService extends SecureStorageService {
  @override
  Future<String?> getToken() async => 'token';

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}
}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository() : super(Dio(), _TestSecureStorageService());
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._user)
    : super(_TestAuthRepository(), _TestSecureStorageService()) {
    state = AuthAuthenticated(_user);
  }

  final User _user;
  int logoutCalls = 0;

  @override
  Future<void> checkAuth() async {
    state = AuthAuthenticated(_user);
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    state = AuthUnauthenticated();
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project project) : super(_TestProjectsRepository()) {
    initialProject = project;
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
      error: null,
    );
  }

  late final Project initialProject;
  int clearSelectionCalls = 0;

  @override
  void clearSelection() {
    clearSelectionCalls += 1;
    super.clearSelection();
  }
}

class _TestModulesRepository extends ModulesRepository {
  _TestModulesRepository() : super(Dio());

  @override
  Future<List<MobileModuleModel>> fetchModules() async => const [];
}

class _TestModulesNotifier extends ModulesNotifier {
  _TestModulesNotifier([List<MobileModuleModel> modules = const []])
    : super(_TestModulesRepository(), canLoad: false) {
    state = ModulesState(isLoading: false, modules: modules, error: null);
  }
}

void main() {
  late _TestAuthNotifier authNotifier;
  late _TestProjectsNotifier projectsNotifier;

  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildScreen({
    String? avatarUrl,
    List<MobileModuleModel> modules = const [],
  }) {
    final user =
        User()
          ..serverId = 1
          ..email = 'foreman@test.local'
          ..name = 'Иван Иванов'
          ..currentOrganizationId = 10
          ..organizationName = 'Тест Строй'
          ..organizationsJson = '[{"id":10,"name":"Тест Строй"}]'
          ..roles = ['foreman']
          ..permissionsJson = '{}'
          ..avatarUrl = avatarUrl;

    final project =
        Project()
          ..serverId = 15
          ..name = 'Строительство склада Литер А'
          ..address = '420054, Респ Татарстан, г Казань'
          ..myRole = 'Прораб';

    authNotifier = _TestAuthNotifier(user);
    projectsNotifier = _TestProjectsNotifier(project);

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => authNotifier),
        projectsProvider.overrideWith((ref) => projectsNotifier),
        modulesProvider.overrideWith((ref) => _TestModulesNotifier(modules)),
      ],
      child: MaterialApp(
        theme: MostTheme.lightTheme,
        home: const MobileMoreScreen(),
      ),
    );
  }

  testWidgets('карточка объекта во вкладке еще остается компактной', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      const semanticLabel =
          'Сменить текущий объект: Строительство склада Литер А. '
          'Адрес: 420054, Респ Татарстан, г Казань';
      final projectSurface = find.byKey(
        const ValueKey('more_project_context_surface'),
      );
      final projectInkWell =
          find
              .descendant(of: projectSurface, matching: find.byType(InkWell))
              .first;

      expect(find.text('Сменить'), findsOneWidget);
      expect(find.text('Сменить объект'), findsNothing);
      expect(find.bySemanticsLabel(semanticLabel), findsOneWidget);
      expect(tester.getSize(projectInkWell).height, lessThanOrEqualTo(132));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.text('Сменить'));
      await tester.pumpAndSettle();

      expect(find.text('Выберите объект для работы'), findsOneWidget);
      expect(projectsNotifier.clearSelectionCalls, 0);
      expect(
        projectsNotifier.state.selectedProject,
        projectsNotifier.initialProject,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('группы вкладки еще закреплены внутри карточных поверхностей', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      buildScreen(
        modules: const [
          MobileModuleModel(
            slug: 'contract-management',
            title: 'Договоры',
            description: 'Договоры и контрагенты',
            icon: 'contract',
            supportedOnMobile: true,
            order: 1,
            route: 'contract_management',
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
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(of: find.text('Помощь'), matching: find.byType(ProSurface)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Управление'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Аккаунт'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.ancestor(
        of: find.text('Аккаунт'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('подтверждает выход перед завершением сессии', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Выйти'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    expect(authNotifier.logoutCalls, 0);
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    expect(find.text('Остаться'), findsOneWidget);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);

    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();

    expect(authNotifier.logoutCalls, 0);
    expect(find.text('Выйти из аккаунта?'), findsNothing);

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();

    expect(authNotifier.logoutCalls, 1);
  });

  testWidgets('профиль не показывает пустую кнопку настроек', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Иван Иванов').first);
    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsNothing);
  });

  testWidgets('профильный лист озвучивает затемнение как закрытие профиля', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Иван Иванов').first);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Закрыть профиль'), findsOneWidget);
      expect(find.bySemanticsLabel('Маска'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'профиль показывает инициалы вместо серверного аватара-заглушки',
    (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        buildScreen(
          avatarUrl: 'https://api.prohelper.pro/images/default-avatar.png',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Иван Иванов').first);
      await tester.pumpAndSettle();

      final profileAvatar = tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .singleWhere((avatar) => avatar.radius == 32);

      expect(profileAvatar.backgroundImage, isNull);
      expect(
        profileAvatar.child,
        isA<Text>().having((text) => text.data, 'data', 'ИИ'),
      );
    },
  );

  testWidgets('смена объекта из профиля открывает выбор без сброса текущего', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Иван Иванов').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сменить объект').last);
    await tester.pumpAndSettle();

    expect(find.text('Выберите объект для работы'), findsOneWidget);
    expect(projectsNotifier.clearSelectionCalls, 0);
    expect(
      projectsNotifier.state.selectedProject,
      projectsNotifier.initialProject,
    );
  });

  testWidgets(
    'профильная карточка озвучивает действие без аватарных инициалов',
    (tester) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();

      try {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(
            'Открыть профиль: Иван Иванов, foreman@test.local',
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('ИИ'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );
}
