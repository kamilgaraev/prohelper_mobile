import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';

void main() {
  test('loads notification list and unread count', () async {
    final repository = _NotificationsRepository();
    final notifier = NotificationsNotifier(repository);

    await _pumpAsync();

    expect(notifier.state.items, hasLength(2));
    expect(notifier.state.unreadCount, 2);
    expect(notifier.state.hasMore, isFalse);
    expect(repository.loadedFilters, [NotificationFilter.all]);
  });

  test('mark as read updates item and decrements unread count', () async {
    final repository = _NotificationsRepository();
    final notifier = NotificationsNotifier(repository);
    await _pumpAsync();

    await notifier.markAsRead('n1');

    expect(notifier.state.items.first.isUnread, isFalse);
    expect(notifier.state.unreadCount, 1);
  });

  test('mark all as read clears unread count', () async {
    final repository = _NotificationsRepository();
    final notifier = NotificationsNotifier(repository);
    await _pumpAsync();

    await notifier.markAllAsRead();

    expect(notifier.state.unreadCount, 0);
    expect(notifier.state.items.every((item) => !item.isUnread), isTrue);
  });
}

Future<void> _pumpAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _NotificationsRepository extends NotificationsRepository {
  _NotificationsRepository() : super(Dio());

  final loadedFilters = <NotificationFilter>[];

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    loadedFilters.add(filter);
    return NotificationsPageResult(
      items: [_notification('n1'), _notification('n2')],
      currentPage: 1,
      lastPage: 1,
      perPage: perPage,
      total: 2,
    );
  }

  @override
  Future<int> fetchUnreadCount() async => 2;

  @override
  Future<NotificationModel> markAsRead(String id) async {
    return _notification(id, read: true);
  }

  @override
  Future<int> markAllAsRead() async => 2;
}

NotificationModel _notification(String id, {bool read = false}) {
  return NotificationModel(
    id: id,
    type: 'site_request_created',
    notificationType: 'site_request_created',
    title: 'Новая заявка',
    message: 'Заявка требует согласования',
    priority: 'high',
    category: 'site-requests',
    data: const <String, dynamic>{
      'module': 'site-requests',
      'site_request_id': 45,
    },
    actions: const <NotificationActionModel>[],
    readAt: read ? DateTime(2026, 5, 22, 10) : null,
    createdAt: DateTime(2026, 5, 22, 9),
  );
}
