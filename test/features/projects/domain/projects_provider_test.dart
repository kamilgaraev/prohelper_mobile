import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _TestSecureStorageService extends SecureStorageService {
  @override
  Future<int?> getSelectedProjectId() async => null;

  @override
  Future<Map<String, dynamic>?> getOfflineProjects() async => null;
}

class _MemoryProjectsStorage extends SecureStorageService {
  Map<String, dynamic>? cachedProjects;

  @override
  Future<int?> getSelectedProjectId() async => 42;

  @override
  Future<Map<String, dynamic>?> getOfflineProjects() async => cachedProjects;

  @override
  Future<void> saveOfflineProjects(Map<String, dynamic> value) async {
    cachedProjects = value;
  }
}

class _AvailableProjectsRepository extends ProjectsRepository {
  _AvailableProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => [
    Project()
      ..serverId = 42
      ..name = 'Объект 42',
  ];
}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository(SecureStorageService storage) : super(Dio(), storage);
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(
    AuthAuthenticated initialState,
    SecureStorageService storage,
  ) : super(_TestAuthRepository(storage), storage, autoCheckAuth: false) {
    state = initialState;
  }

  void updateAuthState(AuthAuthenticated next) {
    state = next;
  }
}

class _FailingProjectsRepository extends ProjectsRepository {
  _FailingProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async {
    throw Exception('offline');
  }
}

void main() {
  test(
    'selected project is restored offline for the same session only',
    () async {
      final storage = _MemoryProjectsStorage();
      final online = ProjectsNotifier(
        _AvailableProjectsRepository(),
        storage: storage,
        identity: _identity(),
      );
      await online.loadProjects();
      expect(online.state.selectedProject?.serverId, 42);
      expect(online.state.fromCache, isFalse);
      online.dispose();

      final offline = ProjectsNotifier(
        _FailingProjectsRepository(),
        storage: storage,
        identity: _identity(),
      );
      await offline.loadProjects();
      expect(offline.state.selectedProject?.serverId, 42);
      expect(offline.state.fromCache, isTrue);
      expect(offline.state.error, contains('сохранённые объекты'));
      offline.dispose();

      final otherUser = ProjectsNotifier(
        _FailingProjectsRepository(),
        storage: storage,
        identity: const AuthSessionIdentity(
          userId: 2,
          organizationId: 10,
          sessionId: 'session-1',
        ),
      );
      await otherUser.loadProjects();
      expect(otherUser.state.selectedProject, isNull);
      expect(otherUser.state.fromCache, isFalse);
      otherUser.dispose();

      for (final identity in <AuthSessionIdentity>[
        const AuthSessionIdentity(
          userId: 1,
          organizationId: 11,
          sessionId: 'session-1',
        ),
        const AuthSessionIdentity(
          userId: 1,
          organizationId: 10,
          sessionId: 'session-2',
        ),
      ]) {
        final otherScope = ProjectsNotifier(
          _FailingProjectsRepository(),
          storage: storage,
          identity: identity,
        );
        await otherScope.loadProjects();
        expect(otherScope.state.selectedProject, isNull);
        expect(otherScope.state.fromCache, isFalse);
        otherScope.dispose();
      }
    },
  );

  test(
    'online verification preserves projects error for the same identity',
    () async {
      final user = _user();
      final storage = _TestSecureStorageService();
      final auth = _TestAuthNotifier(
        AuthAuthenticated(user, sessionIdentity: _identity()),
        storage,
      );
      final container = _createContainer(auth, storage);
      addTearDown(container.dispose);
      final subscription = container.listen(projectsProvider, (_, __) {});
      addTearDown(subscription.close);

      final notifier = container.read(projectsProvider.notifier);
      await notifier.loadProjects();
      expect(container.read(projectsProvider).error, isNotNull);

      auth.updateAuthState(
        AuthAuthenticated(
          user,
          sessionIdentity: _identity(),
          isOnlineVerified: true,
        ),
      );
      await container.pump();

      expect(
        identical(container.read(projectsProvider.notifier), notifier),
        isTrue,
      );
      expect(container.read(projectsProvider).error, isNotNull);
      expect(container.read(projectsProvider).hasLoaded, isTrue);

      auth.updateAuthState(
        AuthAuthenticated(
          user,
          sessionIdentity: _identity(),
          isOnlineVerified: false,
        ),
      );
      await container.pump();

      expect(
        identical(container.read(projectsProvider.notifier), notifier),
        isTrue,
      );
      expect(container.read(projectsProvider).error, isNotNull);
    },
  );

  test(
    'projects state resets when user, organization, or session changes',
    () async {
      final user = _user();
      final storage = _TestSecureStorageService();
      final auth = _TestAuthNotifier(
        AuthAuthenticated(user, sessionIdentity: _identity()),
        storage,
      );
      final container = _createContainer(auth, storage);
      addTearDown(container.dispose);
      final subscription = container.listen(projectsProvider, (_, __) {});
      addTearDown(subscription.close);

      var currentNotifier = container.read(projectsProvider.notifier);
      for (final identity in <AuthSessionIdentity>[
        const AuthSessionIdentity(
          userId: 1,
          organizationId: 10,
          sessionId: 'session-2',
        ),
        const AuthSessionIdentity(
          userId: 1,
          organizationId: 11,
          sessionId: 'session-2',
        ),
        const AuthSessionIdentity(
          userId: 2,
          organizationId: 11,
          sessionId: 'session-2',
        ),
      ]) {
        await currentNotifier.loadProjects();
        expect(container.read(projectsProvider).error, isNotNull);

        auth.updateAuthState(
          AuthAuthenticated(user, sessionIdentity: identity),
        );
        await container.pump();

        final nextNotifier = container.read(projectsProvider.notifier);
        expect(identical(nextNotifier, currentNotifier), isFalse);
        expect(container.read(projectsProvider).error, isNull);
        expect(container.read(projectsProvider).hasLoaded, isFalse);
        currentNotifier = nextNotifier;
      }
    },
  );
}

ProviderContainer _createContainer(
  _TestAuthNotifier auth,
  SecureStorageService storage,
) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith((ref) => auth),
      projectsRepositoryProvider.overrideWithValue(
        _FailingProjectsRepository(),
      ),
      secureStorageProvider.overrideWith((ref) => storage),
    ],
  );
}

AuthSessionIdentity _identity() => const AuthSessionIdentity(
  userId: 1,
  organizationId: 10,
  sessionId: 'session-1',
);

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
