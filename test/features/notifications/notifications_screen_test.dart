import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/widgets/notification_card.dart';

class _NotificationsRepository extends NotificationsRepository {
  _NotificationsRepository() : super(Dio());

  final markedReadIds = <String>[];
  var markedAllAsRead = false;

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async {
    return NotificationsPageResult(
      items: [_notification()],
      currentPage: 1,
      lastPage: 1,
      perPage: perPage,
      total: 1,
    );
  }

  @override
  Future<int> fetchUnreadCount() async => 1;

  @override
  Future<NotificationModel> markAsRead(String id) async {
    markedReadIds.add(id);
    return _notification(read: true);
  }

  @override
  Future<int> markAllAsRead() async {
    markedAllAsRead = true;
    return 1;
  }
}

void main() {
  testWidgets('непрочитанные уведомления показывают действия, а не состояние', (
    tester,
  ) async {
    final repository = _NotificationsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => NotificationsNotifier(repository),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Отметить все'), findsOneWidget);
    expect(find.text('Все прочитаны'), findsNothing);
    expect(find.text('Отметить прочитанным'), findsOneWidget);
    expect(find.text('Прочитано'), findsNothing);

    await tester.tap(find.text('Отметить прочитанным'));
    await tester.pumpAndSettle();

    expect(repository.markedReadIds, ['n1']);
    expect(find.text('Отметить прочитанным'), findsNothing);
  });

  testWidgets('notification card separates card content from inline actions', (
    tester,
  ) async {
    var opened = false;
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: MostTheme.lightTheme,
          home: Scaffold(
            body: NotificationCard(
              notification: _notification(),
              onTap: () => opened = true,
              onMarkRead: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Открыть'), findsOneWidget);
      expect(find.text('Отметить прочитанным'), findsOneWidget);
      const actionContext = 'Вход с нового устройства, 02.07.2026 08:45';
      expect(
        find.bySemanticsLabel('Открыть уведомление: $actionContext'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Отметить уведомление прочитанным: $actionContext',
        ),
        findsOneWidget,
      );
      final openActionNode = tester.getSemantics(
        find.bySemanticsLabel('Открыть уведомление: $actionContext'),
      );
      final markReadActionNode = tester.getSemantics(
        find.bySemanticsLabel(
          'Отметить уведомление прочитанным: $actionContext',
        ),
      );
      final cardRect = tester.getRect(find.byType(NotificationCard));

      expect(openActionNode.rect.width, lessThan(cardRect.width / 2));
      expect(markReadActionNode.rect.width, lessThan(cardRect.width / 2));
      final openActionBoundary = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Открыть уведомление: $actionContext',
        ),
      );
      final markReadActionBoundary = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Отметить уведомление прочитанным: $actionContext',
        ),
      );

      expect(openActionBoundary.container, isTrue);
      expect(markReadActionBoundary.container, isTrue);

      final nestedActionButtons = _collectSemanticsNodes(
            tester.binding.rootPipelineOwner,
          )
          .where((node) => node.hasFlag(SemanticsFlag.isButton))
          .where((node) {
            final labels = _collectSemanticsSubtree(node)
                .map((child) => child.getSemanticsData().label)
                .where((label) => label.isNotEmpty)
                .join('\n');

            return labels.contains('Вход с нового устройства') &&
                labels.contains('Отметить прочитанным');
          })
          .toList(growable: false);

      expect(nestedActionButtons, isEmpty);

      await tester.tap(find.text('Открыть'));
      await tester.pump();

      expect(opened, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('notification screen keeps mark all action semantics single', (
    tester,
  ) async {
    final repository = _NotificationsRepository();
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsProvider.overrideWith(
              (ref) => NotificationsNotifier(repository),
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Отметить все'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Отметить все уведомления прочитанными'),
        findsOneWidget,
      );

      final nestedMarkAllButtons = _collectSemanticsNodes(
            tester.binding.rootPipelineOwner,
          )
          .where((node) => node.hasFlag(SemanticsFlag.isButton))
          .where((node) {
            final data = node.getSemanticsData();
            final childLabels =
                _collectSemanticsSubtree(node)
                    .skip(1)
                    .map((child) => child.getSemanticsData().label)
                    .where((label) => label.isNotEmpty)
                    .toSet();

            return data.label == 'Отметить все уведомления прочитанными' &&
                childLabels.contains('Отметить все');
          })
          .toList(growable: false);

      expect(nestedMarkAllButtons, isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('notification filters expose purpose-driven semantics', (
    tester,
  ) async {
    final repository = _NotificationsRepository();
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsProvider.overrideWith(
              (ref) => NotificationsNotifier(repository),
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Все'), findsOneWidget);
      expect(find.bySemanticsLabel('Показать все уведомления'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Показать непрочитанные уведомления, 1'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Показать прочитанные уведомления'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Все'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'notification priority pills keep readable light-theme contrast',
    (tester) async {
      final categoryLabel = String.fromCharCodes([
        0x0411,
        0x0435,
        0x0437,
        0x043E,
        0x043F,
        0x0430,
        0x0441,
        0x043D,
        0x043E,
        0x0441,
        0x0442,
        0x044C,
      ]);

      for (final priority in ['critical', 'high', 'low', 'normal']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: MostTheme.lightTheme,
            home: Scaffold(
              body: NotificationCard(
                notification: _notification(priority: priority),
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        final categoryText = tester.widget<Text>(find.text(categoryLabel));
        final color = categoryText.style?.color;

        expect(color, isNotNull);
        expect(
          _contrastRatio(color!, MostTheme.lightTheme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'priority $priority',
        );
      }
    },
  );

  testWidgets('notification list keeps content above bottom gesture area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _NotificationsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => NotificationsNotifier(repository),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: NotificationsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scrollBottom = tester.getBottomLeft(find.byType(CustomScrollView)).dy;

    expect(scrollBottom, lessThanOrEqualTo(810));
  });
}

NotificationModel _notification({bool read = false, String priority = 'high'}) {
  return NotificationModel(
    id: 'n1',
    type: 'security_login',
    notificationType: 'security_login',
    title: 'Вход с нового устройства',
    message: 'В аккаунт выполнен вход с устройства Windows, Chrome.',
    priority: priority,
    category: 'security',
    data: const <String, dynamic>{},
    actions: const <NotificationActionModel>[],
    readAt: read ? DateTime(2026, 7, 2, 9) : null,
    createdAt: DateTime(2026, 7, 2, 8, 45),
  );
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter =
      foregroundLuminance > backgroundLuminance
          ? foregroundLuminance
          : backgroundLuminance;
  final darker =
      foregroundLuminance > backgroundLuminance
          ? backgroundLuminance
          : foregroundLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}

List<SemanticsNode> _collectSemanticsNodes(PipelineOwner owner) {
  final roots = <SemanticsNode>[];
  final root = owner.semanticsOwner?.rootSemanticsNode;
  if (root != null) {
    roots.add(root);
  }
  owner.visitChildren((child) {
    roots.addAll(_collectSemanticsNodes(child));
  });

  final nodes = <SemanticsNode>[];
  for (final root in roots) {
    nodes.addAll(_collectSemanticsSubtree(root));
  }
  return nodes;
}

List<SemanticsNode> _collectSemanticsSubtree(SemanticsNode root) {
  final nodes = <SemanticsNode>[root];
  root.visitChildren((child) {
    nodes.addAll(_collectSemanticsSubtree(child));
    return true;
  });
  return nodes;
}
