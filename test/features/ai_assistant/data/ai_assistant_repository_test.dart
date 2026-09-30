import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';

void main() {
  test('loads usage and nonempty mobile conversations list', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      if (options.path == '/ai-assistant/usage') {
        return _responseData({
          'billing_contract_version': 2,
          'limiting_resource': 'organization_ai_credits',
          'usage_kind': 'statistics',
          'monthly_limit': null,
          'used': 125,
          'remaining': null,
          'percentage_used': null,
          'tokens_used': 8400,
          'cost_rub': 12.5,
        });
      }
      if (options.path == '/ai-assistant/conversations') {
        return {
          'success': true,
          'message': null,
          'data': [
            {
              'id': 12,
              'title': 'Риски по объекту',
              'created_at': '2026-09-25T10:00:00.000000Z',
              'updated_at': '2026-09-26T14:30:00.000000Z',
              'last_message_preview': 'Проверьте график поставок',
              'last_message_at': '2026-09-26T14:30:00.000000Z',
              'messages_count': 4,
            },
          ],
        };
      }
      if (options.path == '/ai-assistant/credits/balance') {
        return _responseData({
          'included_minor': 500000,
          'purchased_minor': 25000,
          'reserved_minor': 5000,
          'available_minor': 520000,
          'total_minor': 525000,
          'packs': [],
          'charging_enabled': true,
        });
      }
      throw StateError('Unexpected endpoint: ${options.path}');
    });

    final home = await AiAssistantRepository(dio).fetchHome();

    expect(requests.map((request) => request.method).toSet(), {'GET'});
    expect(requests.map((request) => request.path).toSet(), {
      '/ai-assistant/usage',
      '/ai-assistant/conversations',
      '/ai-assistant/credits/balance',
    });
    expect(home.usage.monthlyLimit, isNull);
    expect(home.usage.used, 125);
    expect(home.usage.tokensUsed, 8400);
    expect(home.balance?.available, '5200.00');
    expect(home.conversations, hasLength(1));
    expect(home.conversations.single.id, 12);
    expect(home.conversations.single.title, 'Риски по объекту');
    expect(
      home.conversations.single.lastMessagePreview,
      'Проверьте график поставок',
    );
    expect(home.conversations.single.messagesCount, 4);
  });

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
  test(
    'keeps envelope pagination and uses chronological history endpoint',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((request) {
        expect(request.path, '/ai-assistant/conversations/12/history');
        expect(request.queryParameters['page'], 2);
        return {
          'success': true,
          'data': [
            {'id': '2', 'role': 'assistant', 'content': 'Earlier'},
          ],
          'meta': {'current_page': 2, 'last_page': 3, 'total': 52},
        };
      });
      final result = await AiAssistantRepository(
        dio,
      ).fetchMessages(12, page: 2);
      expect(result.nextPage, 3);
      expect(result.total, 52);
      expect(result.items.single.id, 2);
    },
  );

  test(
    'quote and chat bind identical UUID, profile, context and allow_actions',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      const requestId = 'abcde123-1234-4123-8123-123456789abc';
      dio.httpClientAdapter = _JsonAdapter((request) {
        requests.add(request);
        if (request.path.endsWith('/quote')) {
          return _responseData({
            'quote_id': 'quote-uuid',
            'max_units_minor': 175,
          });
        }
        return _responseData({
          'request_id': requestId,
          'conversation_id': 12,
          'credit_usage': {'charged_minor': 50},
        });
      });
      final repository = AiAssistantRepository(dio);
      final quote = await repository.quoteCredits(
        message: 'Question',
        requestId: requestId,
        conversationId: 12,
        profile: 'short',
        allowActions: false,
        context: {'entity_refs': []},
      );
      expect(quote.amount, '1.75');
      final result = await repository.sendMessageRequest(
        message: 'Question',
        requestId: requestId,
        conversationId: 12,
        quoteId: quote.id,
        maxConfirmed: true,
        profile: 'short',
        allowActions: false,
        context: {'entity_refs': []},
      );
      final chat =
          Map<String, dynamic>.from(requests[1].data as Map)
            ..remove('quote_id')
            ..remove('async');
      expect(chat, requests[0].data);
      expect((requests[1].data as Map)['async'], true);
      expect(result.result!.creditUsage!.actualCharge, '0.50');
    },
  );

  test('rejects responses belonging to another request', () async {
    final dio = Dio();
    dio.httpClientAdapter = _JsonAdapter(
      (_) => _responseData({'request_id': 'other', 'conversation_id': 12}),
    );
    await expectLater(
      AiAssistantRepository(dio).sendMessageRequest(
        message: 'Question',
        requestId: 'current',
        quoteId: 'quote',
        maxConfirmed: true,
      ),
      throwsException,
    );
  });

  test('202 request completes through GET with the same identity', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((request) {
      requests.add(request);
      if (request.method == 'POST') {
        return _responseData({
          'request_id': 'request-1',
          'conversation_id': null,
          'status': 'running',
          'stage': 'queued',
          'progress': [
            {'id': 31, 'code': 'estimates', 'state': 'started'},
          ],
        });
      }
      return _responseData({
        'request_id': 'request-1',
        'conversation_id': 12,
        'status': 'completed',
        'stage': 'completed',
        'progress': [
          {'id': 31, 'code': 'estimates', 'state': 'completed'},
          {'id': 32, 'code': 'warehouse', 'state': 'completed'},
        ],
        'response': {
          'request_id': 'request-1',
          'conversation_id': 12,
          'message': {'id': 17, 'role': 'assistant', 'content': 'Готово'},
          'progress': [
            {'id': 31, 'code': 'estimates', 'state': 'completed'},
            {'id': 32, 'code': 'warehouse', 'state': 'completed'},
          ],
        },
      });
    }, statusCode: (request) => request.method == 'POST' ? 202 : 200);
    final repository = AiAssistantRepository(dio);
    final accepted = await repository.sendMessageRequest(
      message: 'Вопрос',
      requestId: 'request-1',
      quoteId: 'quote-1',
      maxConfirmed: true,
    );
    expect(accepted.status, 'running');
    expect(accepted.result, isNull);
    expect(accepted.progress.single.code, 'estimates');
    expect(accepted.progress.single.state, 'started');
    expect((requests.first.data as Map)['async'], true);
    final completed = await repository.fetchChatRequest('request-1');
    expect(completed.result!.message!.content, 'Готово');
    expect(completed.progress.map((step) => step.code), [
      'estimates',
      'warehouse',
    ]);
    expect(completed.result!.progress.last.state, 'completed');
    expect(requests.last.path, '/ai-assistant/requests/request-1');
  });

  test(
    'progress accepts ids above 24 and keeps at most 24 latest events',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((_) {
        return _responseData({
          'request_id': 'request-2',
          'conversation_id': 12,
          'status': 'running',
          'progress': List.generate(
            26,
            (index) => {
              'id': 31 + index,
              'code': 'warehouse',
              'state': 'completed',
            },
          ),
        });
      });
      final progress = await AiAssistantRepository(
        dio,
      ).fetchChatRequest('request-2');
      expect(progress.progress, hasLength(24));
      expect(progress.progress.first.id, 33);
      expect(progress.progress.last.id, 56);
    },
  );

  test(
    'repeating the accepted POST preserves request and quote identity',
    () async {
      final payloads = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((request) {
        payloads.add(Map<String, dynamic>.from(request.data as Map));
        return _responseData({'request_id': 'same-id', 'conversation_id': 12});
      });
      final repository = AiAssistantRepository(dio);
      for (var i = 0; i < 2; i++) {
        await repository.sendMessageRequest(
          message: 'Вопрос',
          requestId: 'same-id',
          conversationId: 12,
          quoteId: 'same-quote',
          maxConfirmed: true,
        );
      }
      expect(payloads, hasLength(2));
      expect(payloads[1], payloads[0]);
      expect(payloads[1]['request_id'], 'same-id');
      expect(payloads[1]['quote_id'], 'same-quote');
    },
  );

  test(
    'request status rejects a result for a different conversation',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter(
        (_) => _responseData({
          'request_id': 'request-1',
          'conversation_id': 12,
          'status': 'completed',
          'response': {'request_id': 'request-1', 'conversation_id': 13},
        }),
      );
      await expectLater(
        AiAssistantRepository(
          dio,
        ).fetchChatRequest('request-1', conversationId: 12),
        throwsException,
      );
    },
  );

  test('missing request preserves 404 for same-ID recovery', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter(
      (_) => {'success': false, 'message': 'Не найдено'},
      statusCode: (_) => 404,
    );
    await expectLater(
      AiAssistantRepository(dio).fetchChatRequest('same-id'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });

  test('executes only confirmed server action ID and preview token', () async {
    late RequestOptions request;
    final dio = Dio();
    dio.httpClientAdapter = _JsonAdapter((value) {
      request = value;
      return _responseData({'message': 'Done'});
    });
    final preview = AiActionPreviewModel.fromJson({
      'title': 'Review',
      'action': {
        'id': 'action-uuid',
        'tool_name': 'create_task',
        'arguments': {'project_id': 2},
      },
      'preview_token': 'token',
      'executable': true,
    });
    await AiAssistantRepository(
      dio,
    ).executeAction(preview: preview, conversationId: 12);
    expect(request.data, {
      'conversation_id': 12,
      'action': {
        'id': 'action-uuid',
        'preview_token': 'token',
        'confirmed': true,
      },
    });
  });

  test(
    'memory mutations require confirmation and purchase uses commercial pack',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((request) {
        requests.add(request);
        return _responseData(
          request.path.endsWith('/purchase')
              ? {'confirmation_url': 'https://pay.example.test/order'}
              : {'id': 'memory-uuid', 'content': 'Remember'},
        );
      });
      final repository = AiAssistantRepository(dio);
      await repository.createMemory(scope: 'user', content: 'Remember');
      await repository.updateMemory('memory-uuid', content: 'Updated');
      await repository.deleteMemory('memory-uuid');
      final url = await repository.purchaseCredits(pack: 5000);
      expect(requests[0].data, {'content': 'Remember', 'confirmed': true});
      expect(requests[1].method, 'PATCH');
      expect(requests[1].data, {'content': 'Updated', 'confirmed': true});
      expect(requests[2].method, 'DELETE');
      expect(requests[3].data, {'pack_id': 'ai-credits-5000'});
      expect(url, 'https://pay.example.test/order');
    },
  );

  test(
    'sharing sends explicit participant roles and cancel reaches server',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((request) {
        requests.add(request);
        return _responseData({'stage': 'searching', 'status': 'running'});
      });
      final repository = AiAssistantRepository(dio);
      await repository.updateParticipants(12, [
        const AiConversationParticipantModel(userId: '5', role: 'viewer'),
      ]);
      await repository.fetchRequest('request-uuid');
      await repository.cancelRequest('request-uuid');
      expect(requests[0].method, 'PUT');
      expect(requests[0].data, {
        'participants': [
          {'user_id': '5', 'role': 'viewer'},
        ],
      });
      expect(requests[1].method, 'GET');
      expect(requests[2].path, '/ai-assistant/requests/request-uuid/cancel');
      expect(requests[2].method, 'POST');
    },
  );
  test('source navigation accepts only configured origin', () {
    final repository = AiAssistantRepository(
      Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/mobile/')),
      sourceBaseUrl: 'https://most.example.test',
    );
    expect(
      repository.sourceUri('/admin/estimates/3').toString(),
      'https://most.example.test/admin/estimates/3',
    );
    expect(repository.sourceUri('https://evil.example.test/file'), isNull);
    expect(repository.sourceUri('javascript:alert(1)'), isNull);
    expect(
      repository.sourceUri('https://user:password@most.example.test/file'),
      isNull,
    );
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler, {this.statusCode});

  final Map<String, dynamic> Function(RequestOptions options) handler;
  final int Function(RequestOptions options)? statusCode;

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
      statusCode?.call(options) ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _responseData(Map<String, dynamic> data) {
  return {'success': true, 'message': null, 'data': data};
}
