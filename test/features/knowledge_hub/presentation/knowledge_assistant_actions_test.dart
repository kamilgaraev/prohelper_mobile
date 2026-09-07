import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_assistant_repository.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_assistant_actions.dart';

void main() {
  final requests = MobileModuleDestination(
    route: 'site_requests',
    slug: 'site-requests',
    title: 'Заявки',
    shortTitle: 'Заявки',
    icon: Icons.list,
    group: MobileModuleGroup.fieldWork,
    builder: (_) => Scaffold(appBar: AppBar(), body: const Text('Список заявок')),
  );
  const sources = [
    KnowledgeAssistantSource(id: 4, title: 'Заявки', slug: 'site-requests-overview'),
    KnowledgeAssistantSource(id: 5, title: 'Создание', slug: 'create-site-request'),
  ];

  Future<void> open(WidgetTester tester, KnowledgeAssistantAnswer answer, {bool allowed = true}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [knowledgeAssistantDestinationsProvider.overrideWithValue(allowed ? [requests] : [])],
      child: MaterialApp(home: Scaffold(body: KnowledgeAssistantActions(answer: answer))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('открывает экран и объединяет одинаковые переходы', (tester) async {
    await open(tester, const KnowledgeAssistantAnswer(answer: 'Откройте заявки.', answered: true, sources: sources));
    expect(find.text('Открыть заявки'), findsOneWidget);
    await tester.tap(find.text('Открыть заявки'));
    await tester.pumpAndSettle();
    expect(find.text('Список заявок'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Открыть заявки'), findsOneWidget);
  });

  testWidgets('не открывает недоступный модуль', (tester) async {
    await open(tester, const KnowledgeAssistantAnswer(answer: 'Заявки.', answered: true, sources: sources), allowed: false);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('не предлагает переход при уточнении и неизвестных источниках', (tester) async {
    await open(tester, const KnowledgeAssistantAnswer(answer: 'Уточните.', answered: false, sources: sources, needsClarification: true));
    expect(find.byType(OutlinedButton), findsNothing);
    await open(tester, const KnowledgeAssistantAnswer(answer: 'Ответ.', answered: true, sources: [
      KnowledgeAssistantSource(id: 1, title: 'Адрес', slug: 'https://example.com'),
      KnowledgeAssistantSource(id: 2, title: 'Старый формат'),
    ]));
    expect(find.byType(OutlinedButton), findsNothing);
  });

  test('сохраняет совместимость источников и читает slug', () {
    final answer = KnowledgeAssistantAnswer.fromJson({
      'answer': 'Ответ.', 'status': 'answered', 'sources': [
        {'id': 4, 'title': 'Заявки', 'slug': 'site-requests-overview'},
        {'id': 1, 'title': 'Старый формат'},
      ],
    });
    expect(answer.sources.first.slug, 'site-requests-overview');
    expect(answer.sources.last.slug, isNull);
  });

  test('без доступных модулей список переходов пуст', () {
    final container = ProviderContainer(overrides: [supportedMobileModulesProvider.overrideWithValue([])]);
    addTearDown(container.dispose);
    expect(container.read(knowledgeAssistantDestinationsProvider), isEmpty);
  });
}
