import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/field_catalog_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/project_participants_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/team_expansion_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/presentation/brigades_screen.dart';
import 'package:prohelpers_mobile/features/field_catalog/presentation/field_catalog_screen.dart';
import 'package:prohelpers_mobile/features/field_catalog/presentation/project_participants_screen.dart';
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
  _TestAuthRepository(SecureStorageService storage) : super(Dio(), storage);
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier()
    : super(
        _TestAuthRepository(_TestSecureStorageService()),
        _TestSecureStorageService(),
      ) {
    final user =
        User()
          ..serverId = 1
          ..email = 'test@example.test'
          ..name = 'Test'
          ..organizationsJson = '[]'
          ..currentOrganizationId = 4;
    state = AuthAuthenticated(
      user,
      sessionIdentity: const AuthSessionIdentity(
        userId: 1,
        organizationId: 4,
        sessionId: 'test-session',
      ),
    );
  }

  @override
  Future<void> checkAuth() async {}

  void switchOwner(int userId) {
    final user =
        User()
          ..serverId = userId
          ..email = 'user$userId@example.test'
          ..name = 'Test $userId'
          ..organizationsJson = '[]'
          ..currentOrganizationId = 4;
    state = AuthAuthenticated(
      user,
      sessionIdentity: AuthSessionIdentity(
        userId: userId,
        organizationId: 4,
        sessionId: 'test-session-$userId',
      ),
    );
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier() : super(_TestProjectsRepository()) {
    final project =
        Project()
          ..serverId = 9
          ..name = 'Башня';
    state = ProjectsState(projects: [project], selectedProject: project);
  }
}

FieldCatalogPage _fieldPage(String title) => FieldCatalogPage(
  items: [FieldCatalogEntry(uuid: 'row-1', title: title, fields: const {})],
  currentPage: 1,
  lastPage: 2,
  total: 1,
);

FieldCatalogPage _fieldNextPage(String title) => FieldCatalogPage(
  items: [FieldCatalogEntry(uuid: 'row-2', title: title, fields: const {})],
  currentPage: 2,
  lastPage: 2,
  total: 2,
);

class _FieldCatalogRepository extends FieldCatalogRepository {
  _FieldCatalogRepository(this.responses) : super(Dio());

  final List<Object> responses;

  @override
  Future<FieldCatalogPage> fetchPage({
    required String catalog,
    String? apiPrefix,
    String? entity,
    String? query,
    String queryParameter = 'q',
    int? projectId,
    int page = 1,
    int perPage = 20,
    Map<String, Object?> extraQueryParameters = const {},
  }) async {
    final response = responses.removeAt(0);
    if (response is Completer<FieldCatalogPage>) return response.future;
    if (response is! FieldCatalogPage) throw response;
    return response;
  }
}

class _TeamExpansionRepository extends TeamExpansionRepository {
  _TeamExpansionRepository(this.responses) : super(Dio());

  final List<Object> responses;

  @override
  Future<FieldCatalogPage> fetchPage({
    required String path,
    Map<String, Object?> filters = const {},
    int page = 1,
    int perPage = 20,
  }) async {
    final response = responses.removeAt(0);
    if (response is Completer<FieldCatalogPage>) return response.future;
    if (response is! FieldCatalogPage) throw response;
    return response;
  }
}

class _ParticipantsRepository extends ProjectParticipantsRepository {
  _ParticipantsRepository(this.responses) : super(Dio());

  final List<Object> responses;

