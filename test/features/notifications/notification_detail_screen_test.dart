import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notification_detail_screen.dart';

void main() {
  testWidgets(
    'hides open target action when notification has no direct target',
    (tester) async {
      final repository = _NotificationsRepository(_notification());

      await tester.pumpWidget(_buildDetail(repository));
      await tester.pumpAndSettle();

      expect(
        find.text('Для этого уведомления нет прямого перехода.'),
        findsOne,
      );
      expect(find.text('Открыть связанный раздел'), findsNothing);
    },
  );

  testWidgets(
    'shows open target action when notification has a direct target',
    (tester) async {
      final repository = _NotificationsRepository(
        _notification(
          type: 'site_request_created',
          data: const <String, dynamic>{
            'module': 'site-requests',
            'site_request_id': 45,
          },
        ),
      );

      await tester.pumpWidget(_buildDetail(repository));
      await tester.pumpAndSettle();

      expect(find.text('Откроется карточка заявки.'), findsOne);
      expect(find.text('Открыть связанный раздел'), findsOneWidget);
    },
  );

  testWidgets('keeps notification title compact inside detail card', (
    tester,
  ) async {
    final repository = _NotificationsRepository(
      _notification(
        title:
            'AI-смета требует доработки после проверки производственных данных',
        message:
            'Расчет завершен с проблемами. Откройте уведомление и проверьте подсказки.',
      ),
    );

    await tester.pumpWidget(_buildDetail(repository));
    await tester.pumpAndSettle();

    final titleFinder = find.text(
      'AI-смета требует доработки после проверки производственных данных',
    );
    final title = tester.widget<Text>(titleFinder);
    final context = tester.element(titleFinder);

    expect(
      title.style?.fontSize,
      lessThan(AppTypography.h1(context).fontSize!),
    );
    expect(title.maxLines, 3);
    expect(title.overflow, TextOverflow.ellipsis);
  });
}

Widget _buildDetail(_NotificationsRepository repository) {
  return ProviderScope(
    overrides: [
      notificationsRepositoryProvider.overrideWith((ref) => repository),
    ],
    child: MaterialApp(
      home: NotificationDetailScreen(
        notificationId: repository.notification.id,
        initialNotification: repository.notification,
      ),
    ),
  );
}

class _NotificationsRepository extends NotificationsRepository {
  _NotificationsRepository(this.notification) : super(Dio());

  final NotificationModel notification;

  @override
  Future<NotificationModel> fetchNotification(String id) async {
    return notification;
  }

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    return NotificationsPageResult(
      items: [notification],
      currentPage: 1,
      lastPage: 1,
      perPage: perPage,
      total: 1,
    );
  }

  @override
  Future<int> fetchUnreadCount() async => notification.isUnread ? 1 : 0;
}

NotificationModel _notification({
  String type = 'security_login',
  String title = 'Вход с нового устройства',
  String message = 'В аккаунт выполнен вход с устройства Windows.',
  Map<String, dynamic> data = const <String, dynamic>{},
}) {
  return NotificationModel(
    id: 'n1',
    type: type,
    notificationType: type,
    title: title,
    message: message,
    priority: 'high',
    category: 'security',
    data: data,
    actions: const <NotificationActionModel>[],
    readAt: DateTime(2026, 7, 2, 9),
    createdAt: DateTime(2026, 7, 2, 8, 45),
  );
}
