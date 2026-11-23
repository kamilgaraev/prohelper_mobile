import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
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
          'data': {
            'current_page': 1,
            'last_page': 2,
            'total': 20,
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
          },
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
    expect(home.nextPage, 2);
    expect(home.conversations.single.id, 12);
    expect(home.conversations.single.title, 'Риски по объекту');
    expect(
      home.conversations.single.lastMessagePreview,
      'Проверьте график поставок',
    );
    expect(home.conversations.single.messagesCount, 4);
  });

  test(
    'preserves the server cancellation state and rejects a foreign request',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter(
        (options) => _responseData({
          'request_id': 'request-1',
          'status': 'cancel_requested',
          'run_status': 'running',
          'stage': 'generating',
        }),
      );
      final repository = AiAssistantRepository(dio);
      final request = await repository.cancelRequest('request-1');
      expect(request.status, 'cancel_requested');
      expect(request.runStatus, 'running');
      expect(request.isCancellationPending, isTrue);
      expect(request.isTerminal, isFalse);
      expect(request.stage, 'generating');
      await expectLater(
        repository.cancelRequest('request-2'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'fetches a completed result after cancel returned only status',
    () async {
      const requestId = '6d4cbf59-a08a-48cb-9f93-a9ac85ea4e16';
      const requestPath = '/ai-assistant/requests/$requestId';
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((request) {
        if (request.method == 'POST') {
          expect(request.path, '$requestPath/cancel');
          expect(request.data, {'contract_version': 1});
          return _responseData({
            'request_id': requestId,
            'conversation_id': 12,
            'status': 'completed',
          });
        }

        expect(request.method, 'GET');
        expect(request.path, requestPath);
        expect(request.queryParameters, {'contract_version': 1});
        return _responseData({
          'request_id': requestId,
          'conversation_id': 12,
          'status': 'completed',
          'response': {
            'request_id': requestId,
            'conversation_id': 12,
            'message': {'id': 17, 'role': 'assistant', 'content': 'Готово'},
          },
        });
      });
      final repository = AiAssistantRepository(dio);

      final cancellation = await repository.cancelRequest(requestId);
      expect(cancellation.status, 'completed');
      expect(cancellation.result, isNull);

      final completed = await repository.fetchChatRequest(
        requestId,
        conversationId: 12,
      );
      expect(completed.result?.message?.content, 'Готово');
    },
  );

  test(
    'accepts a v1 completed snapshot without result only on cancel',
    () async {
      const requestId = '6d4cbf59-a08a-48cb-9f93-a9ac85ea4e16';
      var includeResult = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter(
        (request) => _responseData({
          'request_id': requestId,
          'conversation_id': 12,
          'run_status': 'completed',
          if (request.method == 'GET' && includeResult)
            'response': {
              'request_id': requestId,
              'conversation_id': 12,
              'message': {'id': 17, 'role': 'assistant', 'content': 'Готово'},
            },
        }),
      );
      final repository = AiAssistantRepository(dio);

      final cancelled = await repository.cancelRequest(
        requestId,
        conversationId: 12,
      );
      expect(cancelled.runStatus, 'completed');
      expect(cancelled.result, isNull);
      await expectLater(
        repository.cancelRequest(requestId, conversationId: 13),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repository.fetchChatRequest(requestId, conversationId: 12),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repository.sendMessageRequest(
          message: 'Вопрос',
          requestId: requestId,
          conversationId: 12,
        ),
        throwsA(isA<ApiException>()),
      );

      includeResult = true;
      final completed = await repository.fetchChatRequest(
        requestId,
        conversationId: 12,
      );
      expect(completed.result?.message?.content, 'Готово');
    },
  );

  test(
    'sends selected project and mobile UI context with an asynchronous turn',
    () async {
      const requestId = '6d4cbf59-a08a-48cb-9f93-a9ac85ea4e16';
      late RequestOptions chatRequest;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        chatRequest = options;
        return _responseData({
          'request_id': requestId,
          'conversation_id': 8,
          'status': 'running',
          'stage': 'queued',
        });
      }, statusCode: (_) => 202);
      final repository = AiAssistantRepository(dio);

      final accepted = await repository.sendMessageRequest(
        message: 'Что по рискам?',
        requestId: requestId,
        conversationId: 8,
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
      expect(payload['async'], isTrue);
      expect(payload['contract_version'], 1);
      expect(
        chatRequest.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('x-most-assistant-contract')),
      );
      expect(accepted.status, 'running');
      expect(accepted.stage, 'queued');
      expect(context['source_route'], 'mobile/ai-assistant/chat');
      expect(entityRefs.single, containsPair('id', 77));
      expect(filters['project_id'], 77);
      expect(uiState['selected_project_id'], 77);
    },
  );
  test(
    'negotiates an active turn on details and reads legacy messages',
    () async {
      const requestId = '2962344c-2256-4315-99f1-638ffb026a3e';
      var supportsActiveRequest = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((request) {
        expect(request.path, '/ai-assistant/conversations/12');
        expect(request.queryParameters, {'contract_version': 1});
        return _responseData({
          'conversation': {'id': 12, 'title': 'Диалог'},
          'messages': [
            {'id': 2, 'role': 'assistant', 'content': 'Предыдущий ответ'},
          ],
          if (supportsActiveRequest)
            'active_request': {
              'request_id': requestId,
              'conversation_id': 12,
              'status': 'running',
              'run_status': 'running',
            },
        });
      });
      final repository = AiAssistantRepository(dio);
      final legacy = await repository.fetchConversation(12);
      expect(legacy.messages.single.content, 'Предыдущий ответ');
      expect(legacy.activeRequest, isNull);

      supportsActiveRequest = true;
      final modern = await repository.fetchConversation(12);
      expect(modern.messages.single.content, 'Предыдущий ответ');
      expect(modern.activeRequest?.requestId, requestId);
      expect(modern.activeRequest?.runStatus, 'running');
    },
  );

  test(
    'keeps envelope pagination and uses chronological history endpoint',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((request) {
        expect(request.path, '/ai-assistant/conversations/12/history');
        expect(request.queryParameters, {'page': 2, 'contract_version': 1});
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
      expect(result.activeRequest, isNull);
    },
  );

  test(
    'quote and chat bind identical UUID, options and renderer capabilities',
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
            'metadata': {
              'processing_deadline_seconds': 120,
              'processing_mode': 'adaptive',
            },
          });
        }
        return _responseData({
          'request_id': requestId,
          'conversation_id': 12,
          'status': 'ok',
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
      expect(quote.processingDeadlineSeconds, 120);
      expect(quote.processingMode, AiAssistantProcessingMode.adaptive);
      final result = await repository.sendMessageRequest(
        message: 'Question',
        requestId: requestId,
        conversationId: 12,
        quoteId: quote.id,
        profile: 'short',
        allowActions: false,
        context: {'entity_refs': []},
      );
      final chat =
          Map<String, dynamic>.from(requests[1].data as Map)
            ..remove('quote_id')
            ..remove('async');
      expect(chat, requests[0].data);
      expect(chat['contract_version'], 1);
      expect(chat['renderer_version'], 1);
      expect(chat['supported_blocks'], ['facts', 'list', 'table']);
      expect((requests[1].data as Map)['async'], true);
      expect(result.runStatus, 'completed');
      expect(result.result!.creditUsage!.actualCharge, '0.50');
    },
  );

  test('handles a v1 local quote and an inline final answer', () async {
    const requestId = '6d4cbf59-a08a-48cb-9f93-a9ac85ea4e16';
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((request) {
      expect(request.method, 'POST');
      expect((request.data as Map)['contract_version'], 1);
      if (request.path == '/ai-assistant/credits/quote') {
        return _responseData({
          'quote_id': 'quote-local',
          'max_units_minor': 0,
          'metadata': {'processing_mode': 'local'},
        });
      }
      expect(request.path, '/ai-assistant/chat');
      expect((request.data as Map)['quote_id'], 'quote-local');
      return _responseData({
        'request_id': requestId,
        'conversation_id': 12,
        'run_status': 'completed',
        'result_key': 'answer',
        'message': {'id': 18, 'role': 'assistant', 'content': 'Здравствуйте!'},
      });
    });
    final repository = AiAssistantRepository(dio);

    final quote = await repository.quoteCredits(
      message: 'Привет',
      requestId: requestId,
    );
    expect(quote.processingMode, AiAssistantProcessingMode.local);
    expect(quote.amount, '0.00');
    final request = await repository.sendMessageRequest(
      message: 'Привет',
      requestId: requestId,
      quoteId: quote.id,
    );
    expect(request.runStatus, 'completed');
    expect(request.result?.message?.content, 'Здравствуйте!');
  });

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
      ),
      throwsException,
    );
  });

  test('loads only a scoped active request from first history page', () async {
    const requestId = '2962344c-2256-4315-99f1-638ffb026a3e';
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((request) {
      expect(request.queryParameters['contract_version'], 1);
      return {
        'success': true,
        'data': [],
        'meta': {
          'active_request': {
            'request_id': requestId,
            'conversation_id': 12,
            'status': 'running',
            'run_status': 'queued',
          },
        },
      };
    });
    final repository = AiAssistantRepository(dio);
    final first = await repository.fetchMessages(12);
    final older = await repository.fetchMessages(12, page: 2);
    final unknown = await repository.fetchMessages(13);

    expect(first.activeRequest?.requestId, requestId);
    expect(first.activeRequest?.runStatus, 'queued');
    expect(older.activeRequest, isNull);
    expect(unknown.activeRequest, isNull);
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
        'run_status': 'completed',
        'stage': 'completed',
        'progress': [
          {'id': 31, 'code': 'estimates', 'state': 'completed'},
          {'id': 32, 'code': 'warehouse', 'state': 'completed'},
        ],
        'response': {
          'request_id': 'request-1',
          'conversation_id': 12,
          'contract_version': 1,
          'outcome': 'ok',
          'coverage': {'status': 'found'},
          'billing': {'charged_minor': 23},
          'source_refs': [
            {
              'entity_type': 'schedule_task',
              'content_scope': 'structured',
              'display_label': 'График корпуса',
            },
          ],
          'presentation': {
            'version': 1,
            'blocks': [
              {
                'id': 'dates',
                'type': 'facts',
                'source_refs': [0],
                'data': {
                  'items': [
                    {
                      'key': 'end',
                      'label': 'Завершение',
                      'value': {'kind': 'date', 'value': '2026-11-30'},
                    },
                  ],
                },
              },
            ],
          },
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
    );
    expect(accepted.status, 'running');
    expect(accepted.runStatus, 'queued');
    expect(accepted.result, isNull);
    expect(accepted.progress.single.code, 'estimates');
    expect(accepted.progress.single.state, 'started');
    expect((requests.first.data as Map)['async'], true);
    final completed = await repository.fetchChatRequest('request-1');
    expect(completed.result!.message!.content, 'Готово');
    expect(completed.result!.message!.publication?.coverageStatus, 'found');
    expect(completed.result!.message!.presentation?.blocks.single.id, 'dates');
    expect(
      completed.result!.message!.presentationSources[0]?.label,
      'График корпуса',
    );
    expect(completed.result!.publication?.chargedMinor, 23);
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
        );
      }
      expect(payloads, hasLength(2));
      expect(payloads[1], payloads[0]);
      expect(payloads[1]['request_id'], 'same-id');
      expect(payloads[1]['quote_id'], 'same-quote');
    },
  );

  test('accepts terminal POST replay with no assistant message', () async {
    for (final (status, errorCode) in [
      ('cancelled', 'request_cancelled'),
      ('failed', 'request_failed'),
    ]) {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((request) {
        requests.add(request);
        return _responseData({
          'request_id': 'same-id',
          'conversation_id': 12,
          'status': status,
          'run_status': status,
          'stage': status,
          'error_code': errorCode,
        });
      });
      final result = await AiAssistantRepository(dio).sendMessageRequest(
        message: 'Вопрос',
        requestId: 'same-id',
        conversationId: 12,
        quoteId: 'same-quote',
      );

      expect(result.requestId, 'same-id');
      expect(result.runStatus, status);
      expect(result.isTerminal, isTrue);
      expect(result.errorCode, errorCode);
      expect(result.result, isNull);
      expect(requests.single.method, 'POST');
    }
  });

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

  test('cancels by preview token and requires a cancelled outcome', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    var status = 'executed';
    var statusCode = 200;
    dio.httpClientAdapter = _JsonAdapter((request) {
      requests.add(request);
      return _responseData({'status': status});
    }, statusCode: (_) => statusCode);
    const actionId = 'fcfc7e05-7fde-401d-a979-30d649af529b';
    final token = List.filled(64, 'x').join();
    final preview = AiActionPreviewModel.fromJson({
      'action': {
        'id': actionId,
        'tool_name': 'create_task',
        'arguments': {'project_id': 2},
      },
      'preview_token': token,
    });
    final repository = AiAssistantRepository(dio);
    Future<void> cancel() =>
        repository.cancelAction(preview: preview, conversationId: 12);

    await expectLater(cancel(), throwsA(isA<ApiException>()));
    statusCode = 404;
    await expectLater(
      cancel(),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'code', 404),
      ),
    );
    statusCode = 200;
    status = 'cancelled';
    await cancel();
    for (final request in requests) {
      expect(request.method, 'POST');
      expect(request.path, '/ai-assistant/actions/cancel');
      expect(request.data, {
        'conversation_id': 12,
        'action': {'id': actionId, 'preview_token': token},
      });
    }
    expect(requests, hasLength(3));
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
        return _responseData({
          'request_id': 'request-uuid',
          'stage': 'searching',
          'status': 'running',
        });
      });
      final repository = AiAssistantRepository(dio);
      await repository.updateParticipants(12, [
        const AiConversationParticipantModel(userId: '5', role: 'viewer'),
      ]);
      await repository.fetchChatRequest('request-uuid');
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

  test(
    'cancel uses the current auth token and sends only contract version',
    () async {
      final storage = _MutableSecureStorage('old-organization-token');
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final requests = <RequestOptions>[];
      final dio = container.read(dioProvider);
      dio.httpClientAdapter = _JsonAdapter((request) {
        requests.add(request);
        return _responseData({
          'request_id': 'request-uuid',
          'status': 'cancelled',
        });
      });
      final repository = AiAssistantRepository(dio);

      storage.token = 'current-organization-token';
      await repository.cancelRequest('request-uuid');

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(
        requests.single.path,
        '/ai-assistant/requests/request-uuid/cancel',
      );
      expect(
        requests.single.headers['Authorization'],
        'Bearer current-organization-token',
      );
      expect(requests.single.queryParameters, isEmpty);
      expect(requests.single.data, {'contract_version': 1});
      expect(
        requests.single.headers.keys.any(
          (key) => key.toLowerCase().contains('organization'),
        ),
        isFalse,
      );
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

  test(
    'document fragment uses its ordinal and verifies response identity',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      var expectedMessage = '17';
      dio.httpClientAdapter = _JsonAdapter((request) {
        expect(request.method, 'GET');
        expect(
          request.path,
          '/ai-assistant/conversations/12/messages/17/sources/2',
        );
        return _responseData({
          'message_id': expectedMessage,
          'source_index': 2,
          'kind': 'source_chunk_preview',
          'title': 'Протокол',
          'content': 'Условие из протокола.',
          'content_range': {'truncated': true},
        });
      });
      final repository = AiAssistantRepository(dio);
      final preview = await repository.fetchSourcePreview(
        conversationId: 12,
        messageId: 17,
        sourceIndex: 2,
      );
      expect(preview.content, 'Условие из протокола.');
      expect(preview.truncated, isTrue);

      expectedMessage = '18';
      await expectLater(
        repository.fetchSourcePreview(
          conversationId: 12,
          messageId: 17,
          sourceIndex: 2,
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );
}

class _MutableSecureStorage extends SecureStorageService {
  _MutableSecureStorage(this.token);

  String? token;

  @override
  Future<String?> getToken() async => token;
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
