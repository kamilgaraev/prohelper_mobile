import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../error/user_message.dart';
import '../network/api_exception.dart';
import '../storage/secure_storage_service.dart';
import '../../features/auth/data/auth_session_identity.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/modules/data/mobile_module_model.dart';
import '../../features/modules/data/modules_repository.dart';
import '../../features/projects/domain/projects_provider.dart';

enum AppModule {
  basicWarehouse,
  siteRequests,
  scheduleManagement,
  constructionJournal,
  aiAssistant,
  crm,
  tenders,
  actReporting,
  payments,
  fileManagement,
  reportTemplates,
  budgeting,
  oneCExchange,
  accessRecertification,
  rateManagement,
  systemLogs,
  budgetEstimates,
  procurement,
  contractManagement,
  designManagement,
  changeManagement,
  executiveDocumentation,
  projectManagement,
  catalogManagement,
  brigades,
  contractorMarketplace,
  videoMonitoring,
  timeTracking,
  workflowManagement,
  qualityControl,
  safetyManagement,
  machineryOperations,
  productionLabor,
  workforceManagement,
  handoverAcceptance,
}

extension AppModuleX on AppModule {
  String get backendSlug {
    return switch (this) {
      AppModule.basicWarehouse => 'basic-warehouse',
      AppModule.siteRequests => 'site-requests',
      AppModule.scheduleManagement => 'schedule-management',
      AppModule.constructionJournal => 'construction-journal',
      AppModule.aiAssistant => 'ai-assistant',
      AppModule.crm => 'crm',
      AppModule.tenders => 'tenders',
      AppModule.actReporting => 'act-reporting',
      AppModule.payments => 'payments',
      AppModule.fileManagement => 'file-management',
      AppModule.reportTemplates => 'report-templates',
      AppModule.budgeting => 'budgeting',
      AppModule.oneCExchange => 'one-c-basic-exchange',
      AppModule.accessRecertification => 'access_recertification',
      AppModule.rateManagement => 'rate-management',
      AppModule.systemLogs => 'system-logs',
      AppModule.budgetEstimates => 'budget-estimates',
      AppModule.procurement => 'procurement',
      AppModule.contractManagement => 'contract-management',
      AppModule.designManagement => 'design-management',
      AppModule.changeManagement => 'change-management',
      AppModule.executiveDocumentation => 'executive-documentation',
      AppModule.projectManagement => 'project-management',
      AppModule.catalogManagement => 'catalog-management',
      AppModule.brigades => 'brigades',
      AppModule.contractorMarketplace => 'contractor-marketplace',
      AppModule.videoMonitoring => 'video-monitoring',
      AppModule.timeTracking => 'time-tracking',
      AppModule.workflowManagement => 'workflow-management',
      AppModule.qualityControl => 'quality-control',
      AppModule.safetyManagement => 'safety-management',
      AppModule.machineryOperations => 'machinery-operations',
      AppModule.productionLabor => 'production-labor',
      AppModule.workforceManagement => 'workforce-management',
      AppModule.handoverAcceptance => 'handover-acceptance',
    };
  }

  static AppModule? fromSlug(String slug) {
    for (final module in AppModule.values) {
      if (module.backendSlug == slug) {
        return module;
      }
    }

    return null;
  }
}

const _modulesSentinel = Object();

class ModulesState {
  const ModulesState({
    this.isLoading = false,
    this.modules = const [],
    this.error,
    this.fromCache = false,
  });

  final bool isLoading;
  final List<MobileModuleModel> modules;
  final String? error;
  final bool fromCache;

