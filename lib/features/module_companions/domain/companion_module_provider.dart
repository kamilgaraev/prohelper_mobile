import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/companion_module_model.dart';
import '../data/companion_module_repository.dart';

class CompanionModuleState {
  const CompanionModuleState({
    this.isLoading = false,
    this.projectId,
    this.list,
    this.status,
    this.query,
    this.permissionDenied = false,
    this.malformedContract = false,
    this.error,
  });

  final bool isLoading;
  final int? projectId;
  final CompanionModuleListModel? list;
  final String? status;
  final String? query;
  final bool permissionDenied;
  final bool malformedContract;
  final String? error;

  CompanionModuleState copyWith({
    bool? isLoading,
    Object? projectId = _projectSentinel,
    Object? list = _listSentinel,
    Object? status = _statusSentinel,
    Object? query = _querySentinel,
    bool? permissionDenied,
    bool? malformedContract,
    Object? error = _errorSentinel,
  }) {
    return CompanionModuleState(
      isLoading: isLoading ?? this.isLoading,
      projectId:
          identical(projectId, _projectSentinel)
              ? this.projectId
              : projectId as int?,
      list:
          identical(list, _listSentinel)
              ? this.list
              : list as CompanionModuleListModel?,
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
const _statusSentinel = Object();
const _querySentinel = Object();
const _errorSentinel = Object();

class CompanionModuleNotifier extends StateNotifier<CompanionModuleState> {
  CompanionModuleNotifier(this._repository, this._moduleSlug)
    : super(const CompanionModuleState());

  final CompanionModuleRepository _repository;
  final String _moduleSlug;

  void syncProject(int? projectId) {
    if (state.projectId == projectId) {
      return;
    }

    state = state.copyWith(projectId: projectId, list: null, error: null);
  }

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      malformedContract: false,
      error: null,
    );

    try {
      final list = await _repository.fetchList(
        moduleSlug: _moduleSlug,
        projectId: state.projectId,
        status: state.status,
        query: state.query,
      );
      state = state.copyWith(isLoading: false, list: list);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        list: null,
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        error: error.toString(),
      );
    }
  }

  Future<void> setStatus(String? status) async {
    state = state.copyWith(status: status, list: null);
    await load();
  }

  Future<void> setQuery(String query) async {
    final trimmedQuery = query.trim();
    state = state.copyWith(
      query: trimmedQuery.isEmpty ? null : trimmedQuery,
      list: null,
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
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final companionModuleProvider = StateNotifierProvider.family<
  CompanionModuleNotifier,
  CompanionModuleState,
  String
>((ref, moduleSlug) {
  return CompanionModuleNotifier(
    ref.read(companionModuleRepositoryProvider),
    moduleSlug,
  );
});
