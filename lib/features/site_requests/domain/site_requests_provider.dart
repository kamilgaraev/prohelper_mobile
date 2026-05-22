import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/site_request_model.dart';
import '../data/site_requests_repository.dart';
import 'site_requests_scope.dart';

const _siteRequestsSentinel = Object();

class SiteRequestsState {
  final bool isLoading;
  final List<SiteRequestModel> requests;
  final int currentPage;
  final bool hasMore;
  final bool permissionDenied;
  final String? error;
  final String? statusFilter;
  final int? projectFilter;
  final SiteRequestsScope scope;

  SiteRequestsState({
    this.isLoading = false,
    this.requests = const [],
    this.currentPage = 1,
    this.hasMore = true,
    this.permissionDenied = false,
    this.error,
    this.statusFilter,
    this.projectFilter,
    this.scope = SiteRequestsScope.own,
  });

  SiteRequestsState copyWith({
    bool? isLoading,
    List<SiteRequestModel>? requests,
    int? currentPage,
    bool? hasMore,
    bool? permissionDenied,
    Object? error = _siteRequestsSentinel,
    String? statusFilter,
    int? projectFilter,
    SiteRequestsScope? scope,
    bool clearStatusFilter = false,
    bool clearProjectFilter = false,
  }) {
    return SiteRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      error:
          identical(error, _siteRequestsSentinel)
              ? this.error
              : error as String?,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      projectFilter:
          clearProjectFilter ? null : (projectFilter ?? this.projectFilter),
      scope: scope ?? this.scope,
    );
  }
}

final siteRequestsProvider =
    StateNotifierProvider<SiteRequestsNotifier, SiteRequestsState>((ref) {
      ref.watch(authProvider);
      final selectedProject = ref.watch(projectsProvider).selectedProject;
      return SiteRequestsNotifier(
        ref.read(siteRequestsRepositoryProvider),
        initialProjectId: selectedProject?.serverId,
      );
    });

class SiteRequestsNotifier extends StateNotifier<SiteRequestsState> {
  SiteRequestsNotifier(
    this._repository, {
    int? initialProjectId,
    SiteRequestsScope initialScope = SiteRequestsScope.own,
  }) : super(
         SiteRequestsState(
           projectFilter: initialProjectId,
           scope: initialScope,
         ),
       );

  final SiteRequestsRepository _repository;

  Future<void> loadRequests({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    if (refresh) {
      state = state.copyWith(
        isLoading: true,
        permissionDenied: false,
        error: null,
        currentPage: 1,
        hasMore: true,
        requests: [],
      );
    } else {
      state = state.copyWith(
        isLoading: true,
        permissionDenied: false,
        error: null,
      );
    }

    try {
      final newRequests = await _repository.fetchSiteRequests(
        page: state.currentPage,
        status: state.statusFilter,
        projectId: state.projectFilter,
        scope: state.scope,
      );

      state = state.copyWith(
        isLoading: false,
        requests: [...state.requests, ...newRequests],
        currentPage: state.currentPage + 1,
        hasMore: newRequests.isNotEmpty,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        error: _errorMessage(error),
      );
    }
  }

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(
      projectFilter: projectId,
      clearProjectFilter: projectId == null,
      requests: [],
      currentPage: 1,
      hasMore: true,
      error: null,
      permissionDenied: false,
    );
  }

  void syncScope(SiteRequestsScope scope) {
    if (state.scope == scope) {
      return;
    }

    state = state.copyWith(
      scope: scope,
      requests: [],
      currentPage: 1,
      hasMore: true,
      error: null,
      permissionDenied: false,
      clearStatusFilter: true,
    );
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
    );
    loadRequests(refresh: true);
  }

  void setProjectFilter(int? projectId) {
    state = state.copyWith(
      projectFilter: projectId,
      clearProjectFilter: projectId == null,
    );
    loadRequests(refresh: true);
  }

  Future<void> changeStatus(
    int requestId,
    String status, {
    String? notes,
  }) async {
    try {
      final updatedRequest = await _repository.changeSiteRequestStatus(
        requestId,
        status,
        notes: notes,
      );

      final nextRequests = [...state.requests];
      final index = nextRequests.indexWhere(
        (request) => request.serverId == requestId,
      );

      if (index != -1) {
        if (state.scope == SiteRequestsScope.approvals &&
            updatedRequest.status != 'pending' &&
            updatedRequest.status != 'in_review') {
          nextRequests.removeAt(index);
        } else {
          nextRequests[index] = updatedRequest;
        }
      }

      state = state.copyWith(requests: nextRequests, error: null);
    } catch (error) {
      state = state.copyWith(
        permissionDenied: _isPermissionDenied(error),
        error: _errorMessage(error),
      );
      rethrow;
    }
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

String _errorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  if (error is FormatException) {
    return 'Данные заявки пришли неполными. Обновите экран и повторите попытку.';
  }

  return 'Не удалось обработать данные заявок.';
}
