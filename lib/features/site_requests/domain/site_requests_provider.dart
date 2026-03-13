import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/site_request_model.dart';
import '../data/site_requests_repository.dart';

const _siteRequestsSentinel = Object();

class SiteRequestsState {
  final bool isLoading;
  final List<SiteRequestModel> requests;
  final int currentPage;
  final bool hasMore;
  final String? error;
  final String? statusFilter;
  final int? projectFilter;

  SiteRequestsState({
    this.isLoading = false,
    this.requests = const [],
    this.currentPage = 1,
    this.hasMore = true,
    this.error,
    this.statusFilter,
    this.projectFilter,
  });

  SiteRequestsState copyWith({
    bool? isLoading,
    List<SiteRequestModel>? requests,
    int? currentPage,
    bool? hasMore,
    Object? error = _siteRequestsSentinel,
    String? statusFilter,
    int? projectFilter,
    bool clearStatusFilter = false,
    bool clearProjectFilter = false,
  }) {
    return SiteRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _siteRequestsSentinel) ? this.error : error as String?,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      projectFilter: clearProjectFilter ? null : (projectFilter ?? this.projectFilter),
    );
  }
}

final siteRequestsProvider = StateNotifierProvider<SiteRequestsNotifier, SiteRequestsState>((ref) {
  ref.watch(authProvider);
  final selectedProject = ref.watch(projectsProvider).selectedProject;
  return SiteRequestsNotifier(
    ref.read(siteRequestsRepositoryProvider),
    initialProjectId: selectedProject?.serverId,
  );
});

class SiteRequestsNotifier extends StateNotifier<SiteRequestsState> {
  final SiteRequestsRepository _repository;

  SiteRequestsNotifier(
    this._repository, {
    int? initialProjectId,
  }) : super(SiteRequestsState(projectFilter: initialProjectId));

  Future<void> loadRequests({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    if (refresh) {
      state = state.copyWith(isLoading: true, error: null, currentPage: 1, hasMore: true, requests: []);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final newRequests = await _repository.fetchSiteRequests(
        page: state.currentPage,
        status: state.statusFilter,
        projectId: state.projectFilter,
      );

      state = state.copyWith(
        isLoading: false,
        requests: [...state.requests, ...newRequests],
        currentPage: state.currentPage + 1,
        hasMore: newRequests.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void syncProject(int? projectId) {
    final currentProjectId = state.projectFilter;
    if (currentProjectId == projectId) {
      return;
    }

    state = state.copyWith(
      projectFilter: projectId,
      clearProjectFilter: projectId == null,
      requests: [],
      currentPage: 1,
      hasMore: true,
      error: null,
    );
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status, clearStatusFilter: status == null);
    loadRequests(refresh: true);
  }

  void setProjectFilter(int? projectId) {
    state = state.copyWith(projectFilter: projectId, clearProjectFilter: projectId == null);
    loadRequests(refresh: true);
  }
}
