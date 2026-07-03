import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_article_model.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_hub_repository.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_article_screen.dart';

class _FakeKnowledgeHubRepository extends KnowledgeHubRepository {
  _FakeKnowledgeHubRepository() : super(Dio());

  static const article = KnowledgeArticleModel(
    id: 10,
    title: 'Работа с заявками объекта',
    slug: 'site-requests',
    excerpt: 'Порядок создания, проверки и согласования заявок.',
    plainText:
        'Откройте раздел заявок, заполните обязательные поля и отправьте заявку ответственному.',
    readingTime: 5,
    tableOfContents: [
      KnowledgeArticleTocItem(
        level: 2,
        title: 'Создание заявки',
        anchor: 'create',
      ),
      KnowledgeArticleTocItem(
        level: 2,
        title: 'Согласование',
        anchor: 'approval',
      ),
    ],
    children: [
      KnowledgeArticleModel(
        id: 11,
        title: 'Материальная заявка',
        slug: 'material-request',
        excerpt: 'Как запросить материалы на объект.',
        readingTime: 3,
      ),
    ],
    related: [
      KnowledgeArticleModel(
        id: 12,
        title: 'Складские остатки',
        slug: 'warehouse-stock',
        excerpt: 'Как проверить наличие материалов.',
        readingTime: 2,
      ),
    ],
  );

  @override
  Future<KnowledgeArticleModel> fetchArticle(String slug) async => article;
}

void main() {
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        knowledgeHubRepositoryProvider.overrideWithValue(
          _FakeKnowledgeHubRepository(),
        ),
      ],
      child: MaterialApp(
        theme: MostTheme.lightTheme,
        home: const KnowledgeArticleScreen(slug: 'site-requests'),
      ),
    );
  }

  testWidgets('закрепляет содержание и связанные статьи внутри поверхностей', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('Содержание'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Вложенные статьи'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.ancestor(
        of: find.text('Вложенные статьи'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Похожие материалы'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('экран статьи проходит базовые accessibility guidelines', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
