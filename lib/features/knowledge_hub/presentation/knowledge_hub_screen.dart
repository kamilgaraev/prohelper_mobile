import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
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
          tooltip: 'Обновить базу знаний',
          onPressed:
              state.isLoading ? null : () => notifier.load(refresh: true),
          icon: const Icon(
            Icons.refresh_rounded,
            semanticLabel: 'Обновить базу знаний',
          ),
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
      child: Semantics(
        container: true,
        explicitChildNodes: true,
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
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: TextField(
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
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                container: true,
                button: true,
                enabled: !isLoading,
                label: 'Искать по базе знаний',
                onTap: isLoading ? null : onSearch,
                child: ExcludeSemantics(
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onSearch,
                    icon: const Icon(Icons.manage_search_rounded),
                    label: const Text('Искать'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeTreeSection extends StatelessWidget {
  const _KnowledgeTreeSection({required this.articles});

  final List<KnowledgeArticleModel> articles;

  @override
  Widget build(BuildContext context) {
    final rows = _flattenKnowledgeTree(articles);

    return _KnowledgeListPanel(
      title: 'Структура',
      subtitle: 'Разделы и вложенные инструкции',
      children: [
        for (final row in rows)
          _KnowledgeActionRow(
            article: row.article,
            level: row.level,
            icon:
                row.article.children.isEmpty
                    ? Icons.article_outlined
                    : Icons.account_tree_outlined,
            onTap: () => _openArticle(context, row.article),
          ),
      ],
    );
  }
}

class _KnowledgeTreeRow {
  const _KnowledgeTreeRow({required this.article, required this.level});

  final KnowledgeArticleModel article;
  final int level;
}

List<_KnowledgeTreeRow> _flattenKnowledgeTree(
  List<KnowledgeArticleModel> articles, {
  int level = 0,
}) {
  return [
    for (final article in articles) ...[
      _KnowledgeTreeRow(article: article, level: level),
      ..._flattenKnowledgeTree(
        article.children.take(4).toList(),
        level: level + 1,
      ),
    ],
  ];
}

class _KnowledgeListPanel extends StatelessWidget {
  const _KnowledgeListPanel({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return ProSurface(
      tone: ProSurfaceTone.elevated,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ProSpacing.md,
              ProSpacing.md,
              ProSpacing.md,
              0,
            ),
            child: ProSectionHeader(title: title, subtitle: subtitle),
          ),
          const ProSectionDivider(indent: ProSpacing.md),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const ProSectionDivider(indent: 72),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeActionRow extends StatelessWidget {
  const _KnowledgeActionRow({
    required this.article,
    required this.icon,
    required this.onTap,
    this.level = 0,
    this.tone = ProStatusTone.info,
    this.showBadge = false,
  });

  final KnowledgeArticleModel article;
  final IconData icon;
  final VoidCallback onTap;
  final int level;
  final ProStatusTone tone;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, tone);
    final theme = Theme.of(context);
    final leftPadding = ProSpacing.md + level * 14.0;

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      label: 'Открыть статью: ${article.title}',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ProTouchTarget.min),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              leftPadding,
              ProSpacing.sm,
              ProSpacing.md,
              ProSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(ProRadius.sm),
                  ),
                  child: Icon(icon, color: status.foreground, size: 22),
                ),
                const SizedBox(width: ProSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              article.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium(
                                context,
                              ).copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (showBadge) ...[
                            const SizedBox(width: ProSpacing.xs),
                            _KnowledgeBadge(
                              label: article.readingTimeLabel,
                              color: status.foreground,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: ProSpacing.xxs),
                      Text(
                        article.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ProSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KnowledgeBadge extends StatelessWidget {
  const _KnowledgeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ProSpacing.xs,
        vertical: ProSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ProRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          context,
        ).copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _KnowledgeLoadMoreRow extends StatelessWidget {
  const _KnowledgeLoadMoreRow({
    required this.isLoading,
    required this.onLoadMore,
  });

  final bool isLoading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ProSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onLoadMore,
          icon:
              isLoading
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.expand_more_rounded),
          label: Text(isLoading ? 'Загружаем...' : 'Показать ещё'),
        ),
      ),
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

    return _KnowledgeListPanel(
      title: state.query.isEmpty ? 'Статьи' : 'Результаты поиска',
      subtitle:
          state.query.isEmpty
              ? 'Материалы, доступные для вашей роли'
              : 'Найдено: ${state.total}',
      children: [
        for (final article in state.articles)
          _KnowledgeActionRow(
            article: article,
            icon:
                article.children.isEmpty
                    ? Icons.article_outlined
                    : Icons.account_tree_outlined,
            tone: article.isPinned ? ProStatusTone.warning : ProStatusTone.info,
            showBadge: true,
            onTap: () => _openArticle(context, article),
          ),
        if (state.hasMore)
          _KnowledgeLoadMoreRow(
            isLoading: state.isLoadingMore,
            onLoadMore: onLoadMore,
          ),
      ],
    );
  }
}

void _openArticle(BuildContext context, KnowledgeArticleModel article) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder:
          (_) =>
              KnowledgeArticleScreen(slug: article.slug, title: article.title),
    ),
  );
}
