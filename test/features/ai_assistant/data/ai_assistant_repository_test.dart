import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';

void main() {
  test(
    'sends selected project and mobile UI context to chat endpoint',
    () async {
      late RequestOptions chatRequest;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        if (options.method == 'POST' && options.path == '/ai-assistant/chat') {
          chatRequest = options;
          return _responseData({'conversation_id': 12});
        }

        if (options.method == 'GET' &&
            options.path == '/ai-assistant/conversations/12') {
          return _responseData({
            'conversation': {
              'id': 12,
              'title': 'Диалог',
              'created_at': '2026-05-22T10:00:00.000000Z',
              'updated_at': '2026-05-22T10:00:00.000000Z',
            },
            'messages': const [],
          });
        }

        return _responseData({'conversation_id': 0});
      });
      final repository = AiAssistantRepository(dio);

      await repository.sendMessage(
        message: 'Что по рискам?',
        conversationId: 8,
        desiredMode: 'grounded',
        context: const {
          'source_module': 'ai-assistant',
          'source_route': 'mobile/ai-assistant/chat',
          'entity_refs': [
            {'type': 'project', 'id': 77, 'label': 'Башня'},
          ],
          'filters': {'project_id': 77},
          'ui_state': {
            'assistant_path': 'mobile/ai-assistant/chat',
            'client': 'mobile',
            'selected_project_id': 77,
          },
        },
      );

      final payload = chatRequest.data as Map;
      final context = payload['context'] as Map;
      final entityRefs = context['entity_refs'] as List;
      final filters = context['filters'] as Map;
      final uiState = context['ui_state'] as Map;

      expect(chatRequest.method, 'POST');
      expect(chatRequest.path, '/ai-assistant/chat');
      expect(payload['message'], 'Что по рискам?');
      expect(payload['conversation_id'], 8);
      expect(payload['desired_mode'], 'grounded');
      expect(context['source_route'], 'mobile/ai-assistant/chat');
      expect(entityRefs.single, containsPair('id', 77));
      expect(filters['project_id'], 77);
      expect(uiState['selected_project_id'], 77);
    },
  );
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _responseData(Map<String, dynamic> data) {
  return {'success': true, 'message': null, 'data': data};
}
