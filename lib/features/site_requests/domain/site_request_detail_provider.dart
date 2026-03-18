import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/site_request_model.dart';
import '../data/site_requests_repository.dart';
import 'site_requests_provider.dart';

const _siteRequestDetailSentinel = Object();

class SiteRequestDetailState {
  final bool isLoading;
  final bool isActionLoading;
  final SiteRequestModel? request;
  final String? error;

  SiteRequestDetailState({
    this.isLoading = false,
    this.isActionLoading = false,
    this.request,
    this.error,
  });

  SiteRequestDetailState copyWith({
    bool? isLoading,
    bool? isActionLoading,
    SiteRequestModel? request,
    Object? error = _siteRequestDetailSentinel,
  }) {
    return SiteRequestDetailState(
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      request: request ?? this.request,
      error: identical(error, _siteRequestDetailSentinel) ? this.error : error as String?,
    );
  }
}

final siteRequestDetailProvider = StateNotifierProvider.family<
    SiteRequestDetailNotifier, SiteRequestDetailState, int>((ref, id) {
  return SiteRequestDetailNotifier(ref.read(siteRequestsRepositoryProvider), ref, id);
});

class SiteRequestDetailNotifier extends StateNotifier<SiteRequestDetailState> {
  SiteRequestDetailNotifier(this._repository, this._ref, this._id)
      : super(SiteRequestDetailState()) {
    loadDetails();
  }

  final SiteRequestsRepository _repository;
  final Ref _ref;
  final int _id;

  Future<void> loadDetails() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final request = await _repository.fetchSiteRequestDetails(_id);
      state = state.copyWith(isLoading: false, request: request);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> submit() async {
    await _performAction(() => _repository.submitSiteRequest(_id));
  }

  Future<void> cancel({String? notes}) async {
    await _performAction(() => _repository.cancelSiteRequest(_id, notes: notes));
  }

  Future<void> complete({String? notes}) async {
    await _performAction(() => _repository.completeSiteRequest(_id, notes: notes));
  }

  Future<void> changeStatus(String status, {String? notes}) async {
    await _performAction(
      () => _repository.changeSiteRequestStatus(_id, status, notes: notes),
    );
  }

  Future<void> _performAction(Future<SiteRequestModel> Function() action) async {
    state = state.copyWith(isActionLoading: true, error: null);
    try {
      final updatedRequest = await action();
      state = state.copyWith(isActionLoading: false, request: updatedRequest);
      await _ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      rethrow;
    }
  }
}
