import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:prohelpers_mobile/features/knowledge_hub/domain/knowledge_hub_provider.dart';
import 'package:prohelpers_mobile/features/knowledge_hub/presentation/knowledge_article_screen.dart';

class KnowledgeContextHelpButton extends ConsumerWidget {
  const KnowledgeContextHelpButton({
    super.key,
    required this.contextKey,
    this.moduleSlug,
    this.permissionKey,
    this.label = 'Нужна помощь?',
  });

  final String contextKey;
  final String? moduleSlug;
  final String? permissionKey;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final help = ref.watch(
      knowledgeContextHelpProvider(
        KnowledgeContextHelpParams(
          contextKey: contextKey,
          moduleSlug: moduleSlug,
          permissionKey: permissionKey,
          limit: 3,
        ),
      ),
    );

    return help.when(
      data: (value) {
        final article = value.primary;
        if (article == null) {
          return const SizedBox.shrink();
        }

        return OutlinedButton.icon(
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => KnowledgeArticleScreen(
                        slug: article.slug,
                        title: article.title,
                      ),
                ),
              ),
          icon: const Icon(Icons.help_outline_rounded),
          label: Text(label),
        );
      },
      loading:
          () => OutlinedButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: Text(label),
          ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
