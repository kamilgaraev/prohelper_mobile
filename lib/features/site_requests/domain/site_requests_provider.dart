import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/site_request_model.dart';
import '../data/site_requests_repository.dart';

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
    String? error,
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
      error: error ?? this.error,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      projectFilter: clearProjectFilter ? null : (projectFilter ?? this.projectFilter),
    );
  }
}

final siteRequestsProvider = StateNotifierProvider<SiteRequestsNotifier, SiteRequestsState>((ref) {
  return SiteRequestsNotifier(ref.read(siteRequestsRepositoryProvider));
});

class SiteRequestsNotifier extends StateNotifier<SiteRequestsState> {
  final SiteRequestsRepository _repository;

  SiteRequestsNotifier(this._repository) : super(SiteRequestsState());

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

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status, clearStatusFilter: status == null);
    loadRequests(refresh: true);
  }

  void setProjectFilter(int? projectId) {
    state = state.copyWith(projectFilter: projectId, clearProjectFilter: projectId == null);
    loadRequests(refresh: true);
  }
}
