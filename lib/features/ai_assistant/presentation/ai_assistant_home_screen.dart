import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/ai_assistant_models.dart';
import '../domain/ai_assistant_provider.dart';
import 'ai_assistant_chat_screen.dart';

class AiAssistantHomeScreen extends ConsumerWidget {
  const AiAssistantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiAssistantHomeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-ассистент'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AiAssistantChatScreen(),
          ),
        ),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Новый чат'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(aiAssistantHomeProvider.notifier).load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: IndustrialCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROHELPER AI',
                        style: AppTypography.caption(context).copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Рабочий помощник по проектам, срокам, контрактам и финансам.',
                        style: AppTypography.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Используйте историю диалогов как рабочий контекст и быстро возвращайтесь к прошлым разбором.',
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.isLoading && state.home == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.home == null)
              SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.smart_toy_outlined,
                  title: 'Не удалось загрузить AI-ассистента',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => ref.read(aiAssistantHomeProvider.notifier).load(),
                    child: const Text('Повторить'),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: _UsageCard(usage: state.home?.usage),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: _QuickPromptsCard(
                    onPromptTap: (prompt) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AiAssistantChatScreen(
                            initialPrompt: prompt,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final conversation = state.home!.conversations[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ConversationCard(
                          conversation: conversation,
                          onOpen: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AiAssistantChatScreen(
                                  conversationId: conversation.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: state.home?.conversations.length ?? 0,
                  ),
                ),
              ),
              if ((state.home?.conversations.isEmpty ?? true))
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverToBoxAdapter(
                    child: _EmptyHistoryCard(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});

  final AiUsageModel? usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Запросы за месяц',
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  usage == null ? '—' : '${usage!.used} / ${usage!.monthlyLimit}',
                  style: AppTypography.h2(context).copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  usage == null ? '0%' : '${usage!.percentageUsed.round()}%',
                  style: AppTypography.bodyLarge(context).copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: usage == null
                  ? 0
                  : ((usage!.percentageUsed / 100).clamp(0, 1) as num).toDouble(),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            usage == null
                ? 'Лимит не загружен'
                : 'Осталось ${usage!.remaining} запросов',
            style: AppTypography.bodyMedium(context).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptsCard extends StatelessWidget {
  const _QuickPromptsCard({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  static const _prompts = [
    'Покажи главные риски по проекту',
    'Собери короткую сводку по финансам',
    'Что сейчас проседает по срокам',
    'Какие подрядчики требуют внимания',
  ];

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Быстрый старт',
            style: AppTypography.bodyLarge(context).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _prompts.map((prompt) {
              return ActionChip(
                label: Text(prompt),
                onPressed: () => onPromptTap(prompt),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onOpen,
  });

  final AiConversationModel conversation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IndustrialCard(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title.isEmpty
                      ? 'Диалог #${conversation.id}'
                      : conversation.title,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.lastMessagePreview ?? 'Сообщений пока нет',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${conversation.messagesCount} сообщений • ${_formatDate(conversation.lastMessageAt ?? conversation.updatedAt)}',
                  style: AppTypography.caption(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: AppStateView(
        icon: Icons.history_toggle_off_rounded,
        title: 'История пока пуста',
        description:
            'Откройте новый чат и используйте ассистента как рабочий контекст по проекту, а не как одноразовый запрос.',
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'нет даты';
  }

  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$day.$month $hour:$minute';
}
