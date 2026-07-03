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

class _FakeModulesRepository extends ModulesRepository {
  _FakeModulesRepository() : super(Dio());

  @override
  Future<List<MobileModuleModel>> fetchModules() async => const [];
}

class _FakeModulesNotifier extends ModulesNotifier {
  _FakeModulesNotifier(List<MobileModuleModel> modules)
    : super(_FakeModulesRepository(), canLoad: false) {
    state = ModulesState(isLoading: false, modules: modules, error: null);
  }
}

void main() {
  testWidgets('renders action center with search recommendations and catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
}
