import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

void main() {
  test('parses every supported backend module slug', () {
    const supportedSlugs = {
      'basic-warehouse': AppModule.basicWarehouse,
      'site-requests': AppModule.siteRequests,
      'schedule-management': AppModule.scheduleManagement,
      'construction-journal': AppModule.constructionJournal,
      'ai-assistant': AppModule.aiAssistant,
      'budget-estimates': AppModule.budgetEstimates,
      'procurement': AppModule.procurement,
      'contract-management': AppModule.contractManagement,
      'change-management': AppModule.changeManagement,
      'executive-documentation': AppModule.executiveDocumentation,
      'project-management': AppModule.projectManagement,
      'catalog-management': AppModule.catalogManagement,
      'brigades': AppModule.brigades,
      'video-monitoring': AppModule.videoMonitoring,
      'time-tracking': AppModule.timeTracking,
      'workflow-management': AppModule.workflowManagement,
      'quality-control': AppModule.qualityControl,
      'safety-management': AppModule.safetyManagement,
      'machinery-operations': AppModule.machineryOperations,
      'production-labor': AppModule.productionLabor,
      'workforce-management': AppModule.workforceManagement,
      'handover-acceptance': AppModule.handoverAcceptance,
    };

    for (final entry in supportedSlugs.entries) {
      expect(AppModuleX.fromSlug(entry.key), entry.value);
      expect(entry.value.backendSlug, entry.key);
    }
  });

  test('ignores unknown backend module slugs', () {
    expect(AppModuleX.fromSlug('unknown-module'), isNull);
  });

  test(
    'turns a hung module load into a retryable error and cancels it',
    () async {
      final repository = _PendingModulesRepository();
      final notifier = ModulesNotifier(
        repository,
        canLoad: true,
        requestTimeout: const Duration(milliseconds: 5),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.modules, isEmpty);
      expect(
        notifier.state.error,
        'Сервер не ответил вовремя. Попробуйте еще раз.',
      );
      expect(repository.fetchCount, 1);
      expect(repository.cancelCount, 1);

      final retry = notifier.loadModules();
      expect(notifier.state.isLoading, isTrue);
      expect(notifier.state.error, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(repository.fetchCount, 2);

      notifier.dispose();
      await retry;

      expect(repository.cancelCount, 2);
    },
  );

  test('repository cancellation stops a pending modules request', () async {
    final adapter = _PendingRequestAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final repository = ModulesRepository(dio);

    final fetch = repository.fetchModules(projectId: 42);
    await adapter.fetchStarted.future.timeout(const Duration(seconds: 1));
    repository.cancelPendingFetch();

    await expectLater(fetch, throwsA(isA<Exception>()));
    expect(adapter.wasCancelled, isTrue);
  });

  test('restores only the current owner and project modules offline', () async {
    final storage = _MemoryModulesStorage();
    const owner = AuthSessionIdentity(
      userId: 1,
      organizationId: 10,
      sessionId: 'session-1',
    );
    const otherOwner = AuthSessionIdentity(
      userId: 2,
      organizationId: 10,
      sessionId: 'session-2',
    );
    const modules = [
      MobileModuleModel(
        slug: 'quality-control',
        title: 'Контроль качества',
        description: 'Замечания',
        icon: 'quality',
        supportedOnMobile: true,
        order: 1,
      ),
    ];
    final online = ModulesNotifier(
      _ConfiguredModulesRepository(modules),
      canLoad: false,
      projectId: 42,
      storage: storage,
      identity: owner,
    );
    await online.loadModules();
    expect(online.state.fromCache, isFalse);
    online.dispose();

    final offlineRepository = _ConfiguredModulesRepository(
      const [],
      failure: const ApiException('Нет связи.'),
    );
    final offline = ModulesNotifier(
      offlineRepository,
      canLoad: false,
      projectId: 42,
      storage: storage,
      identity: owner,
    );
    await offline.loadModules();
    expect(offline.state.modules.single.slug, 'quality-control');
    expect(offline.state.fromCache, isTrue);
    offline.dispose();

    for (final scope in [
      (identity: owner, projectId: 43),
      (identity: otherOwner, projectId: 42),
    ]) {
      final isolated = ModulesNotifier(
        offlineRepository,
        canLoad: false,
        projectId: scope.projectId,
        storage: storage,
        identity: scope.identity,
      );
      await isolated.loadModules();
      expect(isolated.state.modules, isEmpty);
      isolated.dispose();
    }
  });

  test('removes cached modules after access is denied', () async {
    final storage = _MemoryModulesStorage();
    const owner = AuthSessionIdentity(
      userId: 1,
      organizationId: 10,
      sessionId: 'session-1',
    );
    final online = ModulesNotifier(
      _ConfiguredModulesRepository(const [
        MobileModuleModel(
          slug: 'quality-control',
          title: 'Контроль качества',
          description: 'Замечания',
          icon: 'quality',
          supportedOnMobile: true,
          order: 1,
        ),
      ]),
      canLoad: false,
      projectId: 42,
      storage: storage,
      identity: owner,
    );
    await online.loadModules();
    online.dispose();

    final denied = ModulesNotifier(
      _ConfiguredModulesRepository(
        const [],
        failure: const ApiException('Нет доступа.', statusCode: 403),
      ),
      canLoad: false,
      projectId: 42,
      storage: storage,
      identity: owner,
    );
    await denied.loadModules();
    expect(denied.state.modules, isEmpty);
    expect(denied.state.fromCache, isFalse);
    denied.dispose();

    final offline = ModulesNotifier(
      _ConfiguredModulesRepository(
        const [],
        failure: const ApiException('Нет связи.'),
      ),
      canLoad: false,
      projectId: 42,
      storage: storage,
      identity: owner,
    );
    await offline.loadModules();
    expect(offline.state.modules, isEmpty);
    offline.dispose();
  });

  test('online verification keeps the loaded modules', () async {
    final user =
        User()
          ..serverId = 1
          ..email = 'worker@test.local'
          ..name = 'Worker'
          ..currentOrganizationId = 10;
    const identity = AuthSessionIdentity(
      userId: 1,
      organizationId: 10,
      sessionId: 'session-1',
    );
    final storage = _TestSecureStorageService();
    final auth = _TestAuthNotifier(
      AuthAuthenticated(user, sessionIdentity: identity),
      storage,
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        projectsProvider.overrideWith(
          (ref) => ProjectsNotifier(ProjectsRepository(Dio())),
        ),
        modulesRepositoryProvider.overrideWithValue(_StaticModulesRepository()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(modulesProvider, (_, __) {});
    addTearDown(subscription.close);
    final notifier = container.read(modulesProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(modulesProvider).modules, isNotEmpty);
    auth.updateAuthState(
      AuthAuthenticated(
        user,
        sessionIdentity: identity,
        isOnlineVerified: true,
      ),
    );
    await container.pump();

    expect(
      identical(container.read(modulesProvider.notifier), notifier),
      isTrue,
    );
    expect(container.read(modulesProvider).modules, isNotEmpty);
  });
}

class _StaticModulesRepository extends ModulesRepository {
  _StaticModulesRepository() : super(Dio());

  @override
  Future<List<MobileModuleModel>> fetchModules({int? projectId}) async =>
      const [
        MobileModuleModel(
          slug: 'quality-control',
          title: 'Контроль качества',
          description: 'Замечания',
          icon: 'quality',
          supportedOnMobile: true,
          order: 1,
          route: 'quality-control',
        ),
      ];
}

class _TestSecureStorageService extends SecureStorageService {}

class _MemoryModulesStorage extends SecureStorageService {
  Map<String, dynamic>? value;

  @override
  Future<Map<String, dynamic>?> getOfflineModules() async => value;

  @override
  Future<void> saveOfflineModules(Map<String, dynamic> next) async {
    value = next;
  }
}

class _ConfiguredModulesRepository extends ModulesRepository {
  _ConfiguredModulesRepository(this.modules, {this.failure}) : super(Dio());

  final List<MobileModuleModel> modules;
  final ApiException? failure;

  @override
  Future<List<MobileModuleModel>> fetchModules({int? projectId}) async {
    if (failure != null) throw failure!;
    return modules;
  }
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

class _PendingModulesRepository extends ModulesRepository {
  _PendingModulesRepository() : super(Dio());

  final Completer<List<MobileModuleModel>> _pending =
      Completer<List<MobileModuleModel>>();
  var fetchCount = 0;
  var cancelCount = 0;
  var _isActive = false;

  @override
  Future<List<MobileModuleModel>> fetchModules({int? projectId}) {
    fetchCount++;
    _isActive = true;
    return _pending.future;
  }

  @override
  void cancelPendingFetch() {
    if (_isActive) {
      cancelCount++;
      _isActive = false;
    }
  }
}

class _PendingRequestAdapter implements HttpClientAdapter {
  final Completer<void> fetchStarted = Completer<void>();
  var wasCancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchStarted.complete();
    await requestStream?.drain<void>();
    if (cancelFuture == null) {
      throw StateError('Expected a request cancellation future.');
    }
    await cancelFuture;
    wasCancelled = true;
    throw DioException(requestOptions: options, type: DioExceptionType.cancel);
  }

  @override
  void close({bool force = false}) {}
}
