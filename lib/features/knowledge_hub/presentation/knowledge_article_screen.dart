import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_error_state.dart';
import 'package:prohelpers_mobile/core/widgets/app_loading_state.dart';
import 'package:prohelpers_mobile/core/widgets/pro_action_tile.dart';
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
                      const SnackBar(content: Text('Спасибо за оценку статьи.')),
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
              Text(
                article.preview,
                style: AppTypography.bodyMedium(context),
              ),
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
          ProSectionBlock(
            title: 'Содержание',
            children:
                article.tableOfContents
                    .map(
                      (item) => Padding(
                        padding: EdgeInsets.only(left: (item.level - 2) * 12),
                        child: Text(
                          item.title,
                          style: AppTypography.bodyMedium(context),
                        ),
                      ),
                    )
                    .toList(growable: false),
          ),
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
                        : () => onFeedback(KnowledgeFeedbackReaction.notHelpful),
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
    return ProSectionBlock(
      title: title,
      children:
          articles
              .map(
                (article) => ProActionTile(
                  title: article.title,
                  subtitle: article.preview,
                  badge: article.readingTimeLabel,
                  icon: Icons.article_outlined,
                  onTap: () => onOpenArticle(article),
                ),
              )
              .toList(growable: false),
    );
  }
}
