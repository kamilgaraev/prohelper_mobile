import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
import '../data/notification_model.dart';
import '../data/notifications_repository.dart';

const _notificationsSentinel = Object();

class NotificationsState {
  const NotificationsState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isActionLoading = false,
    this.items = const <NotificationModel>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 20,
    this.total = 0,
    this.unreadCount = 0,
    this.filter = NotificationFilter.all,
    this.error,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isActionLoading;
  final List<NotificationModel> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int unreadCount;
  final NotificationFilter filter;
  final String? error;

  bool get hasMore => currentPage < lastPage;

  NotificationsState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isActionLoading,
    List<NotificationModel>? items,
    int? currentPage,
    int? lastPage,
    int? perPage,
    int? total,
    int? unreadCount,
    NotificationFilter? filter,
    Object? error = _notificationsSentinel,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      unreadCount: unreadCount ?? this.unreadCount,
      filter: filter ?? this.filter,
      error:
          identical(error, _notificationsSentinel)
              ? this.error
              : error as String?,
    );
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
      ref.watch(authProvider);
      return NotificationsNotifier(ref.read(notificationsRepositoryProvider));
    });

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repository) : super(const NotificationsState()) {
    load(refresh: true);
    refreshUnreadCount();
  }

  final NotificationsRepository _repository;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading || state.isRefreshing) {
      return;
    }
    if (!refresh && !state.hasMore) {
      return;
    }

    final nextPage = refresh ? 1 : state.currentPage + 1;

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      error: null,
      currentPage: refresh ? 1 : state.currentPage,
      lastPage: refresh ? 1 : state.lastPage,
      items: refresh ? const <NotificationModel>[] : null,
    );

    try {
      final result = await _repository.fetchNotifications(
        page: nextPage,
        perPage: state.perPage,
        filter: state.filter,
      );

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        items:
            refresh
                ? result.items
                : <NotificationModel>[...state.items, ...result.items],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        perPage: result.perPage,
        total: result.total,
        error: null,
      );
      await refreshUnreadCount();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: error.toString().replaceFirst('ApiException: ', ''),
      );
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _repository.fetchUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> setFilter(NotificationFilter filter) async {
    if (state.filter == filter) {
      return;
    }

    state = state.copyWith(filter: filter);
    await load(refresh: true);
  }

  Future<void> markAsRead(String id) async {
    final index = state.items.indexWhere((item) => item.id == id);
    final wasUnread = index != -1 && state.items[index].isUnread;

    state = state.copyWith(isActionLoading: true, error: null);

    try {
      final updated = await _repository.markAsRead(id);
      final nextItems = [...state.items];

      if (index != -1) {
        nextItems[index] = updated;
      }

      state = state.copyWith(
        isActionLoading: false,
        items: nextItems,
        unreadCount:
            wasUnread && state.unreadCount > 0
                ? state.unreadCount - 1
                : state.unreadCount,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        error: error.toString().replaceFirst('ApiException: ', ''),
      );
      rethrow;
    }
  }

  void applyRead(NotificationModel notification) {
    final index = state.items.indexWhere((item) => item.id == notification.id);
    final wasUnread = index != -1 && state.items[index].isUnread;

    if (index == -1) {
      state = state.copyWith(
        unreadCount:
            wasUnread && state.unreadCount > 0
                ? state.unreadCount - 1
                : state.unreadCount,
      );
      return;
    }

    final nextItems = [...state.items];
    nextItems[index] = notification;

    state = state.copyWith(
      items: nextItems,
      unreadCount:
          wasUnread && state.unreadCount > 0
              ? state.unreadCount - 1
              : state.unreadCount,
    );
  }

  Future<void> markAllAsRead() async {
    state = state.copyWith(isActionLoading: true, error: null);

    try {
      await _repository.markAllAsRead();
      final nextItems = state.items
          .map(
            (item) =>
                item.isUnread ? item.copyWith(readAt: DateTime.now()) : item,
          )
          .toList(growable: false);

      state = state.copyWith(
        isActionLoading: false,
        items: nextItems,
        unreadCount: 0,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        error: error.toString().replaceFirst('ApiException: ', ''),
      );
      rethrow;
    }
  }
}

class NotificationDetailState {
  const NotificationDetailState({
    this.isLoading = false,
    this.isMarkingRead = false,
    this.notification,
    this.error,
  });

  final bool isLoading;
  final bool isMarkingRead;
  final NotificationModel? notification;
  final String? error;

  NotificationDetailState copyWith({
    bool? isLoading,
    bool? isMarkingRead,
    NotificationModel? notification,
    Object? error = _notificationsSentinel,
  }) {
    return NotificationDetailState(
      isLoading: isLoading ?? this.isLoading,
      isMarkingRead: isMarkingRead ?? this.isMarkingRead,
      notification: notification ?? this.notification,
      error:
          identical(error, _notificationsSentinel)
              ? this.error
              : error as String?,
    );
  }
}

final notificationDetailProvider = StateNotifierProvider.family<
  NotificationDetailNotifier,
  NotificationDetailState,
  String
>((ref, id) {
  return NotificationDetailNotifier(
    ref.read(notificationsRepositoryProvider),
    ref.read(notificationsProvider.notifier),
    id,
  );
});

class NotificationDetailNotifier
    extends StateNotifier<NotificationDetailState> {
  NotificationDetailNotifier(this._repository, this._listNotifier, this._id)
    : super(const NotificationDetailState()) {
    load();
  }

  final NotificationsRepository _repository;
  final NotificationsNotifier _listNotifier;
  final String _id;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final notification = await _repository.fetchNotification(_id);
      state = state.copyWith(
        isLoading: false,
        notification: notification,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString().replaceFirst('ApiException: ', ''),
      );
    }
  }

  Future<void> markAsRead() async {
    final current = state.notification;
    if (current == null || !current.isUnread || state.isMarkingRead) {
      return;
    }

    state = state.copyWith(isMarkingRead: true, error: null);

    try {
      final updated = await _repository.markAsRead(current.id);
      state = state.copyWith(
        isMarkingRead: false,
        notification: updated,
        error: null,
      );
      _listNotifier.applyRead(updated);
    } catch (error) {
      state = state.copyWith(
        isMarkingRead: false,
        error: error.toString().replaceFirst('ApiException: ', ''),
      );
    }
  }
}
