import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:prohelpers_mobile/features/payments/data/payment_document_model.dart';
import 'package:prohelpers_mobile/features/payments/data/payments_repository.dart';
import 'package:prohelpers_mobile/features/payments/presentation/payments_screen.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_screen.dart';

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

  testWidgets('opens payment document detail from push record payload', (
    tester,
  ) async {
    final notification = _notification(
      type: 'payment_document_created',
      data: const <String, dynamic>{
        'target_type': 'payment_document',
        'target_id': 640,
      },
    );
    final repository = _NotificationsRepository(notification);
    final payments = _FailedPaymentsRepository();

    await tester.pumpWidget(
      _buildDetail(
        repository,
        paymentsRepository: payments,
        autoOpenTarget: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaymentDocumentDetailScreen), findsOneWidget);
    expect(payments.requestedId, 640);
    expect(find.text('Документ'), findsOneWidget);
    expect(
      find.text('Не удалось выполнить операцию. Проверьте связь и повторите.'),
      findsOneWidget,
    );
  });

  testWidgets('reports missing record id and does not open a detail screen', (
    tester,
  ) async {
    final notification = _notification(
      type: 'quality_defect_created',
      data: const <String, dynamic>{'target_type': 'quality_defect'},
    );

    await tester.pumpWidget(
      _buildDetail(
        _NotificationsRepository(notification),
        autoOpenTarget: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('В уведомлении нет идентификатора записи.'), findsOne);
    expect(
      find.text('Карточка замечания по качеству не указана в уведомлении.'),
      findsOne,
    );
  });

  testWidgets('opens purchase request card from push payload', (tester) async {
    final notification = _notification(
      type: 'purchase_request_created',
      data: const <String, dynamic>{
        'target_type': 'purchase_request',
        'target_id': 81,
      },
    );
    final procurement = _FailedProcurementRepository();

    await tester.pumpWidget(
      _buildDetail(
        _NotificationsRepository(notification),
        procurementRepository: procurement,
        autoOpenTarget: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProcurementPurchaseRequestDetailScreen), findsOneWidget);
    expect(procurement.requestedId, 81);
    expect(find.text('Не удалось загрузить заявку'), findsOneWidget);
  });
}

Widget _buildDetail(
  _NotificationsRepository repository, {
  PaymentsRepository? paymentsRepository,
  ProcurementRepository? procurementRepository,
  bool autoOpenTarget = false,
}) {
  return ProviderScope(
    overrides: [
      notificationsRepositoryProvider.overrideWith((ref) => repository),
      if (paymentsRepository != null)
        paymentsRepositoryProvider.overrideWith((ref) => paymentsRepository),
      if (procurementRepository != null)
        procurementRepositoryProvider.overrideWith(
          (ref) => procurementRepository,
        ),
    ],
    child: MaterialApp(
      home: NotificationDetailScreen(
        notificationId: repository.notification.id,
        initialNotification: repository.notification,
        autoOpenTarget: autoOpenTarget,
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

class _FailedPaymentsRepository extends PaymentsRepository {
  _FailedPaymentsRepository() : super(Dio());

  int? requestedId;

  @override
  Future<PaymentDocumentModel> detail(int id) async {
    requestedId = id;
    throw const FormatException('Не удалось загрузить документ.');
  }
}

class _FailedProcurementRepository extends ProcurementRepository {
  _FailedProcurementRepository() : super(Dio());

  int? requestedId;

  @override
  Future<ProcurementPurchaseRequestModel> fetchPurchaseRequest(int id) async {
    requestedId = id;
    throw const FormatException('Заявка недоступна.');
  }
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