  ModulesState copyWith({
    bool? isLoading,
    List<MobileModuleModel>? modules,
    Object? error = _modulesSentinel,
    bool? fromCache,
  }) {
    return ModulesState(
      isLoading: isLoading ?? this.isLoading,
      modules: modules ?? this.modules,
      error: identical(error, _modulesSentinel) ? this.error : error as String?,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class ModulesNotifier extends StateNotifier<ModulesState> {
  ModulesNotifier(
    this._repository, {
    required bool canLoad,
    this.projectId,
    this.requestTimeout = const Duration(seconds: 32),
    SecureStorageService? storage,
    AuthSessionIdentity? identity,
  }) : _storage = storage,
       _identity = identity,
       super(const ModulesState()) {
    if (canLoad) {
      loadModules();
    }
  }

  final ModulesRepository _repository;
  final int? projectId;
  final Duration requestTimeout;
  final SecureStorageService? _storage;
  final AuthSessionIdentity? _identity;
  int _requestGeneration = 0;

  Future<void> loadModules() async {
    final requestGeneration = ++_requestGeneration;
    _repository.cancelPendingFetch();
    state = state.copyWith(isLoading: true, error: null);

    final cached = await _readCached();
    if (!mounted || requestGeneration != _requestGeneration) return;
    if (cached != null) {
      state = state.copyWith(modules: cached, fromCache: true);
    }

    try {
      final modules = await _repository
          .fetchModules(projectId: projectId)
          .timeout(requestTimeout);
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        modules: modules,
        fromCache: false,
      );
      await _saveCached(modules);
    } on TimeoutException {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      _repository.cancelPendingFetch();
      state = state.copyWith(
        isLoading: false,
        modules: state.fromCache ? state.modules : const [],
        error:
            state.fromCache
                ? 'Нет связи. Показаны сохранённые разделы.'
                : UserMessage.fromError(
                  const ApiException(
                    'Сервер не ответил вовремя. Попробуйте еще раз.',
                  ),
                ),
      );
    } catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      final denied = error is ApiException && error.statusCode == 403;
      if (denied) await _removeCached();
      if (!mounted || requestGeneration != _requestGeneration) return;
      state = state.copyWith(
        isLoading: false,
        modules: denied || !state.fromCache ? const [] : state.modules,
        fromCache: denied ? false : state.fromCache,
        error:
            denied
                ? UserMessage.fromError(error)
                : state.fromCache
                ? 'Нет связи. Показаны сохранённые разделы.'
                : UserMessage.fromError(error),
      );
    }
  }

  String? get _ownerKey {
    final identity = _identity;
    if (identity == null || identity.organizationId == null) return null;
    return '${identity.userId}:${identity.organizationId}:${identity.sessionId}';
  }

  String get _scopeKey => projectId?.toString() ?? 'all';

  Future<List<MobileModuleModel>?> _readCached() async {
    if (_ownerKey == null) return null;
    try {
      final stored = await _storage?.getOfflineModules();
      if (stored == null || stored['owner'] != _ownerKey) return null;
      final scopes = stored['scopes'];
      if (scopes is! Map) return null;
      final rows = scopes[_scopeKey];
      if (rows is! List) return null;
      final modules = <MobileModuleModel>[];
      for (final row in rows) {
        if (row is! Map) continue;
        try {
          modules.add(
            MobileModuleModel.fromJson(Map<String, dynamic>.from(row)),
          );
        } catch (_) {
          continue;
        }
      }
      return modules;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCached(List<MobileModuleModel> modules) async {
    if (_ownerKey == null) return;
    try {
      final stored = await _storage?.getOfflineModules();
      final scopes =
          stored?['owner'] == _ownerKey && stored?['scopes'] is Map
              ? Map<String, dynamic>.from(stored!['scopes'] as Map)
              : <String, dynamic>{};
      scopes[_scopeKey] = [
        for (final module in modules)
          {
            'slug': module.slug,
            'title': module.title,
            'description': module.description,
            'icon': module.icon,
            'supported_on_mobile': module.supportedOnMobile,
            'order': module.order,
            'route': module.route,
            'permissions': module.permissions,
          },
      ];
      await _storage?.saveOfflineModules({
        'owner': _ownerKey,
        'scopes': scopes,
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _removeCached() async {
    if (_ownerKey == null) return;
    try {
      final stored = await _storage?.getOfflineModules();
      if (stored == null || stored['owner'] != _ownerKey) return;
      final scopes = stored['scopes'];
      if (scopes is! Map) return;
      final remaining = Map<String, dynamic>.from(scopes)..remove(_scopeKey);
      await _storage?.saveOfflineModules({
        'owner': _ownerKey,
        'scopes': remaining,
      });
    } catch (_) {
      return;
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    _repository.cancelPendingFetch();
    super.dispose();
  }
}

final modulesProvider = StateNotifierProvider<ModulesNotifier, ModulesState>((
  ref,
) {
  final authContext = ref.watch(
    authProvider.select(
      (state) => (
        isAuthenticated: state is AuthAuthenticated,
        sessionIdentity:
            state is AuthAuthenticated ? state.sessionIdentity : null,
      ),
    ),
  );
  final projectId = ref.watch(projectsProvider).selectedProject?.serverId;

  return ModulesNotifier(
    ref.read(modulesRepositoryProvider),
    canLoad: authContext.isAuthenticated,
    projectId: projectId,
    storage: ref.read(secureStorageProvider),
    identity: authContext.sessionIdentity,
  );
});

final activeModulesProvider = Provider<Set<AppModule>>((ref) {
  final modules = ref.watch(modulesProvider).modules;

  return modules
      .map((module) => AppModuleX.fromSlug(module.slug))
      .whereType<AppModule>()
      .toSet();
});

final supportedMobileModulesProvider = Provider<List<MobileModuleModel>>((ref) {
  final modules =
      ref
          .watch(modulesProvider)
          .modules
          .where(
            (module) =>
                module.supportedOnMobile &&
                AppModuleX.fromSlug(module.slug) != null,
          )
          .toList()
        ..sort((left, right) => left.order.compareTo(right.order));

  return modules;
});
