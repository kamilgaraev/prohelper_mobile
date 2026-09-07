import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_assistant_repository.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_hub_screen.dart';

class _Repository extends KnowledgeAssistantRepository {
  _Repository() : super(Dio());
  Completer<KnowledgeAssistantAnswer> response = Completer();
  int calls = 0;
  String? context;
  List<Map<String, String>> lastHistory = [];
  CancelToken? token;

  @override
  Future<KnowledgeAssistantAnswer> ask(String question, {String? contextKey, List<Map<String, String>> history = const [], required CancelToken cancelToken}) {
    calls++;
    lastHistory = history;
    context = contextKey;
    token = cancelToken;
    return response.future;
  }
}

void main() {
  Future<void> open(WidgetTester tester, _Repository repository) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [knowledgeAssistantRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: MostTheme.lightTheme, home: const KnowledgeHubScreen(contextKey: 'site_requests')),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Как создать заявку?');
    await tester.pump();
    await tester.tap(find.text('Спросить'));
    await tester.pump();
  }

  testWidgets('передаёт контекст, исключает повтор и показывает ответ', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    expect(repository.calls, 0);
    await ask(tester);
    expect(repository.context, 'site_requests');
    await tester.tap(find.text('Готовим ответ…'));
    expect(repository.calls, 1);
    repository.response.complete(const KnowledgeAssistantAnswer(answer: 'Откройте заявки.', answered: true, sources: []));
    await tester.pumpAndSettle();
    expect(find.text('Откройте заявки.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('сохраняет вопрос и позволяет повторить после ошибки', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await ask(tester);
    repository.response.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось получить ответ'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Как создать заявку?');
    repository.response = Completer();
    await tester.tap(find.text('Спросить'));
    await tester.pump();
    repository.response.complete(const KnowledgeAssistantAnswer(answer: 'Уточните вопрос.', answered: false, sources: []));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('Уточните вопрос.'), findsOneWidget);
  });

  testWidgets('отменяет запрос при закрытии экрана', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await ask(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(repository.token!.isCancelled, isTrue);
    repository.response.complete(const KnowledgeAssistantAnswer(answer: 'Поздний ответ', answered: true, sources: []));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('сообщает о лимите без совета проверить сеть', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await ask(tester);
    final options = RequestOptions(path: '/knowledge-hub/assistant');
    repository.response.completeError(DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 429),
      type: DioExceptionType.badResponse,
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Лимит обращений'), findsOneWidget);
    expect(find.textContaining('Проверьте подключение'), findsNothing);
  });

  testWidgets('поздний ответ старого раздела не очищает новый вопрос', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await ask(tester);
    final oldToken = repository.token;
    await tester.pumpWidget(ProviderScope(
      overrides: [knowledgeAssistantRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: MostTheme.lightTheme, home: const KnowledgeHubScreen(contextKey: 'other')),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Новый вопрос');
    repository.response.complete(const KnowledgeAssistantAnswer(answer: 'Старый ответ.', answered: true, sources: []));
    await tester.pumpAndSettle();
    expect(oldToken!.isCancelled, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Новый вопрос');
    expect(find.text('Старый ответ.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('экран доступен на телефоне', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, _Repository());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('передаёт короткое уточнение и сбрасывает разговор', (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await ask(tester);
    repository.response.complete(const KnowledgeAssistantAnswer(
      answer: 'Вы создаёте заявку на объекте?', answered: false, sources: [], needsClarification: true,
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    repository.response = Completer();
    await tester.enterText(find.byType(TextField), 'Да');
    await tester.pump();
    await tester.tap(find.text('Спросить'));
    await tester.pump();
    expect(repository.lastHistory, [
      {'role': 'user', 'content': 'Как создать заявку?'},
      {'role': 'assistant', 'content': 'Вы создаёте заявку на объекте?'},
    ]);
    repository.response.complete(const KnowledgeAssistantAnswer(answer: 'Откройте заявки.', answered: true, sources: []));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Новый разговор'));
    await tester.tap(find.text('Новый разговор'));
    await tester.pumpAndSettle();
    expect(find.text('Вы создаёте заявку на объекте?'), findsNothing);
    repository.response = Completer();
    await ask(tester);
    expect(repository.lastHistory, isEmpty);
    repository.response.complete(const KnowledgeAssistantAnswer(answer: 'Готово.', answered: true, sources: []));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
