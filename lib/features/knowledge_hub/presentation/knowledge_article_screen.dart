import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/design/pro_status.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_section.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_article_model.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/data/knowledge_hub_repository.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/domain/knowledge_hub_provider.dart';

class KnowledgeArticleScreen extends ConsumerWidget {
  const KnowledgeArticleScreen({super.key, required this.slug, this.title});

  final String slug;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(knowledgeArticleDetailProvider(slug));
    final notifier = ref.read(knowledgeArticleDetailProvider(slug).notifier);
    final article = state.article;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(article?.title ?? title ?? 'Статья'),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (state.isLoading && article == null)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: AppLoadingState(message: 'Открываем статью'),
              )
            else if (state.error != null && article == null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: AppErrorState(
                  title: 'Не удалось открыть статью',
                  description: state.error,
                  onRetry: notifier.load,
                ),
              )
            else if (article != null)
              _ArticleBody(
                article: article,
                state: state,
                onFeedback: (reaction) async {
                  try {
                    await notifier.submitFeedback(reaction);
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Спасибо за оценку статьи.'),
                      ),
                    );
                  } catch (_) {
                    if (!context.mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.error ?? 'Не удалось сохранить оценку статьи.',
                        ),
                      ),
                    );
                  }
                },
                onOpenArticle: (nextArticle) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => KnowledgeArticleScreen(
                            slug: nextArticle.slug,
                            title: nextArticle.title,
                          ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({
    required this.article,
    required this.state,
    required this.onFeedback,
    required this.onOpenArticle,
  });

  final KnowledgeArticleModel article;
  final KnowledgeArticleDetailState state;
  final ValueChanged<KnowledgeFeedbackReaction> onFeedback;
  final ValueChanged<KnowledgeArticleModel> onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.title, style: AppTypography.h1(context)),
              const SizedBox(height: 8),
              Text(article.preview, style: AppTypography.bodyMedium(context)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule_rounded, size: 16),
                    label: Text(article.readingTimeLabel),
                  ),
                  if (article.categoryTitle != null)
                    Chip(
                      avatar: const Icon(Icons.folder_outlined, size: 16),
                      label: Text(article.categoryTitle!),
                    ),
                  if (article.isPinned)
                    const Chip(
                      avatar: Icon(Icons.push_pin_outlined, size: 16),
                      label: Text('Закреплено'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (article.tableOfContents.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ArticleTocPanel(items: article.tableOfContents),
        ],
        const SizedBox(height: 16),
        ProSurface(
          child: SelectableText(
            article.bodyText.isEmpty ? article.preview : article.bodyText,
            style: AppTypography.bodyLarge(context).copyWith(height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        _FeedbackBlock(state: state, onFeedback: onFeedback),
        if (article.children.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ArticleLinksSection(
            title: 'Вложенные статьи',
            articles: article.children,
            onOpenArticle: onOpenArticle,
          ),
        ],
        if (article.related.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ArticleLinksSection(
            title: 'Похожие материалы',
            articles: article.related,
            onOpenArticle: onOpenArticle,
          ),
        ],
      ],
    );
  }
}

class _FeedbackBlock extends StatelessWidget {
  const _FeedbackBlock({required this.state, required this.onFeedback});

  final KnowledgeArticleDetailState state;
  final ValueChanged<KnowledgeFeedbackReaction> onFeedback;

  @override
  Widget build(BuildContext context) {
    final isHelpful =
        state.feedbackReaction == KnowledgeFeedbackReaction.helpful;
    final isNotHelpful =
        state.feedbackReaction == KnowledgeFeedbackReaction.notHelpful;

    return ProSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статья помогла?',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    state.isSubmittingFeedback
                        ? null
                        : () => onFeedback(KnowledgeFeedbackReaction.helpful),
                icon: Icon(
                  isHelpful
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                ),
                label: Text(isHelpful ? 'Отмечено полезной' : 'Полезно'),
              ),
              OutlinedButton.icon(
                onPressed:
                    state.isSubmittingFeedback
                        ? null
                        : () =>
                            onFeedback(KnowledgeFeedbackReaction.notHelpful),
                icon: Icon(
                  isNotHelpful
                      ? Icons.thumb_down_alt_rounded
                      : Icons.thumb_down_alt_outlined,
                ),
                label: Text(isNotHelpful ? 'Отмечено' : 'Не помогло'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel({required this.title, required this.children});

  final String title;
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
            child: ProSectionHeader(title: title),
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

class _ArticleTocPanel extends StatelessWidget {
  const _ArticleTocPanel({required this.items});

  final List<KnowledgeArticleTocItem> items;

  @override
  Widget build(BuildContext context) {
    return _ArticlePanel(
      title: 'Содержание',
      children: [for (final item in items) _ArticleTocRow(item: item)],
    );
  }
}

class _ArticleTocRow extends StatelessWidget {
  const _ArticleTocRow({required this.item});

  final KnowledgeArticleTocItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelOffset = (item.level - 2).clamp(0, 4) * 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ProSpacing.md + levelOffset,
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
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ProRadius.sm),
            ),
            child: Icon(
              Icons.format_list_bulleted_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: ProSpacing.sm),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleLinksSection extends StatelessWidget {
  const _ArticleLinksSection({
    required this.title,
    required this.articles,
    required this.onOpenArticle,
  });

  final String title;
  final List<KnowledgeArticleModel> articles;
  final ValueChanged<KnowledgeArticleModel> onOpenArticle;

  @override
  Widget build(BuildContext context) {
    return _ArticlePanel(
      title: title,
      children: [
        for (final article in articles)
          _ArticleLinkRow(
            article: article,
            onTap: () => onOpenArticle(article),
          ),
      ],
    );
  }
}

class _ArticleLinkRow extends StatelessWidget {
  const _ArticleLinkRow({required this.article, required this.onTap});

  final KnowledgeArticleModel article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = proStatusStyle(context, ProStatusTone.info);
    final theme = Theme.of(context);

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
            padding: const EdgeInsets.all(ProSpacing.md),
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
                  child: Icon(
                    Icons.article_outlined,
                    color: status.foreground,
                    size: 22,
                  ),
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
                          const SizedBox(width: ProSpacing.xs),
                          _ArticleBadge(
                            label: article.readingTimeLabel,
                            color: status.foreground,
                          ),
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

class _ArticleBadge extends StatelessWidget {
  const _ArticleBadge({required this.label, required this.color});

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
