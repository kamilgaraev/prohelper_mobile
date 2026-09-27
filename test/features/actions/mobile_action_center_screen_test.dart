import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/widgets/pro_search_filter_bar.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_center_screen.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';
import 'package:prohelpers_mobile/features/notifications/domain/notifications_provider.dart';

class _FakeModulesRepository extends ModulesRepository {
  _FakeModulesRepository() : super(Dio());

  @override
  Future<List<MobileModuleModel>> fetchModules({int? projectId}) async =>
      const [];
}

class _FakeModulesNotifier extends ModulesNotifier {
  _FakeModulesNotifier(
    List<MobileModuleModel> modules, {
    ModulesState? initialState,
  }) : super(_FakeModulesRepository(), canLoad: false) {
    state =
        initialState ??
        ModulesState(isLoading: false, modules: modules, error: null);
  }
}

class _FakeNotificationsRepository extends NotificationsRepository {
  _FakeNotificationsRepository() : super(Dio());

  @override
  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int perPage = 20,
    NotificationFilter filter = NotificationFilter.all,
  }) async => NotificationsPageResult(
    items: const [],
    currentPage: page,
    lastPage: page,
    perPage: perPage,
    total: 0,
  );

  @override
  Future<int> fetchUnreadCount() async => 0;
}

class _FakeNotificationsNotifier extends NotificationsNotifier {
  _FakeNotificationsNotifier() : super(_FakeNotificationsRepository());
}

void main() {
  testWidgets('renders action center with search recommendations and catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => _FakeNotificationsNotifier(),
          ),
          modulesProvider.overrideWith(
            (ref) => _FakeModulesNotifier(const [
              MobileModuleModel(
                slug: 'site-requests',
                title: 'Заявки объекта',
                description: 'Заявки',
                icon: 'clipboard',
                supportedOnMobile: true,
                order: 1,
                route: 'site_requests',
              ),
              MobileModuleModel(
                slug: 'basic-warehouse',
                title: 'Склад',
                description: 'Остатки и движения',
                icon: 'warehouse',
                supportedOnMobile: true,
                order: 2,
                route: 'warehouse',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: MobileActionCenterScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Действия'), findsOneWidget);
    expect(find.text('Найти действие или раздел'), findsOneWidget);
    final searchBar = tester.widget<ProSearchFilterBar<String>>(
      find.byType(ProSearchFilterBar<String>),
    );

    expect(searchBar.density, ProSearchFilterDensity.compact);
    expect(find.text('Рекомендуемые'), findsOneWidget);
    expect(find.text('Все разделы'), findsOneWidget);
    expect(find.text('Полевые работы'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Рекомендуемые'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Все разделы'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Полевые работы'),
        matching: find.byType(ProSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a clear recovery action when action search has no results',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsProvider.overrideWith(
              (ref) => _FakeNotificationsNotifier(),
            ),
            modulesProvider.overrideWith(
              (ref) => _FakeModulesNotifier(const [
                MobileModuleModel(
                  slug: 'site-requests',
                  title: 'Заявки объекта',
                  description: 'Заявки',
                  icon: 'clipboard',
                  supportedOnMobile: true,
                  order: 1,
                  route: 'site_requests',
                ),
                MobileModuleModel(
                  slug: 'basic-warehouse',
                  title: 'Склад',
                  description: 'Остатки и движения',
                  icon: 'warehouse',
                  supportedOnMobile: true,
                  order: 2,
                  route: 'warehouse',
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: MobileActionCenterScreen()),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.pumpAndSettle();

      expect(find.text('Найдено: 0 из 2'), findsOneWidget);
      expect(find.text('Действия не найдены'), findsOneWidget);
      expect(find.text('Сбросить поиск'), findsOneWidget);

      await tester.tap(find.text('Сбросить поиск'));
      await tester.pumpAndSettle();

      expect(find.text('Доступно разделов: 2'), findsOneWidget);
      expect(find.text('Все разделы'), findsOneWidget);
      expect(find.text('Действия не найдены'), findsNothing);
    },
  );

  testWidgets('shows retry when loading modules fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => _FakeNotificationsNotifier(),
          ),
          modulesProvider.overrideWith(
            (ref) => _FakeModulesNotifier(
              const [],
              initialState: const ModulesState(
                error: 'Сервер не ответил вовремя. Попробуйте еще раз.',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: MobileActionCenterScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить действия'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Нет доступных действий'), findsOneWidget);
    expect(find.text('Повторить'), findsNothing);
  });
}
