import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_chat_screen.dart';

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

  @override
  Future<void> checkAuth() async {}
}

void main() {
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
            message: const AiMessageModel(
              id: 10,
              role: 'assistant',
              content: 'Recovered',
              createdAt: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
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
    expect(find.text('Склад проверен'), findsOneWidget);
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

  testWidgets('zero-cost greeting skips expense confirmation', (tester) async {
    final repository = _RaceRepository(freeQuote: true);
    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Привет');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(find.text('Оценка расхода'), findsNothing);
    expect(repository.sentIds, hasLength(1));
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
            content: 'Здравствуйте!',
            createdAt: null,
            metadata: {
              'response_kind': 'greeting',
              'validation_status': 'verified',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Здравствуйте!'), findsOneWidget);
    expect(find.text('Проверено'), findsNothing);
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

  testWidgets('disposing the screen cancels the captured request', (
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
    expect(repository.cancelledRequestId, repository.requestId);
    expect(repository.sentCancelToken?.isCancelled, isTrue);
  });

  testWidgets('organization change cancels request captured in old scope', (
    tester,
  ) async {
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
    expect(repository.cancelledRequestId, repository.requestId);
    expect(repository.sentCancelToken?.isCancelled, isTrue);
    expect(find.text('Прошло 00:'), findsNothing);
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
        find.text(
          'Тестовый режим: списания выключены. Фактическое списание — 0 ед. МОСТ.',
        ),
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
    this.quoteExpiresAt,
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
  final DateTime? quoteExpiresAt;
  int _stageIndex = 0;
  int _progressIndex = 0;
  int quoteCalls = 0;
  final sentIds = <String>[];
  final answer = Completer<AiAssistantChatRequest>();
  final polledIds = <String>[];
  String? requestId;
  String? quoteRequestId;
  String? cancelledRequestId;
  CancelToken? sentCancelToken;
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
    List<String> attachmentIds = const <String>[],
  }) async {
    quoteCalls++;
    quoteRequestId = requestId;
    return AiCreditQuoteModel(
      id: 'quote-uuid',
      maxConfirmed: false,
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
    required bool maxConfirmed,
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
    return answer.future;
  }

  @override
  Future<AiAssistantChatRequest> fetchChatRequest(
    String requestId, {
    int? conversationId,
  }) async {
    polledIds.add(requestId);
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
  Future<AiAssistantChatRequest> cancelRequest(String requestId) async {
    cancelledRequestId = requestId;
    return AiAssistantChatRequest(
      requestId: requestId,
      status: cancelPending ? 'cancel_requested' : 'cancelled',
    );
  }
}
