import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_article_model.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/domain/knowledge_hub_provider.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_article_screen.dart';

class KnowledgeHubScreen extends ConsumerStatefulWidget {
  const KnowledgeHubScreen({super.key});

  @override
  ConsumerState<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends ConsumerState<KnowledgeHubScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(knowledgeHubProvider);
    final notifier = ref.read(knowledgeHubProvider.notifier);

    if (_searchController.text != state.query) {
      _searchController.text = state.query;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }

    return ProPageScaffold(
      title: 'База знаний',
      subtitle: 'Инструкции и подсказки по доступным модулям',
      onRefresh: () => notifier.load(refresh: true),
      actions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed:
              state.isLoading ? null : () => notifier.load(refresh: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KnowledgeSearchPanel(
            controller: _searchController,
            isLoading: state.isLoading,
            hasQuery: state.query.isNotEmpty,
            onSearch: () => notifier.setQuery(_searchController.text),
            onClear: () {
              _searchController.clear();
              notifier.clearQuery();
            },
          ),
          if (state.tree.isNotEmpty) ...[
            const SizedBox(height: 20),
            _KnowledgeTreeSection(articles: state.tree),
          ],
          const SizedBox(height: 20),
          _KnowledgeArticleSection(
            state: state,
            onRetry: () => notifier.load(refresh: true),
            onLoadMore: () => notifier.load(),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeSearchPanel extends StatelessWidget {
  const _KnowledgeSearchPanel({
    required this.controller,
    required this.isLoading,
    required this.hasQuery,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isLoading;
  final bool hasQuery;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ProSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Найти инструкцию',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Поиск по статьям, модулям и действиям',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  hasQuery
                      ? IconButton(
                        tooltip: 'Сбросить',
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      )
                      : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onSearch,
              icon: const Icon(Icons.manage_search_rounded),
              label: const Text('Искать'),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeTreeSection extends StatelessWidget {
  const _KnowledgeTreeSection({required this.articles});

  final List<KnowledgeArticleModel> articles;

  @override
  Widget build(BuildContext context) {
    return ProSectionBlock(
      title: 'Структура',
      subtitle: 'Разделы и вложенные инструкции',
      children:
          articles
              .map((article) => _KnowledgeTreeTile(article: article))
              .toList(growable: false),
    );
  }
}

class _KnowledgeTreeTile extends StatelessWidget {
  const _KnowledgeTreeTile({required this.article, this.level = 0});

  final KnowledgeArticleModel article;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openArticle(context, article),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12 + level * 14, 9, 12, 9),
            child: Row(
              children: [
                Icon(
                  article.children.isEmpty
                      ? Icons.article_outlined
                      : Icons.account_tree_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
        for (final child in article.children.take(4))
          _KnowledgeTreeTile(article: child, level: level + 1),
      ],
    );
  }
}

class _KnowledgeArticleSection extends StatelessWidget {
  const _KnowledgeArticleSection({
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
  });

  final KnowledgeHubState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.articles.isEmpty) {
      return const AppLoadingState(message: 'Загружаем базу знаний');
    }

    if (state.error != null && state.articles.isEmpty) {
      return AppErrorState(
        title: 'Не удалось загрузить базу знаний',
        description: state.error,
        onRetry: onRetry,
      );
    }

    if (state.articles.isEmpty) {
      return const AppEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'Статей пока нет',
        description: 'Материалы появятся после публикации в базе знаний.',
      );
    }

    return ProSectionBlock(
      title: state.query.isEmpty ? 'Статьи' : 'Результаты поиска',
      subtitle:
          state.query.isEmpty
              ? 'Материалы, доступные для вашей роли'
              : 'Найдено: ${state.total}',
      children: [
        for (final article in state.articles)
          ProActionTile(
            title: article.title,
            subtitle: article.preview,
            badge: article.readingTimeLabel,
            icon:
                article.children.isEmpty
                    ? Icons.article_outlined
                    : Icons.account_tree_outlined,
            tone: article.isPinned ? ProStatusTone.warning : ProStatusTone.info,
            onTap: () => _openArticle(context, article),
          ),
        if (state.hasMore)
          OutlinedButton.icon(
            onPressed: state.isLoadingMore ? null : onLoadMore,
            icon:
                state.isLoadingMore
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.expand_more_rounded),
            label: Text(state.isLoadingMore ? 'Загружаем...' : 'Показать ещё'),
          ),
      ],
    );
  }
}

void _openArticle(BuildContext context, KnowledgeArticleModel article) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => KnowledgeArticleScreen(slug: article.slug, title: article.title),
    ),
  );
}
