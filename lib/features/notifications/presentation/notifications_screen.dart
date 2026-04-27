import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../data/notification_model.dart';
import '../domain/notifications_provider.dart';
import 'notification_detail_screen.dart';
import 'widgets/notification_card.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        centerTitle: false,
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
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.items.isEmpty)
              SliverFillRemaining(
                child: AppStateView(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.error,
                  title: 'Не удалось загрузить уведомления',
                  description: state.error,
                  action: OutlinedButton(
                    onPressed: () => notifier.load(refresh: true),
                    child: const Text('Повторить'),
                  ),
                ),
              )
            else if (state.items.isEmpty)
              const SliverFillRemaining(
                child: AppStateView(
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
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon:
            isLoading
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.expand_more_rounded),
        label: Text(isLoading ? 'Загружаем...' : 'Показать еще'),
      ),
    );
  }
}
