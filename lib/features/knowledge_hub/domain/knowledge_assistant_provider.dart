import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/knowledge_assistant_repository.dart';

class KnowledgeAssistantTurn {
  const KnowledgeAssistantTurn(this.question, this.result);

  final String question;
  final KnowledgeAssistantAnswer result;
}

class KnowledgeAssistantState {
  const KnowledgeAssistantState({this.loading = false, this.result, this.error, this.turns = const []});

  final bool loading;
  final List<KnowledgeAssistantTurn> turns;
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
    if (state.loading || normalized.isEmpty || normalized.length > 1000) return;
    final token = CancelToken();
    _pending = token;
    final previous = state.turns;
    state = KnowledgeAssistantState(loading: true, turns: previous, result: state.result);
    try {
      final history = previous.expand((turn) => [
        {'role': 'user', 'content': turn.question},
        {'role': 'assistant', 'content': turn.result.answer},
      ]).toList();
      final result = await _repository.ask(normalized, contextKey: _contextKey, history: history, cancelToken: token);
      if (mounted && !token.isCancelled) {
        final turns = [...previous, KnowledgeAssistantTurn(normalized, result)];
        state = KnowledgeAssistantState(result: result, turns: List.unmodifiable(turns.skip(turns.length > 4 ? turns.length - 4 : 0)));
      }
    } catch (error) {
      if (mounted && !token.isCancelled) {
        final limited = error is DioException && error.response?.statusCode == 429;
        state = KnowledgeAssistantState(turns: previous, result: state.result, error: limited
            ? 'Лимит обращений к помощнику временно исчерпан. Попробуйте позже.'
            : 'Не удалось получить ответ. Проверьте подключение и попробуйте ещё раз.');
      }
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
  }

  void reset() {
    _pending?.cancel();
    _pending = null;
    state = const KnowledgeAssistantState();
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }
}
