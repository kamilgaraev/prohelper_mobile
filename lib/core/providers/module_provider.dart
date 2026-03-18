import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/auth/domain/auth_provider.dart';
import '../../features/modules/data/mobile_module_model.dart';
import '../../features/modules/data/modules_repository.dart';

enum AppModule {
  basicWarehouse,
  siteRequests,
  scheduleManagement,
  aiAssistant,
  budgetEstimates,
  timeTracking,
  workflowManagement,
}

extension AppModuleX on AppModule {
  String get backendSlug {
    return switch (this) {
      AppModule.basicWarehouse => 'basic-warehouse',
      AppModule.siteRequests => 'site-requests',
      AppModule.scheduleManagement => 'schedule-management',
      AppModule.aiAssistant => 'ai-assistant',
      AppModule.budgetEstimates => 'budget-estimates',
      AppModule.timeTracking => 'time-tracking',
      AppModule.workflowManagement => 'workflow-management',
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
  });

  final bool isLoading;
  final List<MobileModuleModel> modules;
  final String? error;

  ModulesState copyWith({
    bool? isLoading,
    List<MobileModuleModel>? modules,
    Object? error = _modulesSentinel,
  }) {
    return ModulesState(
      isLoading: isLoading ?? this.isLoading,
      modules: modules ?? this.modules,
      error: identical(error, _modulesSentinel) ? this.error : error as String?,
    );
  }
}

class ModulesNotifier extends StateNotifier<ModulesState> {
  ModulesNotifier(
    this._repository, {
    required bool canLoad,
  }) : super(const ModulesState()) {
    if (canLoad) {
      loadModules();
    }
  }

  final ModulesRepository _repository;

  Future<void> loadModules() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final modules = await _repository.fetchModules();
      state = state.copyWith(
        isLoading: false,
        modules: modules,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        modules: const [],
        error: error.toString(),
      );
    }
  }
}

final modulesProvider = StateNotifierProvider<ModulesNotifier, ModulesState>((ref) {
  final authState = ref.watch(authProvider);

  return ModulesNotifier(
    ref.read(modulesRepositoryProvider),
    canLoad: authState is AuthAuthenticated,
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
  final modules = ref.watch(modulesProvider).modules
      .where((module) => module.supportedOnMobile)
      .toList()
    ..sort((left, right) => left.order.compareTo(right.order));

  return modules;
});
