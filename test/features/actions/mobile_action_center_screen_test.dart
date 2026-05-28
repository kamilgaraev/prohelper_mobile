import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
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
    expect(find.text('Рекомендуемые'), findsOneWidget);
    expect(find.text('Все разделы'), findsOneWidget);
    expect(find.text('Полевые работы'), findsOneWidget);
  });
}
