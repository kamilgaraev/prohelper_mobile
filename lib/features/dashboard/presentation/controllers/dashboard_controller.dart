import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/error/user_message.dart';
import 'dart:async';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:prohelpers_mobile/features/dashboard/data/dashboard_widget_model.dart';

const _dashboardSentinel = Object();

class DashboardState {
  const DashboardState({
    this.isLoading = false,
    this.widgets = const [],
    this.error,
  });

  final bool isLoading;
  final List<DashboardWidgetModel> widgets;
  final String? error;

  DashboardState copyWith({
    bool? isLoading,
    List<DashboardWidgetModel>? widgets,
    Object? error = _dashboardSentinel,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      widgets: widgets ?? this.widgets,
      error:
          identical(error, _dashboardSentinel) ? this.error : error as String?,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(
    this._repository, {
    required bool canLoad,
    this.requestTimeout = const Duration(seconds: 32),
  }) : super(const DashboardState()) {
    if (canLoad) {
      loadDashboard();
    }
  }

  final DashboardRepository _repository;
  final Duration requestTimeout;

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final widgets = await _repository.fetchWidgets().timeout(requestTimeout);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, widgets: widgets);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        widgets: state.widgets,
        error:
            error is TimeoutException
                ? 'Сервер не ответил вовремя. Попробуйте ещё раз.'
                : UserMessage.fromError(error),
      );
    }
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
      final identity = ref.watch(
        authProvider.select(
          (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
        ),
      );

      return DashboardController(
        ref.read(dashboardRepositoryProvider),
        canLoad: identity != null,
      );
    });
