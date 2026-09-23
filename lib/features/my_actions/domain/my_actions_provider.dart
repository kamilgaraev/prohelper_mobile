import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../data/my_action.dart';
import '../data/my_actions_repository.dart';

class MyActionsState {
  const MyActionsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 0,
    this.lastPage = 0,
  });

  final List<MyAction> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

class MyActionsNotifier extends StateNotifier<MyActionsState> {
  MyActionsNotifier(this._repository, this._projectId)
    : super(const MyActionsState()) {
    load();
  }

  final MyActionsRepository _repository;
  final int? _projectId;

  Future<void> load() async {
    state = const MyActionsState(isLoading: true);
    try {
      final result = await _repository.fetch(projectId: _projectId);
      if (!mounted) return;
      state = MyActionsState(
        items: result.items,
        page: result.currentPage,
        lastPage: result.lastPage,
      );
    } catch (error) {
      if (!mounted) return;
      state = MyActionsState(error: UserMessage.fromError(error));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final previous = state;
    state = MyActionsState(
      items: previous.items,
      page: previous.page,
      lastPage: previous.lastPage,
      isLoadingMore: true,
    );
    try {
      final result = await _repository.fetch(
        projectId: _projectId,
        page: previous.page + 1,
      );
      if (!mounted) return;
      state = MyActionsState(
        items: [...previous.items, ...result.items],
        page: result.currentPage,
        lastPage: result.lastPage,
      );
    } catch (error) {
      if (!mounted) return;
      state = MyActionsState(
        items: previous.items,
        page: previous.page,
        lastPage: previous.lastPage,
        error: UserMessage.fromError(error),
      );
    }
  }
}

final myActionsProvider =
    StateNotifierProvider.family<MyActionsNotifier, MyActionsState, int?>(
      (ref, projectId) =>
          MyActionsNotifier(ref.read(myActionsRepositoryProvider), projectId),
    );