  @override
  Future<ProjectParticipantsPage> fetchPage({
    required int projectId,
    String? query,
    bool availableUsers = false,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = responses.removeAt(0);
    if (response is Completer<ProjectParticipantsPage>) return response.future;
    if (response is! ProjectParticipantsPage) {
      throw response;
    }
    return response;
  }
}

void main() {
  Widget buildApp(
    Widget screen, {
    List<Override> repositoryOverrides = const [],
    _TestAuthNotifier? authNotifier,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => authNotifier ?? _TestAuthNotifier()),
        projectsProvider.overrideWith((ref) => _TestProjectsNotifier()),
        permissionServiceProvider.overrideWithValue(
          PermissionService(
            context: UserContext.office,
            activeModules: const <AppModule>{},
            grantedPermissions: const {'*'},
          ),
        ),
        ...repositoryOverrides,
      ],
      child: MaterialApp(home: screen),
    );
  }

  testWidgets('field catalog keeps previous page after offline search', (
    tester,
  ) async {
    final repository = _FieldCatalogRepository([
      _fieldPage('Сохранённая запись'),
      const ApiException('Нет соединения'),
      const ApiException('Нет доступа', statusCode: 403),
    ]);
    await tester.pumpWidget(
      buildApp(
        const FieldCatalogScreen(
          title: 'Тендеры',
          catalog: 'tenders',
          icon: Icons.list,
        ),
        repositoryOverrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'новый запрос');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Сохранённая запись'), findsOneWidget);
    expect(
      find.textContaining('может не учитывать текущий поиск'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Обновить список'));
    await tester.pumpAndSettle();
    expect(find.text('Сохранённая запись'), findsNothing);
    expect(find.text('Раздел недоступен'), findsOneWidget);
  });

  testWidgets('brigade catalog keeps previous page after offline search', (
    tester,
  ) async {
    final repository = _TeamExpansionRepository([
      _fieldPage('Сохранённая бригада'),
      const ApiException('Нет соединения'),
      const ApiException('Нет доступа', statusCode: 403),
    ]);
    await tester.pumpWidget(
      buildApp(
        const BrigadesScreen(),
        repositoryOverrides: [
          teamExpansionRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'новый запрос');
    await tester.pumpAndSettle();

    expect(find.text('Сохранённая бригада'), findsOneWidget);
    expect(
      find.textContaining('может не учитывать текущий поиск'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Обновить список'));
    await tester.pumpAndSettle();
    expect(find.text('Сохранённая бригада'), findsNothing);
    expect(find.text('Не удалось загрузить список'), findsOneWidget);
  });

  testWidgets('project participants keep previous page after offline search', (
    tester,
  ) async {
    final repository = _ParticipantsRepository([
      const ProjectParticipantsPage(
        items: [
          ProjectParticipant(
            id: 1,
            name: 'Сохранённый участник',
            email: 'one@example.test',
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      ),
      const ApiException('Нет соединения'),
      const ApiException('Нет доступа', statusCode: 403),
    ]);
    await tester.pumpWidget(
      buildApp(
        const ProjectParticipantsScreen(),
        repositoryOverrides: [
          projectParticipantsRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'новый запрос');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Сохранённый участник'), findsOneWidget);
    expect(
      find.textContaining('может не учитывать текущий поиск'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Обновить список'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Сохранённый участник'), findsNothing);
    expect(find.text('Не удалось загрузить участников'), findsOneWidget);
  });

  testWidgets('field catalog ignores append started before a new search', (
    tester,
  ) async {
    final append = Completer<FieldCatalogPage>();
    final repository = _FieldCatalogRepository([
      _fieldPage('Старая запись'),
      append,
      const ApiException('Нет соединения'),
    ]);
    await tester.pumpWidget(
      buildApp(
        const FieldCatalogScreen(
          title: 'Тендеры',
          catalog: 'tenders',
          icon: Icons.list,
        ),
        repositoryOverrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'новый поиск');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    append.complete(_fieldNextPage('Чужой старый append'));
    await tester.pumpAndSettle();

    expect(find.text('Старая запись'), findsOneWidget);
    expect(find.text('Чужой старый append'), findsNothing);
  });

  testWidgets('brigade catalog ignores append started before a new search', (
    tester,
  ) async {
    final append = Completer<FieldCatalogPage>();
    final repository = _TeamExpansionRepository([
      _fieldPage('Старая бригада'),
      append,
      const ApiException('Нет соединения'),
    ]);
    await tester.pumpWidget(
      buildApp(
        const BrigadesScreen(),
        repositoryOverrides: [
          teamExpansionRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'новый поиск');
    await tester.pumpAndSettle();
    append.complete(_fieldNextPage('Чужой старый append'));
    await tester.pumpAndSettle();

    expect(find.text('Старая бригада'), findsOneWidget);
    expect(find.text('Чужой старый append'), findsNothing);
  });

  testWidgets('participants ignore append started before a new search', (
    tester,
  ) async {
    final append = Completer<ProjectParticipantsPage>();
    const firstPage = ProjectParticipantsPage(
      items: [
        ProjectParticipant(
          id: 1,
          name: 'Старый участник',
          email: 'one@example.test',
        ),
      ],
      currentPage: 1,
      lastPage: 2,
      total: 2,
    );
    const nextPage = ProjectParticipantsPage(
      items: [
        ProjectParticipant(
          id: 2,
          name: 'Чужой старый append',
          email: 'two@example.test',
        ),
      ],
      currentPage: 2,
      lastPage: 2,
      total: 2,
    );
    final repository = _ParticipantsRepository([
      firstPage,
      append,
      const ApiException('Нет соединения'),
    ]);
    await tester.pumpWidget(
      buildApp(
        const ProjectParticipantsScreen(),
        repositoryOverrides: [
          projectParticipantsRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'новый поиск');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    append.complete(nextPage);
    await tester.pumpAndSettle();

    expect(find.text('Старый участник'), findsOneWidget);
    expect(find.text('Чужой старый append'), findsNothing);
  });

  testWidgets('field catalog reloads and rejects old owner response', (
    tester,
  ) async {
    final oldOwnerRequest = Completer<FieldCatalogPage>();
    final auth = _TestAuthNotifier();
    final repository = _FieldCatalogRepository([
      oldOwnerRequest,
      _fieldPage('Запись нового владельца'),
    ]);
    await tester.pumpWidget(
      buildApp(
        const FieldCatalogScreen(
          title: 'Тендеры',
          catalog: 'tenders',
          icon: Icons.list,
        ),
        authNotifier: auth,
        repositoryOverrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pump();
    auth.switchOwner(2);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Запись нового владельца'), findsOneWidget);
    oldOwnerRequest.complete(_fieldPage('Запись прошлого владельца'));
    await tester.pumpAndSettle();

    expect(find.text('Запись прошлого владельца'), findsNothing);
    expect(find.text('Запись нового владельца'), findsOneWidget);
  });

  testWidgets('hard pagination failures clear retained field catalog rows', (
    tester,
  ) async {
    final repository = _FieldCatalogRepository([
      _fieldPage('Запись до отказа'),
      const ApiException('Нет доступа', statusCode: 403),
    ]);
    await tester.pumpWidget(
      buildApp(
        const FieldCatalogScreen(
          title: 'Тендеры',
          catalog: 'tenders',
          icon: Icons.list,
        ),
        repositoryOverrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();

    expect(find.text('Запись до отказа'), findsNothing);
  });

  testWidgets('hard pagination failures clear retained brigade rows', (
    tester,
  ) async {
    final repository = _TeamExpansionRepository([
      _fieldPage('Бригада до отказа'),
      const ApiException('Нет доступа', statusCode: 403),
    ]);
    await tester.pumpWidget(
      buildApp(
        const BrigadesScreen(),
        repositoryOverrides: [
          teamExpansionRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();

    expect(find.text('Бригада до отказа'), findsNothing);
  });

  testWidgets('hard pagination failures clear retained participant rows', (
    tester,
  ) async {
    final repository = _ParticipantsRepository([
      const ProjectParticipantsPage(
        items: [
          ProjectParticipant(
            id: 1,
            name: 'Участник до отказа',
            email: 'one@example.test',
          ),
        ],
        currentPage: 1,
        lastPage: 2,
        total: 2,
      ),
      const ApiException('Нет доступа', statusCode: 403),
    ]);
    await tester.pumpWidget(
      buildApp(
        const ProjectParticipantsScreen(),
        repositoryOverrides: [
          projectParticipantsRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Участник до отказа'), findsNothing);
  });
}
