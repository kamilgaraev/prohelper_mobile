import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/controllers/dashboard_controller.dart';

void main() {
  test(
    'loadDashboard keeps last successful widgets after refresh failure',
    () async {
      final repository = _SequenceDashboardRepository([
        _DashboardResult.widgets([_widget('project_overview')]),
        _DashboardResult.error(
          const ApiException('Нет соединения с сервером.'),
        ),
      ]);
      final controller = DashboardController(repository, canLoad: false);

      await controller.loadDashboard();

      expect(controller.state.widgets.map((widget) => widget.slug), [
        'project_overview',
      ]);
      expect(controller.state.error, isNull);

      await controller.loadDashboard();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.widgets.map((widget) => widget.slug), [
        'project_overview',
      ]);
      expect(controller.state.error, 'Нет соединения с сервером.');
    },
  );

  test(
    'loadDashboard exposes error when no dashboard data exists yet',
    () async {
      final repository = _SequenceDashboardRepository([
        _DashboardResult.error(
          const ApiException('Нет соединения с сервером.'),
        ),
      ]);
      final controller = DashboardController(repository, canLoad: false);

      await controller.loadDashboard();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.widgets, isEmpty);
      expect(controller.state.error, 'Нет соединения с сервером.');
    },
  );

  test(
    'loadDashboard stops loading when the request never completes',
    () async {
      final controller = DashboardController(
        _HangingDashboardRepository(),
        canLoad: false,
        requestTimeout: const Duration(milliseconds: 10),
      );

      await controller.loadDashboard();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNotNull);
    },
  );

  test('online verification keeps the current dashboard state', () async {
    final storage = _TestSecureStorageService();
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
    final auth = _TestAuthNotifier(
      AuthAuthenticated(user, sessionIdentity: identity),
      storage,
    );
    final repository = _SequenceDashboardRepository([
      _DashboardResult.widgets([_widget('project_overview')]),
    ]);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      dashboardControllerProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
    final notifier = container.read(dashboardControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(dashboardControllerProvider).widgets, isNotEmpty);
    auth.updateAuthState(
      AuthAuthenticated(
        user,
        sessionIdentity: identity,
        isOnlineVerified: true,
      ),
    );
    await container.pump();

    expect(
      identical(container.read(dashboardControllerProvider.notifier), notifier),
      isTrue,
    );
    expect(container.read(dashboardControllerProvider).widgets, isNotEmpty);
  });
}

class _HangingDashboardRepository extends DashboardRepository {
  _HangingDashboardRepository() : super(Dio());

  @override
  Future<List<DashboardWidgetModel>> fetchWidgets() =>
      Completer<List<DashboardWidgetModel>>().future;
}

class _TestSecureStorageService extends SecureStorageService {}

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

class _SequenceDashboardRepository extends DashboardRepository {
  _SequenceDashboardRepository(this._results) : super(Dio());

  final List<_DashboardResult> _results;
  var _index = 0;

  @override
  Future<List<DashboardWidgetModel>> fetchWidgets() async {
    final result = _results[_index++];

    if (result.error != null) {
      throw result.error!;
    }

    return result.widgets;
  }
}

class _DashboardResult {
  const _DashboardResult._({this.widgets = const [], this.error});

  factory _DashboardResult.widgets(List<DashboardWidgetModel> widgets) {
    return _DashboardResult._(widgets: widgets);
  }

  factory _DashboardResult.error(Object error) {
    return _DashboardResult._(error: error);
  }

  final List<DashboardWidgetModel> widgets;
  final Object? error;
}

DashboardWidgetModel _widget(String slug) {
  return DashboardWidgetModel(
    slug: slug,
    title: slug,
    status: DashboardWidgetStatus.ok,
    primaryMetric: const DashboardMetric(label: 'Сигналы', value: 0),
    secondaryMetric: const DashboardMetric(label: 'Просрочено', value: 0),
    route: slug,
    updatedAt: DateTime(2026, 7, 3),
  );
}
