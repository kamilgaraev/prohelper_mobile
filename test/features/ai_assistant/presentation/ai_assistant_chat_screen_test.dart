import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/network/dio_client.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_chat_screen.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_article_screen.dart';

class _TestSecureStorage extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<void> clearToken() async {}
}

class _OrganizationAuthNotifier extends AuthNotifier {
  _OrganizationAuthNotifier(int organizationId)
    : super(
        AuthRepository(Dio(), _TestSecureStorage()),
        _TestSecureStorage(),
        autoCheckAuth: false,
      ) {
    state = AuthAuthenticated(_user(organizationId));
  }

  static User _user(int organizationId) =>
      User()
        ..serverId = 7
        ..email = 'test@example.test'
        ..name = 'Test'
        ..organizationsJson = '[]'
        ..roles = const []
        ..permissionsJson = '{}'
        ..currentOrganizationId = organizationId;

  void setOrganization(int organizationId) {
    state = AuthAuthenticated(_user(organizationId));
  }

  void setActor(int actorId) {
    state = AuthAuthenticated(
      _user(state.user!.currentOrganizationId!)..serverId = actorId,
    );
  }

  @override
  Future<void> checkAuth() async {}
}

void main() {
  Future<void> toggleProgressHistory(WidgetTester tester) async {
    final tile = find.descendant(
      of: find.byType(ExpansionTile),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(tile);
    await tester.tap(tile);
  }

  Widget buildScreen(AiAssistantRepository repository, {ThemeData? theme}) {
    return ProviderScope(
      overrides: [aiAssistantRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: theme,
        home: const AiAssistantChatScreen(conversationId: 1),
      ),
    );
  }

  testWidgets('keeps user message readable on primary bubble', (tester) async {
    final repository = _AiAssistantRepository(
      messages: [
        AiMessageModel(
          id: 7,
          role: 'user',
          content: 'Запрос по проекту',
          createdAt: DateTime(2026, 5, 22),
        ),
      ],
    );
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
      ).copyWith(primary: Colors.blue.shade800, onPrimary: Colors.black),
    );

    await tester.pumpWidget(buildScreen(repository, theme: theme));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('Запрос по проекту'));

    expect(text.style?.color, Colors.white);
  });

  testWidgets('shows answer and navigable record without validation metadata', (
    tester,
  ) async {
    final repository = _AiAssistantRepository(
      messages: [
        const AiMessageModel(
          id: 21,
          role: 'assistant',
          content: 'Здравствуйте. Чем помочь?',
          createdAt: null,
          metadata: {
            'validation_status': 'partial',
            'entity_references': [
              {'id': '77', 'type': 'project', 'label': 'Проект Север'},
            ],
            'source_refs': [
              {
                'title': 'Открыть карточку проекта',
                'url': '/dashboard/projects/77',
              },
              {'title': 'Служебные сведения', 'excerpt': 'Внутренний текст'},
            ],
          },
        ),
      ],
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    expect(find.text('Здравствуйте. Чем помочь?'), findsOneWidget);
    expect(find.text('Открыть карточку проекта'), findsOneWidget);
    expect(find.text('Частично проверено'), findsNothing);
    expect(find.text('Проект Север'), findsNothing);
    expect(find.text('Служебные сведения'), findsNothing);
    expect(find.text('Внутренний текст'), findsNothing);
  });

  testWidgets('renders v1 limitations, selected blocks, and one source entry', (
    tester,
  ) async {
    const source = {
      'entity_id': 7,
      'entity_type': 'schedule_task',
      'content_scope': 'structured',
      'display_label': 'Рабочий график',
    };
    final repository = _AiAssistantRepository(
      messages: [
        AiMessageModel.fromJson({
          'id': 41,
          'role': 'assistant',
          'content': 'Сроки найдены.',
          'source_refs': [null, source, source],
          'metadata': {
            'contract_version': 1,
            'outcome': 'ambiguous',
            'coverage': {'status': 'partial'},
            'evidence': [
              {'source_ref': source},
            ],
            'ui_actions': [
              {'type': 'reveal_source', 'label': 'Показать работу'},
            ],
          },
          'presentation': {
            'version': 1,
            'blocks': [
              {
                'id': 'lead',
                'type': 'text',
                'source_refs': [1],
                'data': {'text': 'Сроки найдены.'},
              },
              {
                'id': 'invalid',
                'type': 'list',
                'source_refs': [3],
                'data': {
                  'items': [
                    {'id': 'invalid', 'title': 'Неверная ссылка'},
                  ],
                },
              },
              {
                'id': 'future-block',
                'type': 'future-block',
                'source_refs': [1],
                'data': {'text': 'Блок будущей версии'},
              },
              {
                'id': 'facts',
                'type': 'facts',
                'source_refs': [1],
                'data': {
                  'items': [
                    {
                      'key': 'start',
                      'label': 'Дата начала',
                      'value': {'kind': 'date', 'value': '2026-11-24'},
                    },
                  ],
                },
              },
              {
                'id': 'list',
                'type': 'list',
                'source_refs': [2],
                'data': {
                  'items': [
                    {'id': 'work', 'title': 'Монтаж', 'status': 'В работе'},
                  ],
                },
              },
              {
                'id': 'table',
                'type': 'table',
                'source_refs': [1, 2],
                'data': {
                  'columns': [
                    {'key': 'price', 'label': 'По смете'},
                  ],
                  'rows': [
                    {
                      'id': 'row',
                      'cells': {
                        'price': {
                          'kind': 'decimal',
                          'value': '1200.0100',
                          'currency': 'RUB',
                          'vat': 'included',
                        },
                      },
                      'source_refs': [2],
                    },
                  ],
                },
              },
            ],
          },
        }),
      ],
    );
    await tester.pumpWidget(buildScreen(repository, theme: ThemeData.dark()));
    await tester.pumpAndSettle();

    final answer = find.text('Сроки найдены.');
    final coverage = find.text('Проверена часть доступных данных.');
    final facts = find.text('2026-11-24');
    final listItem = find.text('Монтаж');
    final tableValue = find.text('1200,0100 RUB (с НДС)');
    final sourceLabel = find.text('[1] Рабочий график');
    for (final element in [
      answer,
      coverage,
      facts,
      listItem,
      tableValue,
      sourceLabel,
    ]) {
      expect(element, findsOneWidget);
    }
    for (final (top, bottom) in [
      (answer, coverage),
      (coverage, facts),
      (facts, listItem),
      (listItem, tableValue),
      (tableValue, sourceLabel),
    ]) {
      expect(tester.getTopLeft(top).dy, lessThan(tester.getTopLeft(bottom).dy));
    }
    expect(find.text('Найдено несколько совпадений.'), findsOneWidget);
    expect(find.text('Показать работу'), findsOneWidget);
    expect(find.text('Эти действия недоступны в приложении.'), findsOneWidget);
    expect(find.text('Источники'), findsOneWidget);
    expect(find.text('Рабочий график'), findsNothing);
    expect(find.text('Блок будущей версии'), findsNothing);
    expect(find.text('Неверная ссылка'), findsNothing);
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checks document access again when reopening its source', (
    tester,
  ) async {
    const message = <String, dynamic>{
      'id': 41,
      'role': 'assistant',
      'content': 'Условие найдено.',
      'metadata': {
        'decision_contract': 3,
        'source_refs': [
          null,
          {
            'entity_type': 'assistant_document',
            'entity_id': 17,
            'preview_kind': 'source_chunk_preview',
          },
        ],
        'presentation': {
          'version': 1,
          'blocks': [
            {
              'id': 'sources',
              'type': 'sources',
              'source_refs': [1],
              'data': <String, dynamic>{},
            },
          ],
        },
      },
    };
    final dio = Dio(BaseOptions(baseUrl: 'https://mobile.example.test'));
    var reads = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path == '/ai-assistant/conversations/1/history') {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': [message],
                },
              ),
            );
            return;
          }
          expect(
            request.path,
            '/ai-assistant/conversations/1/messages/41/sources/1',
          );
          reads += 1;
          final response = Response(
            requestOptions: request,
            statusCode: reads == 1 ? 200 : 403,
            data: {
              'success': reads == 1,
              'data': {
                'message_id': '41',
                'source_index': 1,
                'kind': 'source_chunk_preview',
                'title': 'Протокол',
                'content': 'Подтверждённый фрагмент.',
              },
            },
          );
          if (reads == 1) {
            handler.resolve(response);
          } else {
            handler.reject(
              DioException.badResponse(
                statusCode: 403,
                requestOptions: request,
                response: response,
              ),
            );
          }
        },
      ),
    );
    final repository = _AiAssistantRepository(
      dio: dio,
      messages: [AiMessageModel.fromJson(message)],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiAssistantRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith((_) => _OrganizationAuthNotifier(12)),
        ],
        child: const MaterialApp(
          home: AiAssistantChatScreen(conversationId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final source = find.text('[1] Документ №17');
    await tester.tap(source);
    await tester.pumpAndSettle();
    expect(find.text('Подтверждённый фрагмент.'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.tap(source);
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Фрагмент источника недоступен.'), findsOneWidget);
    expect(find.text('Подтверждённый фрагмент.'), findsNothing);
  });

  testWidgets('shows action preview before execution', (tester) async {
    final repository = _AiAssistantRepository(
      messages: [
        _assistantMessage(actions: [_allowedAction()]),
      ],
    );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Подготовить'));
    await tester.pumpAndSettle();

    expect(repository.previewCalls, 1);
    expect(repository.executeCalls, 0);
    expect(find.text('Проверить действие'), findsOneWidget);
    expect(find.text('Проект: 77'), findsOneWidget);
    expect(find.text('Выполнить'), findsOneWidget);
  });

  testWidgets('closing preview does not execute or cancel the action', (
    tester,
  ) async {
    final repository = _AiAssistantRepository(
      messages: [
        _assistantMessage(actions: [_allowedAction()]),
      ],
    );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Подготовить'));
    await tester.pumpAndSettle();

    expect(repository.executeCalls, 0);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();

    expect(repository.executeCalls, 0);
    expect(repository.cancelCalls, 0);
    expect(find.text('Проверить действие'), findsNothing);
  });

  testWidgets('keeps preview until server confirms action cancellation', (
    tester,
  ) async {
    final first = Completer<void>();
    final second = Completer<void>();
    final outcomes = [first.future, second.future].iterator;
    final repository = _AiAssistantRepository(
      messages: [
        _assistantMessage(actions: [_allowedAction()]),
      ],
      onCancelAction: () {
        outcomes.moveNext();
        return outcomes.current;
      },
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подготовить'));
    await tester.pumpAndSettle();

    final cancel = find.text('Отменить действие');
    const error = 'Отмена недоступна. Можно закрыть подготовку.';
    await tester.tap(cancel);
    await tester.pump();
    expect(repository.cancelCalls, 1);
    expect(find.text('Проверить действие'), findsOneWidget);
    expect(find.text('Действие отменено.'), findsNothing);
    for (final label in ['Закрыть', 'Отменяем…']) {
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, label),
      );
      expect(button.onPressed, isNull);
    }
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Выполнить'))
          .onPressed,
      isNull,
    );

    first.completeError(const ApiException(error, statusCode: 404));
    await tester.pumpAndSettle();
    expect(find.text(error), findsOneWidget);
    expect(find.text('Проверить действие'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Закрыть'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(cancel);
    await tester.pump();
    expect(repository.cancelCalls, 2);
    second.complete();
    await tester.pumpAndSettle();
    expect(find.text('Проверить действие'), findsNothing);
    expect(find.text(error), findsNothing);
    expect(repository.executeCalls, 0);
  });

  testWidgets('shows permission state for unavailable action', (tester) async {
    final repository = _AiAssistantRepository(
      messages: [
        _assistantMessage(actions: [_blockedAction()]),
      ],
    );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    expect(
      find.text('Недостаточно прав для выполнения действия.'),
      findsOneWidget,
    );
    expect(find.text('Недоступно'), findsOneWidget);
    expect(find.text('Подготовить'), findsNothing);
    expect(repository.previewCalls, 0);
  });
  testWidgets('late answer cannot overwrite a different conversation', (
    tester,
  ) async {
    final repository = _RaceRepository();
    Widget screen(int id) => ProviderScope(
      overrides: [aiAssistantRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: AiAssistantChatScreen(conversationId: id)),
    );
    await tester.pumpWidget(screen(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    expect(
      repository.requestId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(repository.quoteRequestId, repository.requestId);
    await tester.pumpWidget(screen(2));
    await tester.pumpAndSettle();
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: repository.requestId!,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: repository.requestId!,
          conversationId: 1,
          message: const AiMessageModel(
            id: 99,
            role: 'assistant',
            content: 'Late answer',
            createdAt: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Late answer'), findsNothing);
    expect(find.text('Диалог #2'), findsOneWidget);
    expect(repository.cancelledRequestId, isNull);
  });

  testWidgets(
    'network error recovers through GET without another quote or POST',
    (tester) async {
      final repository = _RaceRepository(failFirst: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: AiAssistantChatScreen(conversationId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Question');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продолжить'));
      await tester.pump();
      final firstId = repository.requestId;
      expect(repository.polledIds, contains(firstId));
      expect(repository.sentIds, [firstId]);
      expect(repository.polledIds, contains(firstId));
      expect(repository.quoteCalls, 1);
      repository.answer.complete(
        AiAssistantChatRequest(
          requestId: firstId!,
          status: 'completed',
          result: AiAssistantChatResult(
            requestId: firstId,
            conversationId: 1,
            message: AiMessageModel.fromJson({
              'id': 10,
              'role': 'assistant',
              'content': 'Recovered',
              'metadata': {
                'presentation': {
                  'version': 1,
                  'blocks': [
                    {
                      'id': 'recovered',
                      'type': 'facts',
                      'source_refs': [],
                      'data': {
                        'items': [
                          {
                            'key': 'status',
                            'label': 'Статус',
                            'value': {
                              'kind': 'text',
                              'value': 'Данные получены',
                            },
                          },
                        ],
                      },
                    },
                  ],
                },
              },
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
      expect(find.text('Данные получены'), findsOneWidget);
    },
  );

  testWidgets('202 waits for completed GET and shows answer once', (
    tester,
  ) async {
    final repository = _RaceRepository(asyncAccepted: true);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    expect(repository.polledIds, contains(repository.requestId));
    expect(find.text('Готово'), findsNothing);
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: repository.requestId!,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: repository.requestId!,
          conversationId: 1,
          message: const AiMessageModel(
            id: 100,
            role: 'assistant',
            content: 'Готово',
            createdAt: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Готово'), findsOneWidget);
    expect(repository.sentIds, hasLength(1));
  });

  testWidgets('retries an unaccepted POST with the same request and quote', (
    tester,
  ) async {
    final repository = _RaceRepository(failFirst: true, notSubmittedOnce: true);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    expect(repository.sentIds, [repository.requestId, repository.requestId]);
    expect(repository.quoteCalls, 1);
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: repository.requestId!,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: repository.requestId!,
          conversationId: 1,
          message: const AiMessageModel(
            id: 100,
            role: 'assistant',
            content: 'Повтор принят',
            createdAt: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Повтор принят'), findsOneWidget);
  });

  testWidgets('keeps cancellation pending until a terminal server state', (
    tester,
  ) async {
    final repository = _RaceRepository(
      asyncAccepted: true,
      cancelPending: true,
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.tap(find.text('Стоп'));
    await tester.pump();
    expect(repository.cancelledRequestId, repository.requestId);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.byIcon(Icons.send_rounded),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(repository.sentIds, hasLength(1));
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: repository.requestId!,
        status: 'cancelled',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Стоп'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Question',
    );
  });

  testWidgets(
    'keeps the question and stops resubmitting after quote expiration',
    (tester) async {
      final repository = _RaceRepository(
        failFirst: true,
        notSubmittedOnce: true,
        quoteExpiresAt: DateTime(2020),
      );
      await tester.pumpWidget(buildScreen(repository));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Question');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(repository.sentIds, hasLength(1));
      expect(repository.quoteCalls, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Question',
      );
      expect(find.text('Стоп'), findsNothing);
    },
  );

  testWidgets(
    'shows accepted progress and keeps completed sources after a fast response',
    (tester) async {
      final repository = _RaceRepository(
        asyncAccepted: true,
        initialProgress: const [
          AiAssistantProgressModel(id: 31, code: 'estimates', state: 'started'),
        ],
      );
      await tester.pumpWidget(buildScreen(repository));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Вопрос про бетон');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продолжить'));
      await tester.pump();
      expect(find.text('Проверяю сметы'), findsOneWidget);
      const completedProgress = [
        AiAssistantProgressModel(id: 31, code: 'estimates', state: 'completed'),
        AiAssistantProgressModel(id: 32, code: 'warehouse', state: 'completed'),
        AiAssistantProgressModel(id: 33, code: 'warehouse', state: 'completed'),
        AiAssistantProgressModel(id: 34, code: 'projects', state: 'started'),
      ];
      repository.answer.complete(
        AiAssistantChatRequest(
          requestId: repository.requestId!,
          status: 'completed',
          progress: completedProgress,
          result: AiAssistantChatResult(
            requestId: repository.requestId!,
            conversationId: 1,
            message: const AiMessageModel(
              id: 101,
              role: 'assistant',
              content: 'Ответ про бетон',
              createdAt: null,
            ),
            progress: completedProgress,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ответ про бетон'), findsOneWidget);
      expect(find.text('Сметы проверены'), findsNothing);
      await toggleProgressHistory(tester);
      await tester.pumpAndSettle();
      expect(find.text('Сметы проверены'), findsOneWidget);
      expect(find.text('Склад проверен'), findsOneWidget);
      expect(find.text('Проекты проверены'), findsNothing);
      expect(find.text('Проверяю проекты'), findsNothing);
    },
  );

  testWidgets('keeps the latest 24 events as progress window advances', (
    tester,
  ) async {
    final repeatedEstimates = List<AiAssistantProgressModel>.generate(
      23,
      (index) => AiAssistantProgressModel(
        id: index + 2,
        code: 'estimates',
        state: 'completed',
      ),
    );
    final repository = _RaceRepository(
      asyncAccepted: true,
      initialProgress: [
        const AiAssistantProgressModel(
          id: 1,
          code: 'warehouse',
          state: 'started',
        ),
        ...repeatedEstimates,
      ],
      progressSnapshots: [
        [
          ...repeatedEstimates,
          const AiAssistantProgressModel(
            id: 25,
            code: 'warehouse',
            state: 'completed',
          ),
        ],
      ],
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Вопрос');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    expect(find.text('Проверяю склад'), findsNothing);
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: repository.requestId!,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: repository.requestId!,
          conversationId: 1,
          message: const AiMessageModel(
            id: 102,
            role: 'assistant',
            content: 'Готово',
            createdAt: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await toggleProgressHistory(tester);
    await tester.pumpAndSettle();
    expect(find.text('Склад проверен'), findsOneWidget);
  });

  testWidgets('shows one current activity and elapsed time', (tester) async {
    final repository = _RaceRepository(
      asyncAccepted: true,
      initialProgress: const [
        AiAssistantProgressModel(id: 1, code: 'estimates', state: 'started'),
        AiAssistantProgressModel(id: 2, code: 'estimates', state: 'completed'),
      ],
      stages: ['queued', 'reading', 'tools', 'verifying'],
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('В очереди'), findsOneWidget);
    expect(find.text('Ожидаю начала обработки.'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Анализирую данные'), findsOneWidget);
    expect(find.text('Проверяю сметы'), findsNothing);
    expect(
      find.text('Подбираю сведения, относящиеся к вопросу.'),
      findsNothing,
    );
    expect(find.textContaining('Прошло 00:'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Получаю данные'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Проверяю ответ'), findsOneWidget);
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: repository.requestId!,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: repository.requestId!,
          conversationId: 1,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Прошло '), findsNothing);
    final pollCount = repository.polledIds.length;
    await tester.pump(const Duration(seconds: 3));
    expect(repository.polledIds.length, pollCount);
  });

  testWidgets(
    'restores verified progress and replaces the latest interim result',
    (tester) async {
      const requestId = '2962344c-2256-4315-99f1-638ffb026a3e';
      final repository = _RaceRepository(
        activeRequest: const AiAssistantChatRequest(
          requestId: requestId,
          conversationId: 1,
          status: 'running',
          canonicalStatus: 'running',
        ),
        scriptedStatuses: [
          {
            'run_status': 'running',
            'accepted_at': '2026-11-19T08:00:00Z',
            'elapsed_seconds': 125,
            'progress': [
              {
                'id': 1,
                'key': 'private-record-id',
                'code': 'record_check',
                'state': 'started',
              },
              {
                'id': 2,
                'key': 'private-record-id',
                'code': 'record_check',
                'state': 'completed',
              },
              {'id': 3, 'code': 'estimates', 'state': 'failed'},
              {'id': 4, 'code': 'estimate_position_search', 'state': 'started'},
              {'id': 5, 'code': 'private_tool', 'state': 'completed'},
            ],
            'interim_result': _interimResult(1, 'Проверен первый срок.'),
          },
          StateError('Connection lost'),
          {
            'progress': [
              {
                'id': 6,
                'code': 'estimate_position_search',
                'state': 'completed',
              },
              {'id': 7, 'code': 'estimate_position_read', 'state': 'started'},
            ],
            'interim_result': _interimResult(2, 'Проверены два срока.'),
          },
        ],
      );
      await tester.pumpWidget(buildScreen(repository));
      await tester.pump();
      await tester.pump();

      expect(find.text('Прошло 02:05'), findsOneWidget);
      expect(find.text('Поиск позиций сметы'), findsOneWidget);
      expect(find.text('Промежуточный результат'), findsOneWidget);
      expect(find.text('Проверен первый срок.'), findsOneWidget);
      expect(find.text('По проекту'), findsOneWidget);
      expect(find.text('График работ'), findsOneWidget);
      expect(find.text('Работа продолжается.'), findsOneWidget);
      expect(find.text('Запись проверена'), findsNothing);
      await toggleProgressHistory(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Запись проверена'), findsOneWidget);
      expect(find.text('Не удалось проверить сметы'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      await toggleProgressHistory(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Запись проверена'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Проверяю состояние запроса'), findsOneWidget);
      expect(find.text('Проверен первый срок.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Проверен первый срок.'), findsNothing);
      expect(find.text('Проверены два срока.'), findsOneWidget);
      expect(find.text('Чтение позиции сметы'), findsOneWidget);

      repository.answer.complete(
        AiAssistantChatRequest.fromJson({
          'request_id': requestId,
          'conversation_id': 1,
          'run_status': 'completed',
          'response': {
            'request_id': requestId,
            'conversation_id': 1,
            'result_key': 'answer',
            'message': {
              'id': 81,
              'role': 'assistant',
              'content': 'Проверены два срока.',
            },
          },
        }),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(repository.sentIds, isEmpty);
      expect(find.text('Проверены два срока.'), findsOneWidget);
      expect(find.text('Промежуточный результат'), findsNothing);
      expect(find.text('Работа продолжается.'), findsNothing);
      expect(find.textContaining('Прошло '), findsNothing);
    },
  );

  testWidgets('hides interim text on an empty snapshot and denied status', (
    tester,
  ) async {
    const requestId = '2962344c-2256-4315-99f1-638ffb026a3e';
    final repository = _RaceRepository(
      activeRequest: const AiAssistantChatRequest(
        requestId: requestId,
        conversationId: 1,
        status: 'running',
      ),
      scriptedStatuses: [
        {'interim_result': _interimResult(1, 'Первая проверка.')},
        {'interim_result': null},
        {
          'interim_result': _interimResult(
            2,
            'Вторая проверка.',
            project: false,
          ),
        },
        const ApiException('Нет доступа.', statusCode: 403),
      ],
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pump();
    await tester.pump();
    expect(find.text('Первая проверка.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Промежуточный результат'), findsNothing);
    expect(find.text('Стоп'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Вторая проверка.'), findsOneWidget);
    expect(find.text('По организации'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.text('Диалог недоступен или у пользователя нет прав.'),
      findsOneWidget,
    );
    expect(find.text('Промежуточный результат'), findsNothing);
    expect(find.text('Стоп'), findsNothing);
  });

  testWidgets('fast local turn shows the final reply without polling', (
    tester,
  ) async {
    final repository = _RaceRepository(freeQuote: true);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Привет');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(find.text('Оценка расхода'), findsNothing);
    expect(repository.sentIds, hasLength(1));
    repository.answer.complete(
      AiAssistantChatRequest.fromJson({
        'request_id': repository.requestId,
        'conversation_id': 1,
        'run_status': 'completed',
        'result_key': 'answer',
        'message': {'id': 102, 'role': 'assistant', 'content': 'Здравствуйте!'},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Здравствуйте!'), findsOneWidget);
    expect(find.textContaining('Прошло '), findsNothing);
    expect(find.text('Промежуточный результат'), findsNothing);
    expect(repository.polledIds, isEmpty);
  });

  testWidgets('declining a legacy paid quote keeps the question unsent', (
    tester,
  ) async {
    final repository = _RaceRepository();
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Вопрос');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Оценка расхода'), findsOneWidget);
    expect(repository.sentIds, isEmpty);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(repository.sentIds, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Вопрос',
    );
  });

  testWidgets('v1 completed cancel without a result waits for GET', (
    tester,
  ) async {
    final repository = _RaceRepository(
      asyncAccepted: true,
      freeQuote: true,
      cancelStatus: 'completed',
      cancelRunStatus: 'completed',
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Вопрос');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.tap(find.text('Стоп'));
    await tester.pump();

    expect(repository.cancelledRequestId, repository.requestId);
    expect(repository.polledIds, [repository.requestId]);
    expect(find.text('Стоп'), findsOneWidget);

    final requestId = repository.requestId!;
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: requestId,
        conversationId: 1,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: requestId,
          conversationId: 1,
          message: const AiMessageModel(
            id: 103,
            role: 'assistant',
            content: 'Готовый ответ',
            createdAt: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Готовый ответ'), findsOneWidget);
    expect(find.text('Стоп'), findsNothing);
    expect(repository.sentIds, [requestId]);
  });

  testWidgets('switching chat detaches 202 polling without server cancel', (
    tester,
  ) async {
    final repository = _RaceRepository(asyncAccepted: true);
    Widget screen(int id) => ProviderScope(
      overrides: [aiAssistantRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: AiAssistantChatScreen(conversationId: id)),
    );
    await tester.pumpWidget(screen(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.pumpWidget(screen(2));
    await tester.pumpAndSettle();
    repository.answer.complete(
      AiAssistantChatRequest(
        requestId: repository.requestId!,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: repository.requestId!,
          conversationId: 1,
          message: const AiMessageModel(
            id: 101,
            role: 'assistant',
            content: 'Поздний ответ',
            createdAt: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Поздний ответ'), findsNothing);
    expect(find.text('Диалог #2'), findsOneWidget);
    expect(find.textContaining('Прошло '), findsNothing);
    final pollCount = repository.polledIds.length;
    await tester.pump(const Duration(seconds: 3));
    expect(repository.polledIds.length, pollCount);
    expect(repository.cancelledRequestId, isNull);
  });

  testWidgets('disposing the screen detaches without cancelling the turn', (
    tester,
  ) async {
    final repository = _RaceRepository(asyncAccepted: true);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(repository.cancelledRequestId, isNull);
    expect(repository.sentCancelToken?.isCancelled, isTrue);
  });

  testWidgets('organization change detaches from the old turn', (tester) async {
    final repository = _RaceRepository(asyncAccepted: true);
    final auth = _OrganizationAuthNotifier(4);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          aiAssistantRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: AiAssistantChatScreen(conversationId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    auth.setOrganization(5);
    await tester.pump();
    expect(repository.cancelledRequestId, isNull);
    expect(repository.sentCancelToken?.isCancelled, isTrue);
    expect(find.text('Прошло 00:'), findsNothing);
  });

  testWidgets('reopening a chat watches the active turn from the server', (
    tester,
  ) async {
    const requestId = '2962344c-2256-4315-99f1-638ffb026a3e';
    final repository = _RaceRepository(
      activeRequest: const AiAssistantChatRequest(
        requestId: requestId,
        conversationId: 1,
        status: 'running',
        canonicalStatus: 'queued',
      ),
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pump();
    await tester.pump();

    expect(repository.polledIds, [requestId]);
    expect(repository.sentIds, isEmpty);
    expect(find.text('Стоп'), findsOneWidget);

    repository.answer.complete(
      const AiAssistantChatRequest(
        requestId: requestId,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: requestId,
          conversationId: 1,
          message: AiMessageModel(
            id: 72,
            role: 'assistant',
            content: 'Запрос завершён после возвращения.',
            createdAt: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Запрос завершён после возвращения.'), findsOneWidget);
    expect(find.text('Стоп'), findsNothing);
    expect(repository.cancelledRequestId, isNull);
  });

  testWidgets('reopens a draft turn saved for the signed-in organization', (
    tester,
  ) async {
    const requestId = '2962344c-2256-4315-99f1-638ffb026a3e';
    FlutterSecureStorage.setMockInitialValues({
      'assistant_draft_request_7_4': requestId,
      'assistant_draft_request_7_5': 'bfb62fbc-e2cb-49f3-95aa-b169bb5538ce',
    });
    final repository = _RaceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => _OrganizationAuthNotifier(4)),
          aiAssistantRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AiAssistantChatScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(repository.polledIds, [requestId]);
    expect(repository.sentIds, isEmpty);

    repository.answer.complete(
      const AiAssistantChatRequest(requestId: requestId, status: 'cancelled'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Запрос остановлен.'), findsOneWidget);
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'assistant_draft_request_7_4'), isNull);
    expect(await storage.read(key: 'assistant_draft_request_7_5'), isNotNull);
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('merges delayed draft history with the next completed turn', (
    tester,
  ) async {
    const requestId = '2962344c-2256-4315-99f1-638ffb026a3e';
    const recovered = AiMessageModel(
      id: 72,
      role: 'assistant',
      content: 'Первый ответ',
      createdAt: null,
    );
    const followUp = AiMessageModel(
      id: 74,
      role: 'assistant',
      content: 'Следующий ответ',
      createdAt: null,
    );
    final history = Completer<AiConversationDetailsModel>();
    final nextResponse = Completer<AiAssistantChatRequest>();
    final repository = _RaceRepository(
      freeQuote: true,
      delayedConversation: history.future,
      postResponse: nextResponse.future,
    );
    FlutterSecureStorage.setMockInitialValues({
      'assistant_draft_request_7_4': requestId,
    });
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => _OrganizationAuthNotifier(4)),
          aiAssistantRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AiAssistantChatScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    repository.answer.complete(
      const AiAssistantChatRequest(
        requestId: requestId,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: requestId,
          conversationId: 1,
          message: recovered,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Первый ответ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Следующий вопрос');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    final nextId = repository.sentIds.single;
    nextResponse.complete(
      AiAssistantChatRequest(
        requestId: nextId,
        status: 'completed',
        result: AiAssistantChatResult(
          requestId: nextId,
          conversationId: 1,
          message: followUp,
        ),
      ),
    );
    await tester.pumpAndSettle();
    history.complete(
      AiConversationDetailsModel(
        conversation: const AiConversationModel(
          id: 1,
          title: 'Chat',
          createdAt: null,
          updatedAt: null,
        ),
        messages: [
          const AiMessageModel(
            id: 71,
            role: 'user',
            content: 'Восстановленный вопрос',
            createdAt: null,
          ),
          recovered,
          AiMessageModel(
            id: 73,
            role: 'user',
            content: 'Следующий вопрос',
            createdAt: null,
            metadata: {'request_id': nextId},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final messages = [
      find.text('Восстановленный вопрос'),
      find.text('Первый ответ'),
      find.text('Следующий вопрос'),
      find.text('Следующий ответ'),
    ];
    for (final message in messages) {
      expect(message, findsOneWidget);
    }
    final positions =
        messages.map((message) => tester.getTopLeft(message).dy).toList();
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('published reveal is noninteractive without mobile adapter', (
    tester,
  ) async {
    final repository = _AiAssistantRepository(
      messages: [
        AiMessageModel.fromJson({
          'id': 51,
          'role': 'assistant',
          'content': 'Найдена работа.',
          'metadata': {
            'contract_version': 1,
            'outcome': 'ok',
            'coverage': {'status': 'partial'},
            'source_refs': [
              {
                'title': 'Непроверенная ссылка',
                'url': '/dashboard/projects/77',
              },
            ],
            'evidence': [
              {
                'source_ref': {'title': 'Рабочий график'},
              },
            ],
            'ui_actions': [
              {
                'type': 'reveal_source',
                'label': 'Показать работу',
                'surface': 'mobile',
                'target': 'https://example.test/arbitrary',
              },
            ],
          },
        }),
      ],
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.text('Рабочий график'), findsOneWidget);
    expect(find.text('Показать работу'), findsOneWidget);
    expect(find.text('Эти действия недоступны в приложении.'), findsOneWidget);
    expect(find.text('Непроверенная ссылка'), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
  });

  testWidgets('queued export task does not offer the file download', (
    tester,
  ) async {
    final repository = _AiAssistantRepository(
      messages: [
        AiMessageModel.fromJson({
          'id': 52,
          'role': 'assistant',
          'content': 'Собираю отчёт.',
          'metadata': {
            'contract_version': 1,
            'export_task': {
              'task_id': 'f6d3412e-5b13-4426-b77f-de8a5e81736d',
              'title': 'График работ',
              'status': 'queued',
              'url':
                  '/ai-assistant/report-tasks/f6d3412e-5b13-4426-b77f-de8a5e81736d',
            },
          },
        }),
      ],
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.text('График работ'), findsOneWidget);
    expect(
      find.text('Отчёт готовится. Статус доступен в админке.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('opens a checked chat article through the strict mobile GET', (
    tester,
  ) async {
    final auth = _OrganizationAuthNotifier(11);
    final requests = <RequestOptions>[];
    var statusCode = 200;
    await tester.pumpWidget(
      _knowledgeArticleChat(
        auth: auth,
        articleResponse: (request) async {
          requests.add(request);
          return statusCode;
        },
      ),
    );
    await tester.pumpAndSettle();

    final articleLink = find.widgetWithText(TextButton, 'Порядок работ');
    expect(articleLink, findsOneWidget);
    expect(find.text('Проект Север'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Проект Север'), findsNothing);
    expect(find.text('Внешняя ссылка'), findsNothing);
    expect(requests, isEmpty);

    await tester.ensureVisible(articleLink);
    await tester.tap(articleLink);
    await tester.pumpAndSettle();

    final articleScreen = find.byType(KnowledgeArticleScreen);
    expect(articleScreen, findsOneWidget);
    expect(
      tester.widget<KnowledgeArticleScreen>(articleScreen).slug,
      'Field_1-С',
    );
    expect(find.text('Порядок работ'), findsNWidgets(2));
    expect(find.text('Откройте раздел и создайте заявку.'), findsOneWidget);
    expect(find.text('Статья помогла?'), findsNothing);
    expect(requests.single.method, 'GET');
    expect(requests.single.followRedirects, isFalse);
    expect(
      requests.single.uri.toString(),
      'https://mobile.example.test/api/v1/mobile/ai-assistant/knowledge/articles/Field_1-%D0%A1',
    );

    statusCode = 404;
    final refresh =
        tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
    await tester.pumpAndSettle();
    await refresh;
    expect(requests, hasLength(2));
    expect(find.text('Статья недоступна.'), findsOneWidget);
    expect(find.text('Откройте раздел и создайте заявку.'), findsNothing);
    expect(find.text('Порядок работ'), findsNothing);
  });

  for (final (statusCode, serverMessage, userMessage) in [
    (401, 'Unauthorized.', 'Статья недоступна.'),
    (
      500,
      'FormatException: malformed article payload',
      'Не удалось выполнить действие. Попробуйте еще раз.',
    ),
  ]) {
    testWidgets('hides raw article errors from HTTP $statusCode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _knowledgeArticleChat(
          auth: _OrganizationAuthNotifier(11),
          articleResponse: (_) async => statusCode,
          articleErrorMessage: serverMessage,
        ),
      );
      await tester.pumpAndSettle();
      final link = find.widgetWithText(TextButton, 'Порядок работ');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.byType(KnowledgeArticleScreen), findsOneWidget);
      expect(find.text('Не удалось открыть статью'), findsOneWidget);
      expect(find.text(userMessage), findsOneWidget);
      expect(find.text(serverMessage, findRichText: true), findsNothing);
      expect(find.text('Откройте раздел и создайте заявку.'), findsNothing);
    });
  }

  testWidgets('hides a loaded chat article after the organization changes', (
    tester,
  ) async {
    final auth = _OrganizationAuthNotifier(11);
    var requests = 0;
    await tester.pumpWidget(
      _knowledgeArticleChat(
        auth: auth,
        articleResponse: (_) async {
          requests++;
          return 200;
        },
      ),
    );
    await tester.pumpAndSettle();
    final link = find.widgetWithText(TextButton, 'Порядок работ');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Откройте раздел и создайте заявку.'), findsOneWidget);

    auth.setOrganization(12);
    await tester.pumpAndSettle();
    auth.setOrganization(11);
    await tester.pumpAndSettle();

    expect(find.text('Статья недоступна.'), findsOneWidget);
    expect(find.text('Откройте раздел и создайте заявку.'), findsNothing);
    expect(find.text('Порядок работ'), findsNothing);
    expect(requests, 1);
  });

  testWidgets('drops a delayed chat article after the actor changes', (
    tester,
  ) async {
    final auth = _OrganizationAuthNotifier(11);
    final pendingResponse = Completer<int>();
    await tester.pumpWidget(
      _knowledgeArticleChat(
        auth: auth,
        articleResponse: (_) => pendingResponse.future,
      ),
    );
    await tester.pumpAndSettle();
    final link = find.widgetWithText(TextButton, 'Порядок работ');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Открываем статью'), findsOneWidget);

    auth.setActor(8);
    await tester.pump();
    pendingResponse.complete(200);
    await tester.pumpAndSettle();

    expect(find.text('Статья недоступна.'), findsOneWidget);
    expect(find.text('Откройте раздел и создайте заявку.'), findsNothing);
    expect(find.text('Порядок работ'), findsNothing);
  });

  testWidgets('forbidden status polling stops instead of retrying', (
    tester,
  ) async {
    final repository = _RaceRepository(
      asyncAccepted: true,
      pollErrorStatusCode: 403,
    );
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(
      find.text('Диалог недоступен или у пользователя нет прав.'),
      findsOneWidget,
    );
    expect(repository.polledIds, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    expect(repository.polledIds, hasLength(1));
    expect(find.text('Стоп'), findsNothing);
  });

  testWidgets('Stop explicitly cancels accepted request', (tester) async {
    final repository = _RaceRepository(asyncAccepted: true);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Стоп'));
    await tester.pump();
    expect(repository.cancelledRequestId, repository.requestId);
    expect(find.textContaining('Прошло '), findsNothing);
    final pollCount = repository.polledIds.length;
    await tester.pump(const Duration(seconds: 3));
    expect(repository.polledIds.length, pollCount);
  });

  testWidgets('failed and cancelled requests stop waiting', (tester) async {
    for (final status in ['failed', 'cancelled']) {
      final repository = _RaceRepository(asyncAccepted: true);
      await tester.pumpWidget(buildScreen(repository));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Question');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продолжить'));
      await tester.pump();
      repository.answer.complete(
        AiAssistantChatRequest(
          requestId: repository.requestId!,
          status: status,
          errorCode: 'provider_error',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          status == 'failed'
              ? 'Ассистент не смог подготовить ответ. Попробуйте новый запрос.'
              : 'Запрос остановлен.',
        ),
        findsOneWidget,
      );
      expect(find.text('Стоп'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('terminal POST replay restores the question without retrying', (
    tester,
  ) async {
    for (final (status, errorCode, notice) in [
      ('cancelled', 'request_cancelled', 'Запрос остановлен.'),
      (
        'failed',
        'request_failed',
        'Ассистент не смог подготовить ответ. Попробуйте новый запрос.',
      ),
    ]) {
      final repository = _RaceRepository(freeQuote: true);
      await tester.pumpWidget(buildScreen(repository));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Вопрос');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      repository.answer.complete(
        AiAssistantChatRequest.fromJson({
          'request_id': repository.requestId,
          'conversation_id': 1,
          'status': status,
          'run_status': status,
          'stage': status,
          'error_code': errorCode,
        }),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text(notice), findsOneWidget);
      expect(find.text('Ассистент готов'), findsOneWidget);
      expect(find.text('Стоп'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Вопрос',
      );
      expect(repository.sentIds, [repository.requestId]);
      expect(repository.polledIds, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('pending server cancellation disables Stop with running status', (
    tester,
  ) async {
    final repository = _RaceRepository(freeQuote: true);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Вопрос');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    repository.answer.complete(
      AiAssistantChatRequest.fromJson({
        'request_id': repository.requestId,
        'conversation_id': 1,
        'status': 'cancel_requested',
        'run_status': 'running',
        'stage': 'generating',
      }),
    );
    await tester.pump();

    expect(find.text('Останавливаю обработку'), findsOneWidget);
    final stop = find.ancestor(
      of: find.text('Стоп'),
      matching: find.byWidgetPredicate((widget) => widget is TextButton),
    );
    expect(tester.widget<TextButton>(stop).onPressed, isNull);
    expect(repository.cancelledRequestId, isNull);
    expect(repository.polledIds, [repository.requestId]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reports zero actual charge in shadow mode without claiming payment',
    (tester) async {
      final repository = _RaceRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: AiAssistantChatScreen(conversationId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Question');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Оценка расхода'), findsOneWidget);
      await tester.tap(find.text('Продолжить'));
      await tester.pump();
      repository.answer.complete(
        AiAssistantChatRequest(
          requestId: repository.requestId!,
          status: 'completed',
          result: AiAssistantChatResult(
            requestId: repository.requestId!,
            conversationId: 1,
            creditUsage: const AiCreditUsageModel(
              actualCharge: '0.00',
              chargingEnabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Списания выключены. За этот запрос списано 0 ед. МОСТ.'),
        findsOneWidget,
      );
      expect(find.textContaining('Списано: 0'), findsNothing);
    },
  );

  testWidgets('shows server deadline in detailed quote confirmation', (
    tester,
  ) async {
    final repository = _RaceRepository(processingDeadlineSeconds: 630);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подробный ответ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Подробный анализ: ожидание до 10 мин 30 сек.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Подробный анализ: ожидание до 10 мин 30 сек.'),
      findsNothing,
    );
  });

  testWidgets('does not show server deadline for the normal profile', (
    tester,
  ) async {
    final repository = _RaceRepository(processingDeadlineSeconds: 630);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Оценка расхода'), findsOneWidget);
    expect(find.textContaining('Подробный анализ: ожидание'), findsNothing);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });

  testWidgets('viewer sees history without message composer', (tester) async {
    final repository = _RaceRepository(canWrite: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiAssistantRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: AiAssistantChatScreen(conversationId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Доступ только для просмотра.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Доступ к чату'), findsNothing);
  });
}

Widget _knowledgeArticleChat({
  required _OrganizationAuthNotifier auth,
  required Future<int> Function(RequestOptions) articleResponse,
  String? articleErrorMessage,
}) {
  final dio = Dio(
    BaseOptions(baseUrl: 'https://mobile.example.test/api/v1/mobile'),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        const articlePath = '/ai-assistant/knowledge/articles/Field_1-%D0%A1';
        final (data, statusCode) = switch (options.path) {
          '/ai-assistant/conversations/1' => (
            {
              'conversation': {'id': 1, 'title': 'Диалог'},
              'messages': [
                {
                  'id': 52,
                  'role': 'assistant',
                  'content': 'Нашёл инструкцию.',
                  'metadata': {
                    'contract_version': 1,
                    'outcome': 'ok',
                    'evidence': [
                      {'title': 'Проект Север'},
                    ],
                    'source_refs': [
                      {
                        'source_type': 'knowledge',
                        'entity_type': 'knowledge_article',
                        'display_label': 'Порядок работ',
                        'navigation': {
                          'url': '/dashboard/help/knowledge/Field_1-%D0%A1',
                        },
                      },
                      {
                        'source_type': 'knowledge',
                        'entity_type': 'knowledge_article',
                        'display_label': 'Внешняя ссылка',
                        'navigation': {
                          'url':
                              'https://external.example.test/dashboard/help/knowledge/Field_1-%D0%A1',
                        },
                      },
                    ],
                  },
                },
              ],
            },
            200,
          ),
          articlePath => (
            {
              'id': 41,
              'slug': 'Field_1-С',
              'title': 'Порядок работ',
              'plain_text': 'Откройте раздел и создайте заявку.',
            },
            await articleResponse(options),
          ),
          _ => (null, 404),
        };
        final response = Response(
          requestOptions: options,
          statusCode: statusCode,
          data: {
            'success': statusCode == 200,
            'data': data,
            if (options.path == articlePath &&
                statusCode != 200 &&
                articleErrorMessage != null)
              'message': articleErrorMessage,
          },
        );
        if (statusCode == 200) {
          handler.resolve(response);
        } else {
          handler.reject(
            DioException.badResponse(
              statusCode: statusCode,
              requestOptions: options,
              response: response,
            ),
          );
        }
      },
    ),
  );
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((_) => auth),
      dioProvider.overrideWithValue(dio),
    ],
    child: const MaterialApp(home: AiAssistantChatScreen(conversationId: 1)),
  );
}

class _AiAssistantRepository extends AiAssistantRepository {
  _AiAssistantRepository({
    required this.messages,
    Dio? dio,
    this.onCancelAction,
  }) : super(dio ?? Dio());

  final List<AiMessageModel> messages;
  final Future<void> Function()? onCancelAction;
  int previewCalls = 0;
  int executeCalls = 0;
  int cancelCalls = 0;

  @override
  Future<AiConversationDetailsModel> fetchConversation(int id) async {
    return AiConversationDetailsModel(
      conversation: AiConversationModel(
        id: id,
        title: 'Диалог',
        createdAt: DateTime(2026, 5, 22),
        updatedAt: DateTime(2026, 5, 22),
      ),
      messages: messages,
    );
  }

  @override
  Future<AiActionPreviewModel> previewAction({
    required AiAssistantActionModel action,
    int? conversationId,
  }) async {
    previewCalls += 1;

    return AiActionPreviewModel(
      title: 'Проверить действие',
      description: 'Создание задачи графика',
      requiresConfirmation: true,
      actionClass: 'confirm',
      action: action,
      warnings: const [],
      summaryItems: const [AiActionSummaryItem(label: 'Проект', value: '77')],
      executable: true,
      previewToken: 'signed-preview-token',
    );
  }

  @override
  Future<AiActionExecutionModel> executeAction({
    required AiActionPreviewModel preview,
    int? conversationId,
  }) async {
    executeCalls += 1;

    return const AiActionExecutionModel(messageText: 'Действие выполнено.');
  }

  @override
  Future<void> cancelAction({
    required AiActionPreviewModel preview,
    required int conversationId,
  }) async {
    cancelCalls += 1;
    await onCancelAction?.call();
  }
}

AiMessageModel _assistantMessage({
  required List<AiAssistantActionModel> actions,
}) {
  return AiMessageModel(
    id: 10,
    role: 'assistant',
    content: 'Можно выполнить действие',
    createdAt: DateTime(2026, 5, 22),
    structuredPayload: AiAssistantStructuredPayload(actions: actions),
  );
}

AiAssistantActionModel _allowedAction() {
  return const AiAssistantActionModel(
    id: 'schedule-1',
    type: 'act',
    label: 'Создать задачу графика',
    allowed: true,
    requiresConfirmation: true,
    actionClass: 'confirm',
    toolName: 'create_schedule_task',
    arguments: {'project_id': 77},
  );
}

AiAssistantActionModel _blockedAction() {
  return const AiAssistantActionModel(
    id: 'schedule-1',
    type: 'act',
    label: 'Создать задачу графика',
    allowed: false,
    reasonIfDisabled: 'Недостаточно прав для выполнения действия.',
    requiresConfirmation: true,
    actionClass: 'confirm',
    toolName: 'create_schedule_task',
    arguments: {'project_id': 77},
  );
}

Map<String, dynamic> _interimResult(
  int revision,
  String text, {
  bool project = true,
}) => {
  'key': 'answer',
  'revision': revision,
  'text': text,
  'scope': {
    'kind': project ? 'project' : 'organization',
    if (project) 'project_id': 17,
  },
  'sources': [
    {'label': 'График работ'},
  ],
  'published_at': '2026-11-19T08:01:00Z',
};

class _RaceRepository extends AiAssistantRepository {
  _RaceRepository({
    this.canWrite = true,
    this.failFirst = false,
    this.asyncAccepted = false,
    this.stages = const [],
    this.freeQuote = false,
    this.processingDeadlineSeconds,
    this.initialProgress = const [],
    this.progressSnapshots = const [],
    this.pollErrorStatusCode,
    this.notSubmittedOnce = false,
    this.cancelPending = false,
    this.cancelStatus,
    this.cancelRunStatus,
    this.quoteExpiresAt,
    this.activeRequest,
    this.delayedConversation,
    this.postResponse,
    this.scriptedStatuses = const [],
  }) : super(Dio());
  final bool canWrite;
  final bool failFirst;
  final bool asyncAccepted;
  final bool freeQuote;
  final int? processingDeadlineSeconds;
  final List<String> stages;
  final List<AiAssistantProgressModel> initialProgress;
  final List<List<AiAssistantProgressModel>> progressSnapshots;
  final int? pollErrorStatusCode;
  final bool notSubmittedOnce;
  final bool cancelPending;
  final String? cancelStatus;
  final String? cancelRunStatus;
  final DateTime? quoteExpiresAt;
  final AiAssistantChatRequest? activeRequest;
  final Future<AiConversationDetailsModel>? delayedConversation;
  final Future<AiAssistantChatRequest>? postResponse;
  final List<Object> scriptedStatuses;
  int _stageIndex = 0;
  int _progressIndex = 0;
  int _statusIndex = 0;
  int quoteCalls = 0;
  final sentIds = <String>[];
  final answer = Completer<AiAssistantChatRequest>();
  final polledIds = <String>[];
  String? requestId;
  String? quoteRequestId;
  String? cancelledRequestId;
  CancelToken? sentCancelToken;
  @override
  Future<AiConversationDetailsModel> fetchConversation(int id) async {
    final pending = delayedConversation;
    if (pending != null) return pending;
    return AiConversationDetailsModel(
      conversation: AiConversationModel(
        id: id,
        title: 'Chat',
        createdAt: null,
        updatedAt: null,
        canWrite: canWrite,
      ),
      messages: const [],
      activeRequest: activeRequest,
    );
  }

  @override
  Future<AiAssistantPage<AiMessageModel>> fetchMessages(
    int conversationId, {
    int page = 1,
  }) async => const AiAssistantPage(items: []);
  @override
  Future<AiCreditQuoteModel> quoteCredits({
    required String message,
    required String requestId,
    String profile = 'normal',
    bool allowActions = true,
    int? conversationId,
    Map<String, dynamic>? context,
    List<String> attachmentIds = const <String>[],
  }) async {
    quoteCalls++;
    quoteRequestId = requestId;
    return AiCreditQuoteModel(
      id: 'quote-uuid',
      amount: freeQuote ? '0.00' : '1.50',
      unit: 'ед. МОСТ',
      processingDeadlineSeconds: processingDeadlineSeconds,
      expiresAt: quoteExpiresAt,
    );
  }

  @override
  Future<AiAssistantChatRequest> sendMessageRequest({
    required String message,
    required String requestId,
    int? conversationId,
    String? quoteId,
    String profile = 'normal',
    bool allowActions = true,
    Map<String, dynamic>? context,
    List<String> attachmentIds = const <String>[],
    CancelToken? cancelToken,
  }) {
    this.requestId = requestId;
    sentCancelToken = cancelToken;
    sentIds.add(requestId);
    if (failFirst && sentIds.length == 1) {
      return Future.error(StateError('Connection lost'));
    }
    if (asyncAccepted) {
      return Future.value(
        AiAssistantChatRequest(
          requestId: requestId,
          status: 'running',
          stage: 'queued',
          progress: initialProgress,
        ),
      );
    }
    return postResponse ?? answer.future;
  }

  @override
  Future<AiAssistantChatRequest> fetchChatRequest(
    String requestId, {
    int? conversationId,
  }) async {
    polledIds.add(requestId);
    if (_statusIndex < scriptedStatuses.length) {
      final snapshot = scriptedStatuses[_statusIndex++];
      if (snapshot is Map<String, dynamic>) {
        return AiAssistantChatRequest.fromJson({
          'request_id': requestId,
          'conversation_id': conversationId,
          'status': 'running',
          ...snapshot,
        });
      }
      throw snapshot;
    }
    if (notSubmittedOnce && polledIds.length == 1) {
      return AiAssistantChatRequest(
        requestId: requestId,
        status: 'not_submitted',
        stage: 'not_submitted',
      );
    }
    if (pollErrorStatusCode != null) {
      throw ApiException('Ошибка доступа', statusCode: pollErrorStatusCode);
    }
    if (_stageIndex < stages.length ||
        _progressIndex < progressSnapshots.length) {
      return AiAssistantChatRequest(
        requestId: requestId,
        status: 'running',
        stage: _stageIndex < stages.length ? stages[_stageIndex++] : null,
        progress:
            _progressIndex < progressSnapshots.length
                ? progressSnapshots[_progressIndex++]
                : const [],
      );
    }
    return answer.future;
  }

  @override
  Future<AiAssistantChatRequest> cancelRequest(
    String requestId, {
    int? conversationId,
  }) async {
    cancelledRequestId = requestId;
    return AiAssistantChatRequest(
      requestId: requestId,
      status:
          cancelStatus ?? (cancelPending ? 'cancel_requested' : 'cancelled'),
      canonicalStatus: cancelRunStatus,
      conversationId: conversationId,
    );
  }
}
