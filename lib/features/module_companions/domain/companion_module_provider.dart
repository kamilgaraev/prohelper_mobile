import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/companion_module_model.dart';
import '../data/companion_module_repository.dart';

class CompanionModuleState {
  const CompanionModuleState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.projectId,
    this.list,
    this.listQuery,
    this.listStatus,
    this.showingStaleList = false,
    this.status,
    this.query,
    this.permissionDenied = false,
    this.malformedContract = false,
    this.error,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final int? projectId;
  final CompanionModuleListModel? list;
  final String? listQuery;
  final String? listStatus;
  final bool showingStaleList;
  final String? status;
  final String? query;
  final bool permissionDenied;
  final bool malformedContract;
  final String? error;

  CompanionModuleState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    Object? projectId = _projectSentinel,
    Object? list = _listSentinel,
    Object? listQuery = _listQuerySentinel,
    Object? listStatus = _listStatusSentinel,
    bool? showingStaleList,
    Object? status = _statusSentinel,
    Object? query = _querySentinel,
    bool? permissionDenied,
    bool? malformedContract,
    Object? error = _errorSentinel,
  }) {
    return CompanionModuleState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      projectId:
          identical(projectId, _projectSentinel)
              ? this.projectId
              : projectId as int?,
      list:
          identical(list, _listSentinel)
              ? this.list
              : list as CompanionModuleListModel?,
      listQuery:
          identical(listQuery, _listQuerySentinel)
              ? this.listQuery
              : listQuery as String?,
      listStatus:
          identical(listStatus, _listStatusSentinel)
              ? this.listStatus
              : listStatus as String?,
      showingStaleList: showingStaleList ?? this.showingStaleList,
      status:
          identical(status, _statusSentinel) ? this.status : status as String?,
      query: identical(query, _querySentinel) ? this.query : query as String?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      malformedContract: malformedContract ?? this.malformedContract,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _projectSentinel = Object();
const _listSentinel = Object();
const _listQuerySentinel = Object();
const _listStatusSentinel = Object();
const _statusSentinel = Object();
const _querySentinel = Object();
const _errorSentinel = Object();

class CompanionModuleNotifier extends StateNotifier<CompanionModuleState> {
  CompanionModuleNotifier(this._repository, this._moduleSlug)
    : super(const CompanionModuleState());

  final CompanionModuleRepository _repository;
  final String _moduleSlug;
  int _loadVersion = 0;

  void syncProject(int? projectId) {
    if (state.projectId == projectId) {
      return;
    }

    _loadVersion++;
    state = state.copyWith(
      projectId: projectId,
      list: null,
      listQuery: null,
      listStatus: null,
      showingStaleList: false,
      isLoadingMore: false,
      error: null,
    );
  }

  Future<void> load() async {
    final requestVersion = ++_loadVersion;
    final requestProjectId = state.projectId;
    final requestStatus = state.status;
    final requestQuery = state.query;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      permissionDenied: false,
      malformedContract: false,
      error: null,
      showingStaleList: state.list != null,
    );

    try {
      final list = await _repository.fetchList(
        moduleSlug: _moduleSlug,
        projectId: requestProjectId,
        status: requestStatus,
        query: requestQuery,
        page: 1,
      );
      if (!mounted || requestVersion != _loadVersion) return;
      state = state.copyWith(
        isLoading: false,
        list: list,
        listQuery: requestQuery,
        listStatus: requestStatus,
        showingStaleList: false,
      );
    } catch (error) {
      if (!mounted || requestVersion != _loadVersion) return;
      if (isSnapshotOffline(error) && state.list != null) {
        state = state.copyWith(
          isLoading: false,
          showingStaleList: true,
          error: UserMessage.fromError(error),
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        list: null,
        listQuery: null,
        listStatus: null,
        showingStaleList: false,
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.list;
    if (state.isLoading ||
        state.isLoadingMore ||
        current == null ||
        state.showingStaleList ||
        state.listQuery != state.query ||
        state.listStatus != state.status ||
        current.meta.currentPage >= current.meta.lastPage) {
      return;
    }

    final requestVersion = _loadVersion;
    final requestProjectId = state.projectId;
    final requestStatus = state.status;
    final requestQuery = state.query;
    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final next = await _repository.fetchList(
        moduleSlug: _moduleSlug,
        projectId: requestProjectId,
        status: requestStatus,
        query: requestQuery,
        page: current.meta.currentPage + 1,
      );
      if (!mounted ||
          requestVersion != _loadVersion ||
          state.list != current ||
          state.projectId != requestProjectId ||
          state.status != requestStatus ||
          state.query != requestQuery) {
        return;
      }
      {
        state = state.copyWith(
          isLoadingMore: false,
          list: current.appendPage(next),
        );
      }
    } catch (error) {
      if (!mounted ||
          requestVersion != _loadVersion ||
          state.list != current ||
          state.projectId != requestProjectId ||
          state.status != requestStatus ||
          state.query != requestQuery) {
        return;
      }
      if (!isSnapshotOffline(error)) {
        state = state.copyWith(
          isLoadingMore: false,
          list: null,
          listQuery: null,
          listStatus: null,
          showingStaleList: false,
          permissionDenied: _isPermissionDenied(error),
          malformedContract: error is FormatException,
          error: UserMessage.fromError(error),
        );
        return;
      }
      state = state.copyWith(
        isLoadingMore: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> setStatus(String? status) async {
    state = state.copyWith(
      status: status,
      showingStaleList: state.list != null,
    );
    await load();
  }

  Future<void> setQuery(String query) async {
    final trimmedQuery = query.trim();
    state = state.copyWith(
      query: trimmedQuery.isEmpty ? null : trimmedQuery,
      showingStaleList: state.list != null,
    );
    await load();
  }

  Future<CompanionModuleDetailModel> fetchDetail(int id) {
    return _repository.fetchDetail(moduleSlug: _moduleSlug, id: id);
  }

  Future<CompanionModuleDetailModel> executeAction({
    required int id,
    required String action,
    String? comment,
  }) async {
    final detail = await _repository.executeAction(
      moduleSlug: _moduleSlug,
      id: id,
      action: action,
      comment: comment,
    );
    await load();
    return detail;
  }

  Future<void> executeExecutiveDocumentAction({
    required int documentId,
    required String action,
    String? comment,
    int? versionId,
    String? severity,
  }) async {
    await _repository.executeExecutiveDocumentAction(
      documentId: documentId,
      action: action,
      comment: comment,
      versionId: versionId,
      severity: severity,
    );
    await load();
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final companionModuleProvider = StateNotifierProvider.family<
  CompanionModuleNotifier,
  CompanionModuleState,
  String
>((ref, moduleSlug) {
  ref.watch(
    authProvider.select(
      (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
    ),
  );
  return CompanionModuleNotifier(
    ref.read(companionModuleRepositoryProvider),
    moduleSlug,
  );
});
