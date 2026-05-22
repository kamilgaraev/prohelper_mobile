import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_models.dart';
import 'package:prohelpers_mobile/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_chat_screen.dart';

void main() {
  Widget buildScreen(_AiAssistantRepository repository) {
    return ProviderScope(
      overrides: [aiAssistantRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: AiAssistantChatScreen(conversationId: 1)),
    );
  }

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
