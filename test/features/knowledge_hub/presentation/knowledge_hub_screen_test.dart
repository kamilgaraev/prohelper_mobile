import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_article_model.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_hub_repository.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_hub_screen.dart';

class _FakeKnowledgeHubRepository extends KnowledgeHubRepository {
  _FakeKnowledgeHubRepository() : super(Dio());

  static const tree = [
    KnowledgeArticleModel(
      id: 1,
      title: 'Заявки объекта',
      slug: 'site-requests',
      excerpt: 'Разделы и вложенные инструкции',
      children: [
        KnowledgeArticleModel(
          id: 2,
          title: 'Создание заявки',
          slug: 'site-request-create',
          excerpt: 'Как создать заявку с объекта',
        ),
      ],
    ),
  ];

  static const articles = [
    KnowledgeArticleModel(
      id: 3,
      title: 'Проверка складских остатков',
      slug: 'warehouse-stock',
      excerpt: 'Как проверить доступные материалы',
      readingTime: 4,
      isPinned: true,
    ),
    KnowledgeArticleModel(
      id: 4,
      title: 'Согласование заявки',
      slug: 'request-approval',
      excerpt: 'Как принять решение по заявке',
      readingTime: 2,
    ),
  ];

  @override
  Future<List<KnowledgeArticleModel>> fetchTree({
    String? moduleSlug,
    String? contextKey,
  }) async {
    return tree;
  }

  @override
  Future<KnowledgeArticlePage> fetchArticles({
    int page = 1,
    int perPage = 20,
    String? query,
    String? moduleSlug,
    String? contextKey,
    String? permissionKey,
  }) async {
    return KnowledgeArticlePage(
      items: articles,
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: articles.length,
    );
  }
}

void main() {
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'кнопка обновления базы знаний имеет понятную accessibility-метку',
    (tester) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeHubRepositoryProvider.overrideWithValue(
              _FakeKnowledgeHubRepository(),
            ),
          ],
          child: MaterialApp(
            theme: MostTheme.lightTheme,
            home: const KnowledgeHubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final refreshButton = find.widgetWithIcon(
        IconButton,
        Icons.refresh_rounded,
      );

      expect(refreshButton, findsOneWidget);
      expect(find.byTooltip('Обновить базу знаний'), findsOneWidget);

      final refreshIcon = tester.widget<Icon>(
        find.descendant(of: refreshButton, matching: find.byType(Icon)),
      );

      expect(refreshIcon.semanticLabel, 'Обновить базу знаний');
    },
  );

  testWidgets('закрепляет структуру и статьи внутри карточных поверхностей', (
    tester,
  ) async {
    usePhoneViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          knowledgeHubRepositoryProvider.overrideWithValue(
            _FakeKnowledgeHubRepository(),
          ),
        ],
        child: MaterialApp(
          theme: MostTheme.lightTheme,
          home: const KnowledgeHubScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('Структура'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Статьи'), matching: find.byType(ProSurface)),
      findsOneWidget,
    );
  });

  testWidgets('поиск базы знаний отделяет поле ввода от кнопки поиска', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeHubRepositoryProvider.overrideWithValue(
              _FakeKnowledgeHubRepository(),
            ),
          ],
          child: MaterialApp(
            theme: MostTheme.lightTheme,
            home: const KnowledgeHubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nodes = _collectSemanticsNodes(tester.binding.rootPipelineOwner);
      final textFieldNodes = nodes
          .toSet()
          .where((node) => node.hasFlag(SemanticsFlag.isTextField))
          .toList(growable: false);

      expect(textFieldNodes, hasLength(1));
      expect(find.bySemanticsLabel('Искать по базе знаний'), findsOneWidget);

      final nestedSearchButtons = _collectSemanticsSubtree(
            textFieldNodes.single,
          )
          .skip(1)
          .where((node) => node.hasFlag(SemanticsFlag.isButton))
          .where(
            (node) =>
                node.getSemanticsData().label == 'Искать по базе знаний' ||
                node.getSemanticsData().label == 'Искать',
          )
          .toList(growable: false);

      expect(nestedSearchButtons, isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('экран базы знаний проходит базовые accessibility guidelines', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            knowledgeHubRepositoryProvider.overrideWithValue(
              _FakeKnowledgeHubRepository(),
            ),
          ],
          child: MaterialApp(
            theme: MostTheme.lightTheme,
            home: const KnowledgeHubScreen(),
          ),
        ),
      );

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

List<SemanticsNode> _collectSemanticsNodes(PipelineOwner owner) {
  final roots = <SemanticsNode>[];
  final root = owner.semanticsOwner?.rootSemanticsNode;
  if (root != null) {
    roots.add(root);
  }
  owner.visitChildren((child) {
    roots.addAll(_collectSemanticsNodes(child));
  });

  final nodes = <SemanticsNode>[];
  for (final root in roots) {
    nodes.addAll(_collectSemanticsSubtree(root));
  }
  return nodes;
}

List<SemanticsNode> _collectSemanticsSubtree(SemanticsNode root) {
  final nodes = <SemanticsNode>[root];
  root.visitChildren((child) {
    nodes.addAll(_collectSemanticsSubtree(child));
    return true;
  });
  return nodes;
}
