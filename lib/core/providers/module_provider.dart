import 'dart:convert';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../features/auth/domain/auth_provider.dart';

enum AppModule {
  basicWarehouse,
  siteRequests,
  scheduleManagement,
  budgetEstimates,
  timeTracking,
  workflowManagement,
}

extension AppModuleX on AppModule {
  String get backendSlug {
    return switch (this) {
      AppModule.basicWarehouse     => 'basic-warehouse',
      AppModule.siteRequests       => 'site-requests',
      AppModule.scheduleManagement => 'schedule-management',
      AppModule.budgetEstimates    => 'budget-estimates',
      AppModule.timeTracking       => 'time-tracking',
      AppModule.workflowManagement => 'workflow-management',
    };
  }

  static AppModule? fromSlug(String slug) {
    for (final module in AppModule.values) {
      if (module.backendSlug == slug) return module;
    }
    return null;
  }
}

final activeModulesProvider = Provider<Set<AppModule>>((ref) {
  final authState = ref.watch(authProvider);

  if (authState is! AuthAuthenticated) return const {};

  final permissionsJson = authState.user.permissionsJson;
  if (permissionsJson.isEmpty) return const {};

  try {
    final decoded = jsonDecode(permissionsJson);

    final Set<String> slugs;
    if (decoded is Map) {
      slugs = decoded.keys.cast<String>().toSet();
    } else if (decoded is List) {
      slugs = Set<String>.from(decoded.whereType<String>());
    } else {
      return const {};
    }

    return slugs
        .map((s) => AppModuleX.fromSlug(s))
        .whereType<AppModule>()
        .toSet();
  } catch (_) {
    return const {};
  }
});
