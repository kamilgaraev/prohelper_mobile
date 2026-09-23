import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../data/design_package_model.dart';
import '../data/design_package_repository.dart';

class DesignPackageState {
  const DesignPackageState({
    this.projectId,
    this.page,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.permissionDenied = false,
    this.error,
  });

  final int? projectId;
  final DesignPackagePage? page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool permissionDenied;
  final String? error;

  DesignPackageState copyWith({
    Object? projectId = _unset,
    Object? page = _unset,
    bool? isLoading,
    bool? isLoadingMore,
    bool? permissionDenied,
    Object? error = _unset,
  }) => DesignPackageState(
    projectId:
        identical(projectId, _unset) ? this.projectId : projectId as int?,
    page: identical(page, _unset) ? this.page : page as DesignPackagePage?,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    error: identical(error, _unset) ? this.error : error as String?,
  );
}

const _unset = Object();

class DesignPackageNotifier extends StateNotifier<DesignPackageState> {
  DesignPackageNotifier(this._repository) : super(const DesignPackageState());

  final DesignPackageRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectId == projectId) return;
    state = DesignPackageState(projectId: projectId);
  }

  Future<void> load() async {
    final projectId = state.projectId;
    if (projectId == null) return;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      permissionDenied: false,
      error: null,
    );
    try {
      final page = await _repository.fetchList(projectId: projectId);
      if (state.projectId != projectId) return;
      state = state.copyWith(isLoading: false, page: page);
    } catch (error) {
      if (state.projectId != projectId) return;
      state = state.copyWith(
        isLoading: false,
        permissionDenied: error is ApiException && error.statusCode == 403,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.page;
    final projectId = state.projectId;
    if (current == null ||
        projectId == null ||
        state.isLoading ||
        state.isLoadingMore ||
        current.currentPage >= current.lastPage) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      final next = await _repository.fetchList(
        projectId: projectId,
        page: current.currentPage + 1,
      );
      if (state.projectId != projectId || !identical(state.page, current)) {
        return;
      }
      state = state.copyWith(isLoadingMore: false, page: current.append(next));
    } catch (error) {
      if (state.projectId != projectId) {
        return;
      }
      state = state.copyWith(
        isLoadingMore: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<DesignPackageModel> fetchDetail(int id) => _repository.fetchDetail(id);

  Future<DesignPackageModel> executeAction({
    required int id,
    required DesignPackageAction action,
    String? comment,
  }) async {
    final detail = await _repository.executeAction(
      id: id,
      action: action.key,
      comment: comment,
    );
    await load();
    return detail;
  }
}

final designPackageProvider =
    StateNotifierProvider<DesignPackageNotifier, DesignPackageState>(
      (ref) => DesignPackageNotifier(ref.read(designPackageRepositoryProvider)),
    );
