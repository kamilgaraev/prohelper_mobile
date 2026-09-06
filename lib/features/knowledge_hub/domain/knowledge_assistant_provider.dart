import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/knowledge_assistant_repository.dart';

class KnowledgeAssistantState {
  const KnowledgeAssistantState({this.loading = false, this.result, this.error});

  final bool loading;
  final KnowledgeAssistantAnswer? result;
  final String? error;
}

final knowledgeAssistantProvider = StateNotifierProvider.autoDispose.family<KnowledgeAssistantNotifier, KnowledgeAssistantState, String?>((ref, contextKey) {
  return KnowledgeAssistantNotifier(ref.read(knowledgeAssistantRepositoryProvider), contextKey);
});

class KnowledgeAssistantNotifier extends StateNotifier<KnowledgeAssistantState> {
  KnowledgeAssistantNotifier(this._repository, this._contextKey) : super(const KnowledgeAssistantState());

  final KnowledgeAssistantRepository _repository;
  final String? _contextKey;
  CancelToken? _pending;

  Future<void> ask(String question) async {
    final normalized = question.trim();
    if (state.loading || normalized.length < 3 || normalized.length > 1000) return;
    final token = CancelToken();
    _pending = token;
    state = const KnowledgeAssistantState(loading: true);
    try {
      final result = await _repository.ask(normalized, contextKey: _contextKey, cancelToken: token);
      if (mounted && !token.isCancelled) state = KnowledgeAssistantState(result: result);
    } catch (error) {
      if (mounted && !token.isCancelled) {
        final limited = error is DioException && error.response?.statusCode == 429;
        state = KnowledgeAssistantState(error: limited
            ? 'Лимит обращений к помощнику временно исчерпан. Попробуйте позже.'
            : 'Не удалось получить ответ. Проверьте подключение и попробуйте ещё раз.');
      }
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }
}
