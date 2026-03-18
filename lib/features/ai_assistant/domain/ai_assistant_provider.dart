import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';

const _homeSentinel = Object();

class AiAssistantHomeState {
  const AiAssistantHomeState({
    this.isLoading = false,
    this.home,
    this.error,
  });

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
      home: identical(home, _homeSentinel) ? this.home : home as AiAssistantHomeModel?,
      error: identical(error, _homeSentinel) ? this.error : error as String?,
    );
  }
}

class AiAssistantHomeNotifier extends StateNotifier<AiAssistantHomeState> {
  AiAssistantHomeNotifier(this._repository) : super(const AiAssistantHomeState()) {
    load();
  }

  final AiAssistantRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final home = await _repository.fetchHome();
      state = state.copyWith(
        isLoading: false,
        home: home,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }
}

final aiAssistantHomeProvider =
    StateNotifierProvider<AiAssistantHomeNotifier, AiAssistantHomeState>((ref) {
  return AiAssistantHomeNotifier(ref.read(aiAssistantRepositoryProvider));
});
