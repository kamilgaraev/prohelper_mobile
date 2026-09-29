import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_chat_screen.dart';

void main() {
  Widget buildScreen(_AiAssistantRepository repository, {ThemeData? theme}) {
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

  testWidgets('does not execute action without confirmation', (tester) async {
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

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();

    expect(repository.executeCalls, 0);
    expect(find.text('Проверить действие'), findsNothing);
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
      AiAssistantChatResult(
        requestId: repository.requestId!,
        conversationId: 1,
        message: const AiMessageModel(
          id: 99,
          role: 'assistant',
          content: 'Late answer',
          createdAt: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Late answer'), findsNothing);
    expect(find.text('Диалог #2'), findsOneWidget);
    expect(repository.cancelledRequestId, repository.requestId);
  });

  testWidgets('retry preserves original request and approved quote', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();
    final firstId = repository.requestId;
    await tester.tap(find.text('Повторить запрос без повторного списания'));
    await tester.pump();
    expect(repository.sentIds, [firstId, firstId]);
    expect(repository.quoteCalls, 1);
    repository.answer.complete(
      AiAssistantChatResult(
        requestId: firstId!,
        conversationId: 1,
        message: const AiMessageModel(
          id: 10,
          role: 'assistant',
          content: 'Recovered',
          createdAt: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
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
        AiAssistantChatResult(
          requestId: repository.requestId!,
          conversationId: 1,
          creditUsage: const AiCreditUsageModel(
            actualCharge: '0.00',
            chargingEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Тестовый режим: списания выключены. Фактическое списание — 0 ед. МОСТ.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Списано: 0'), findsNothing);
    },
  );

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

class _AiAssistantRepository extends AiAssistantRepository {
  _AiAssistantRepository({required this.messages}) : super(Dio());

  final List<AiMessageModel> messages;
  int previewCalls = 0;
  int executeCalls = 0;

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

class _RaceRepository extends AiAssistantRepository {
  _RaceRepository({this.canWrite = true, this.failFirst = false})
    : super(Dio());
  final bool canWrite;
  final bool failFirst;
  int quoteCalls = 0;
  final sentIds = <String>[];
  final answer = Completer<AiAssistantChatResult>();
  String? requestId;
  String? quoteRequestId;
  String? cancelledRequestId;
  @override
  Future<AiConversationDetailsModel> fetchConversation(int id) async =>
      AiConversationDetailsModel(
        conversation: AiConversationModel(
          id: id,
          title: 'Chat',
          createdAt: null,
          updatedAt: null,
          canWrite: canWrite,
        ),
        messages: const [],
      );
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
  }) async {
    quoteCalls++;
    quoteRequestId = requestId;
    return const AiCreditQuoteModel(
      id: 'quote-uuid',
      maxConfirmed: false,
      amount: '1.50',
      unit: 'ед. МОСТ',
    );
  }

  @override
  Future<AiAssistantChatResult> sendMessageRequest({
    required String message,
    required String requestId,
    int? conversationId,
    String? quoteId,
    required bool maxConfirmed,
    String profile = 'normal',
    bool allowActions = true,
    Map<String, dynamic>? context,
    CancelToken? cancelToken,
  }) {
    this.requestId = requestId;
    sentIds.add(requestId);
    if (failFirst && sentIds.length == 1) {
      return Future.error(StateError('Connection lost'));
    }
    return answer.future;
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    cancelledRequestId = requestId;
  }
}
