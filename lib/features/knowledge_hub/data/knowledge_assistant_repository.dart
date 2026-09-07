import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/network/mobile_api_response.dart';

final knowledgeAssistantRepositoryProvider = Provider<KnowledgeAssistantRepository>((ref) {
  return KnowledgeAssistantRepository(ref.read(dioProvider));
});

class KnowledgeAssistantSource {
  const KnowledgeAssistantSource({required this.id, required this.title, this.slug});

  final int id;
  final String title;
  final String? slug;
}

class KnowledgeAssistantAnswer {
  const KnowledgeAssistantAnswer({required this.answer, required this.answered, required this.sources, this.needsClarification = false});

  final String answer;
  final bool answered;
  final bool needsClarification;
  final List<KnowledgeAssistantSource> sources;

  factory KnowledgeAssistantAnswer.fromJson(Map<String, dynamic> json) {
    final answer = json['answer'];
    final status = json['status'];
    final sources = json['sources'];
    if (answer is! String || (status != 'answered' && status != 'insufficient_knowledge') || sources is! List) {
      throw const FormatException('knowledge_assistant_response');
    }
    final references = <KnowledgeAssistantSource>[];
    for (final source in sources) {
      if (source is! Map || source['id'] is! int || source['title'] is! String) {
        throw const FormatException('knowledge_assistant_source');
      }
      references.add(KnowledgeAssistantSource(id: source['id'] as int, title: source['title'] as String, slug: source['slug'] is String ? source['slug'] as String : null));
    }
    return KnowledgeAssistantAnswer(answer: answer, answered: status == 'answered', needsClarification: json['needs_clarification'] == true, sources: List.unmodifiable(references));
  }
}

class KnowledgeAssistantRepository {
  KnowledgeAssistantRepository(this._dio);

  final Dio _dio;

  Future<KnowledgeAssistantAnswer> ask(String question, {String? contextKey, List<Map<String, String>> history = const [], required CancelToken cancelToken}) async {
    final response = await _dio.post(
      '/knowledge-hub/assistant',
      data: {'question': question.trim(), 'history': history, if (contextKey != null) 'context_key': contextKey},
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(seconds: 60), sendTimeout: const Duration(seconds: 20)),
    );
    return KnowledgeAssistantAnswer.fromJson(MobileApiResponse.dataMap(response.data));
  }
}
