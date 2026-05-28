import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_buttons.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../data/notification_model.dart';
import '../domain/notifications_provider.dart';
import 'notification_detail_screen.dart';
import 'widgets/notification_card.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, this.asTab = false});

  final bool asTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        centerTitle: false,
        automaticallyImplyLeading: !asTab,
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: state.isActionLoading ? null : notifier.markAllAsRead,
              icon:
                  state.isActionLoading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.done_all_rounded),
              label: const Text('Все прочитаны'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _NotificationFilters(
                  selected: state.filter,
                  unreadCount: state.unreadCount,
                  onChanged: notifier.setFilter,
                ),
              ),
            ),
            if (state.isRefreshing && state.items.isEmpty)
              const SliverFillRemaining(
                child: AppLoadingState(message: 'Загружаем уведомления'),
              )
            else if (state.error != null && state.items.isEmpty)
              SliverFillRemaining(
                child: AppErrorState(
                  title: 'Не удалось загрузить уведомления',
                  description:
                      state.error == null
                          ? null
                          : UserMessage.fromError(state.error!),
                  onRetry: () => notifier.load(refresh: true),
                ),
              )
            else if (state.items.isEmpty)
              const SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Уведомлений пока нет',
                  description:
                      'Здесь появятся события, которые требуют внимания.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == state.items.length) {
                      return _LoadMoreButton(
                        isLoading: state.isLoading,
                        hasMore: state.hasMore,
                        onPressed: () => notifier.load(),
                      );
                    }

                    final notification = state.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NotificationCard(
                        notification: notification,
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => NotificationDetailScreen(
                                      notificationId: notification.id,
                                      initialNotification: notification,
                                    ),
                              ),
                            ),
                        onMarkRead:
                            notification.isUnread
                                ? () => notifier.markAsRead(notification.id)
                                : null,
                      ),
                    );
                  }, childCount: state.items.length + 1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationFilters extends StatelessWidget {
  const _NotificationFilters({
    required this.selected,
    required this.unreadCount,
    required this.onChanged,
  });

  final NotificationFilter selected;
  final int unreadCount;
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            NotificationFilter.values.map((filter) {
              final label = switch (filter) {
                NotificationFilter.all => 'Все',
                NotificationFilter.unread =>
                  unreadCount > 0
                      ? 'Непрочитанные $unreadCount'
                      : 'Непрочитанные',
                NotificationFilter.read => 'Прочитанные',
              };

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected == filter,
                  label: Text(label),
                  onSelected: (_) => onChanged(filter),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.isLoading,
    required this.hasMore,
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasMore;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Все уведомления загружены',
            style: AppTypography.caption(context),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AppSecondaryActionButton(
        label: isLoading ? 'Загружаем...' : 'Показать еще',
        onPressed: isLoading ? null : onPressed,
        leading: const Icon(Icons.expand_more_rounded),
        isBusy: isLoading,
      ),
    );
  }
}
