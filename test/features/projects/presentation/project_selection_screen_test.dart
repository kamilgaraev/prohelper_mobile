import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';

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
  _TestAuthNotifier(User user)
    : super(_TestAuthRepository(), _TestSecureStorageService()) {
    state = AuthAuthenticated(user);
  }

  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    state = AuthUnauthenticated();
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository({this.projects = const [], this.failure})
    : super(Dio());

  final List<Project> projects;
  final Object? failure;
  int fetchCalls = 0;

  @override
  Future<List<Project>> fetchProjects() async {
    fetchCalls += 1;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return projects;
  }
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier._(this.repository, {ProjectsState? initialState})
    : super(repository) {
    if (initialState != null) {
      state = initialState;
    }
  }

  factory _TestProjectsNotifier.loaded(Project project) {
    return _TestProjectsNotifier._(
      _TestProjectsRepository(projects: [project]),
      initialState: ProjectsState(
        hasLoaded: true,
        projects: [project],
        selectedProject: project,
      ),
    );
  }

  factory _TestProjectsNotifier.pending({
    List<Project> projects = const [],
    Object? failure,
  }) {
    return _TestProjectsNotifier._(
      _TestProjectsRepository(projects: projects, failure: failure),
    );
  }

  final _TestProjectsRepository repository;
  int loadCalls = 0;

  @override
  Future<void> loadProjects() async {
    loadCalls += 1;
    await super.loadProjects();
  }
}

void main() {
  late _TestAuthNotifier authNotifier;
  late _TestProjectsNotifier projectsNotifier;

  ProviderScope buildScope({
    required Widget child,
    _TestProjectsNotifier? projectState,
  }) {
    authNotifier = _TestAuthNotifier(_user());
    projectsNotifier = projectState ?? _TestProjectsNotifier.loaded(_project());

    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => authNotifier),
        projectsProvider.overrideWith((ref) => projectsNotifier),
      ],
      child: child,
    );
  }

  Widget buildScreen({_TestProjectsNotifier? projectState}) {
    return buildScope(
      projectState: projectState,
      child: MaterialApp(
        theme: MostTheme.lightTheme,
        home: const ProjectSelectionScreen(),
      ),
    );
  }

  Widget buildRoutedScreen() {
    return buildScope(
      child: MaterialApp(
        theme: MostTheme.lightTheme,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProjectSelectionScreen(),
                        ),
                      );
                    },
                    child: const Text('Открыть выбор объекта'),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  testWidgets('кнопка выхода на выборе объекта имеет понятную подпись', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final logoutIcon = tester.widget<Icon>(find.byIcon(Icons.logout_rounded));
    final logoutButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.logout_rounded),
        matching: find.byType(IconButton),
      ),
    );

    expect(logoutIcon.semanticLabel, 'Выйти из аккаунта');
    expect(logoutButton.tooltip, 'Выйти из аккаунта');
  });

  testWidgets('кнопка обновления объектов имеет понятную подпись', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final refreshIcon = tester.widget<Icon>(find.byIcon(Icons.refresh_rounded));
    final refreshButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.refresh_rounded),
        matching: find.byType(IconButton),
      ),
    );

    expect(refreshIcon.semanticLabel, 'Обновить список объектов');
    expect(refreshButton.tooltip, 'Обновить список объектов');
  });

  testWidgets('выход с выбора объекта требует подтверждения', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();

    expect(authNotifier.logoutCalls, 0);
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    expect(find.text('Остаться'), findsOneWidget);

    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();

    expect(authNotifier.logoutCalls, 0);
    expect(find.text('Выйти из аккаунта?'), findsNothing);

    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();

    expect(authNotifier.logoutCalls, 1);
  });

  testWidgets('выбор объекта из отдельного маршрута возвращает назад', (
    tester,
  ) async {
    await tester.pumpWidget(buildRoutedScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Открыть выбор объекта'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите объект для работы'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsNothing);

    await tester.tap(find.text('Строительство склада Литер А'));
    await tester.pumpAndSettle();

    expect(projectsNotifier.state.selectedProject?.serverId, 15);
    expect(find.text('Открыть выбор объекта'), findsOneWidget);
    expect(find.text('Выберите объект для работы'), findsNothing);
  });

  testWidgets('пустой список загружается один раз и дает ручное обновление', (
    tester,
  ) async {
    final notifier = _TestProjectsNotifier.pending();

    await tester.pumpWidget(buildScreen(projectState: notifier));
    await tester.pumpAndSettle();

    expect(notifier.loadCalls, 1);
    expect(notifier.repository.fetchCalls, 1);
    expect(find.text('Нет доступных объектов'), findsOneWidget);
    expect(find.text('Обновить список'), findsOneWidget);

    await tester.pump();

    expect(notifier.loadCalls, 1);
    expect(notifier.repository.fetchCalls, 1);

    await tester.tap(find.text('Обновить список'));
    await tester.pumpAndSettle();

    expect(notifier.loadCalls, 2);
    expect(notifier.repository.fetchCalls, 2);
  });

  testWidgets('ошибка загрузки проекта не показывает технический текст', (
    tester,
  ) async {
    final notifier = _TestProjectsNotifier.pending(
      failure: Exception('DioException payload constraint'),
    );

    await tester.pumpWidget(buildScreen(projectState: notifier));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить объекты'), findsOneWidget);
    expect(
      find.text('Не удалось выполнить действие. Попробуйте еще раз.'),
      findsOneWidget,
    );
    final headerBottom = tester.getBottomLeft(find.text('Объект не выбран')).dy;
    final errorTop =
        tester.getTopLeft(find.text('Не удалось загрузить объекты')).dy;
    expect(errorTop - headerBottom, lessThan(140));
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('payload'), findsNothing);
  });

  testWidgets('карточка объекта имеет единое доступное действие', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const expectedLabel =
        'Выбранный объект. Строительство склада Литер А. '
        'Адрес: 420054, Респ Татарстан, г Казань. Роль: Владелец';

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.bySemanticsLabel(expectedLabel));
    final data = node.getSemanticsData();

    expect(data.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(
      node,
      matchesSemantics(
        label: expectedLabel,
        hasEnabledState: true,
        isEnabled: true,
        isSelected: true,
        isButton: true,
        hasTapAction: true,
      ),
    );

    semantics.dispose();
  });
}

User _user() {
  return User()
    ..serverId = 1
    ..email = 'foreman@test.local'
    ..name = 'Иван Иванов'
    ..currentOrganizationId = 10
    ..organizationName = 'СТРОЙ-ТУР'
    ..organizationsJson = '[{"id":10,"name":"СТРОЙ-ТУР"}]'
    ..roles = ['owner']
    ..permissionsJson = '{}';
}

Project _project() {
  return Project()
    ..serverId = 15
    ..name = 'Строительство склада Литер А'
    ..address = '420054, Респ Татарстан, г Казань'
    ..myRole = 'Владелец';
}
