import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'ai_assistant_models.dart';

final aiAssistantRepositoryProvider = Provider<AiAssistantRepository>((ref) {
  return AiAssistantRepository(ref.read(dioProvider));
});

class AiAssistantRepository {
  AiAssistantRepository(this._dio);

  final Dio _dio;

  Future<AiAssistantHomeModel> fetchHome() async {
    try {
      final responses = await Future.wait([
        _dio.get('/ai-assistant/usage'),
        _dio.get('/ai-assistant/conversations'),
      ]);

      final usageData = _unwrapData(responses[0].data);
      final conversationsData = _unwrapData(responses[1].data);

      final usage = AiUsageModel.fromJson(_asMap(usageData));
      final conversations = _asList(conversationsData)
          .map((item) => AiConversationModel.fromJson(_asMap(item)))
          .toList();

      return AiAssistantHomeModel(
        usage: usage,
        conversations: conversations,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить данные AI-ассистента.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить данные AI-ассистента.');
    }
  }

  Future<AiConversationDetailsModel> fetchConversation(int id) async {
    try {
      final response = await _dio.get('/ai-assistant/conversations/$id');
      final payload = _asMap(_unwrapData(response.data));

      final conversation =
          AiConversationModel.fromJson(_asMap(payload['conversation']));
      final messages = _asList(payload['messages'])
          .map((item) => AiMessageModel.fromJson(_asMap(item)))
          .toList();

      return AiConversationDetailsModel(
        conversation: conversation,
        messages: messages,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить историю диалога.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить историю диалога.');
    }
  }

  Future<AiConversationDetailsModel> sendMessage({
    required String message,
    int? conversationId,
  }) async {
    try {
      final response = await _dio.post(
        '/ai-assistant/chat',
        data: {
          'message': message,
          if (conversationId != null) 'conversation_id': conversationId,
        },
      );

      final payload = _asMap(_unwrapData(response.data));
      final nextConversationId = _intValue(payload['conversation_id']);

      if (nextConversationId <= 0) {
        throw const ApiException('Сервер не вернул идентификатор диалога.');
      }

      return fetchConversation(nextConversationId);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить сообщение ассистенту.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось отправить сообщение ассистенту.');
    }
  }

  Future<void> deleteConversation(int id) async {
    try {
      await _dio.delete('/ai-assistant/conversations/$id');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось удалить диалог.',
      );
    } catch (_) {
      throw const ApiException('Не удалось удалить диалог.');
    }
  }

  dynamic _unwrapData(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
    }

    if (response is Map && response.containsKey('data')) {
      return response['data'];
    }

    return response;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }

    if (value is List) {
      return value.cast<dynamic>();
    }

    return const <dynamic>[];
  }

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
