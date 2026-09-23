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
  final String? searchFilter;
  final bool urgentOnly;
  final int? assignedUserFilter;
  final String? requestTypeFilter;
  final DateTime? requiredFromFilter;
  final DateTime? requiredToFilter;
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
    this.searchFilter,
    this.urgentOnly = false,
    this.assignedUserFilter,
    this.requestTypeFilter,
    this.requiredFromFilter,
    this.requiredToFilter,
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
    String? searchFilter,
    bool? urgentOnly,
    int? assignedUserFilter,
    String? requestTypeFilter,
    DateTime? requiredFromFilter,
    DateTime? requiredToFilter,
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
      searchFilter: searchFilter ?? this.searchFilter,
      urgentOnly: urgentOnly ?? this.urgentOnly,
      assignedUserFilter: assignedUserFilter ?? this.assignedUserFilter,
      requestTypeFilter: requestTypeFilter ?? this.requestTypeFilter,
      requiredFromFilter: requiredFromFilter ?? this.requiredFromFilter,
      requiredToFilter: requiredToFilter ?? this.requiredToFilter,
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
  int _requestEpoch = 0;

  Future<void> loadRequests({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    if (!refresh && !state.hasMore) return;
    final requestEpoch = refresh ? ++_requestEpoch : _requestEpoch;

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
        search: state.searchFilter,
        urgentOnly: state.urgentOnly,
        assignedUserId: state.assignedUserFilter,
        requestType: state.requestTypeFilter,
        requiredFrom: state.requiredFromFilter,
        requiredTo: state.requiredToFilter,
        projectId: state.projectFilter,
        scope: state.scope,
      );

      if (requestEpoch != _requestEpoch) return;
      state = state.copyWith(
        isLoading: false,
        requests: [...state.requests, ...newRequests],
        currentPage: state.currentPage + 1,
        hasMore: newRequests.isNotEmpty,
      );
    } catch (error) {
      if (requestEpoch != _requestEpoch) return;
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

  void setSearchFilter(String? value) {
    state = state.copyWith(searchFilter: value);
    loadRequests(refresh: true);
  }

  void setUrgentFilter(bool value) {
    state = state.copyWith(urgentOnly: value);
    loadRequests(refresh: true);
  }

  void setAssigneeFilter(int? value) {
    state = state.copyWith(assignedUserFilter: value);
    loadRequests(refresh: true);
  }

  void setRequestTypeFilter(String? value) {
    state = state.copyWith(requestTypeFilter: value);
    loadRequests(refresh: true);
  }

  void setRequiredDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(requiredFromFilter: from, requiredToFilter: to);
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
