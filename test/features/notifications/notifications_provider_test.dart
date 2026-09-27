import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/secure_storage_service.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_repository.dart';
import 'package:prohelpers_mobile/features/auth/data/auth_session_identity.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';
import 'package:prohelpers_mobile/features/auth/domain/auth_provider.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';

void main() {
  testWidgets('dispose cancels the pending notification timeout timer', (
    tester,
  ) async {
    final repository = _DelayedNotificationsRepository();
    final notifier = NotificationsNotifier(
      repository,
      requestTimeout: const Duration(seconds: 1),
    );

    expect(notifier.state.isRefreshing, isTrue);
    notifier.dispose();
    await tester.pump();
  });

  test(
    'notification load ends with a retryable error after request timeout',
    () async {
      final repository = _HangingRefreshNotificationsRepository();
      final notifier = NotificationsNotifier(
        repository,
        requestTimeout: const Duration(milliseconds: 5),
      );

      await _pumpAsync();
      expect(notifier.state.items, hasLength(2));

      await notifier.load(refresh: true);

      expect(notifier.state.isRefreshing, isFalse);
      expect(notifier.state.items, hasLength(2));
      expect(
        notifier.state.error,
        'Сервер не ответил вовремя. Проверьте связь и повторите.',
      );
      expect(repository.cancelCount, 1);

      await notifier.load(refresh: true);

      expect(repository.fetchCount, 3);
      expect(repository.cancelCount, 2);
      expect(notifier.state.isRefreshing, isFalse);
      expect(notifier.state.items, hasLength(2));
      expect(notifier.state.error, isNotNull);
    },
  );

  test(
    'same-session online verification does not restart notification loading',
    () async {
      final storage = _TestSecureStorageService();
      final user = _user();
      final identity = _identity();
      final auth = _TestAuthNotifier(
        AuthAuthenticated(user, sessionIdentity: identity),
        storage,
      );
      final repository = _PendingNotificationsRepository();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => auth),
          notificationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(notificationsProvider, (_, __) {});
      addTearDown(subscription.close);

      final notifier = container.read(notificationsProvider.notifier);
      expect(container.read(notificationsProvider).isRefreshing, isTrue);
      expect(repository.fetchCount, 1);

      auth.updateAuthState(
        AuthAuthenticated(
          user,
          sessionIdentity: identity,
          isOnlineVerified: true,
        ),
      );
      await container.pump();

      expect(
        identical(container.read(notificationsProvider.notifier), notifier),
        isTrue,
      );
      expect(repository.fetchCount, 1);
      expect(container.read(notificationsProvider).isRefreshing, isTrue);

      repository.complete();
      await _pumpAsync();
      expect(container.read(notificationsProvider).isRefreshing, isFalse);
      expect(container.read(notificationsProvider).items, hasLength(1));

      auth.updateAuthState(
        AuthAuthenticated(
          user,
          sessionIdentity: AuthSessionIdentity(
            userId: identity.userId,
            organizationId: identity.organizationId,
            sessionId: 'session-2',
          ),
        ),
      );
      await container.pump();

      expect(
        identical(container.read(notificationsProvider.notifier), notifier),
        isFalse,
      );
      expect(repository.fetchCount, 2);
    },
  );

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

  test('ignores late notification errors after notifier dispose', () async {
    final repository = _DelayedNotificationsRepository();
    final notifier = NotificationsNotifier(repository);

    notifier.dispose();
    repository.completeWithAuthErrors();
    await _pumpAsync();
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

class _DelayedNotificationsRepository extends NotificationsRepository {
  _DelayedNotificationsRepository() : super(Dio());

  final _listCompleter = Completer<NotificationsPageResult>();
  final _unreadCompleter = Completer<int>();

  void completeWithAuthErrors() {
    _listCompleter.completeError(
      const ApiException('Unauthenticated.', statusCode: 401),
    );
    _unreadCompleter.completeError(
      const ApiException('Unauthenticated.', statusCode: 401),
    );
  }

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) {
    return _listCompleter.future;
  }

  @override
  Future<int> fetchUnreadCount() {
    return _unreadCompleter.future;
  }
}

class _HangingRefreshNotificationsRepository extends _NotificationsRepository {
  var fetchCount = 0;
  var cancelCount = 0;

  @override
  void cancelPendingFetch() {
    cancelCount++;
  }

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) {
    fetchCount++;
    if (fetchCount == 1) {
      return super.fetchNotifications(
        page: page,
        perPage: perPage,
        filter: filter,
      );
    }

    return Completer<NotificationsPageResult>().future;
  }
}

class _PendingNotificationsRepository extends _NotificationsRepository {
  final _listCompleter = Completer<NotificationsPageResult>();
  var fetchCount = 0;

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) {
    fetchCount++;
    return _listCompleter.future;
  }

  void complete() {
    _listCompleter.complete(
      NotificationsPageResult(
        items: [_notification('n1')],
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 1,
      ),
    );
  }
}

class _TestSecureStorageService extends SecureStorageService {}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository(SecureStorageService storage) : super(Dio(), storage);
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(
    AuthAuthenticated initialState,
    SecureStorageService storage,
  ) : super(_TestAuthRepository(storage), storage, autoCheckAuth: false) {
    state = initialState;
  }

  void updateAuthState(AuthAuthenticated next) {
    state = next;
  }
}

AuthSessionIdentity _identity() => const AuthSessionIdentity(
  userId: 1,
  organizationId: 10,
  sessionId: 'session-1',
);

User _user() {
  return User()
    ..serverId = 1
    ..email = 'foreman@test.local'
    ..name = 'Иван Иванов'
    ..currentOrganizationId = 10
    ..organizationName = 'СТРОЙ-ТУР'
    ..organizationsJson = '[{"id":10,"name":"СТРОЙ-ТУР"}]'
    ..roles = ['owner']
    ..permissionsJson = '{}';
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
