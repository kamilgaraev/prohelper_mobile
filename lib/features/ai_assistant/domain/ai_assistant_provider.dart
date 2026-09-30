import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';

const _homeSentinel = Object();

class AiAssistantHomeState {
  const AiAssistantHomeState({this.isLoading = false, this.home, this.error});

  final bool isLoading;
  final AiAssistantHomeModel? home;
  final String? error;

  AiAssistantHomeState copyWith({
    bool? isLoading,
    Object? home = _homeSentinel,
    Object? error = _homeSentinel,
  }) {
    return AiAssistantHomeState(
      isLoading: isLoading ?? this.isLoading,
      home:
          identical(home, _homeSentinel)
              ? this.home
              : home as AiAssistantHomeModel?,
      error: identical(error, _homeSentinel) ? this.error : error as String?,
    );
  }
}

class AiAssistantHomeNotifier extends StateNotifier<AiAssistantHomeState> {
  AiAssistantHomeNotifier(this._repository)
    : super(const AiAssistantHomeState()) {
    load();
  }

  final AiAssistantRepository _repository;
  int _revision = 0;

  Future<void> load() async {
    final revision = ++_revision;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final home = await _repository.fetchHome();
      if (!mounted || revision != _revision) return;
      state = state.copyWith(isLoading: false, home: home);
    } catch (error) {
      if (!mounted || revision != _revision) return;
      state = state.copyWith(
        isLoading: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> loadMore() async {
    final home = state.home;
    if (home == null || home.nextPage == null || state.isLoading) return;
    final revision = _revision;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final page = await _repository.fetchConversations(page: home.nextPage!);
      if (!mounted || revision != _revision) return;
      final ids = <int>{};
      state = state.copyWith(
        isLoading: false,
        home: AiAssistantHomeModel(
          usage: home.usage,
          conversations:
              [
                ...home.conversations,
                ...page.items,
              ].where((conversation) => ids.add(conversation.id)).toList(),
          nextPage: page.nextPage,
          balance: home.balance,
        ),
      );
    } catch (error) {
      if (!mounted || revision != _revision) return;
      state = state.copyWith(
        isLoading: false,
        error: UserMessage.fromError(error),
      );
    }
  }
}

final aiAssistantHomeProvider =
    StateNotifierProvider<AiAssistantHomeNotifier, AiAssistantHomeState>((ref) {
      ref.watch(
        authProvider.select(
          (state) => (state.user?.serverId, state.user?.currentOrganizationId),
        ),
      );
      return AiAssistantHomeNotifier(ref.read(aiAssistantRepositoryProvider));
    });
