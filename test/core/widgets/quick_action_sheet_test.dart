import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/widgets/quick_action_sheet.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';

class _FakeModulesRepository extends ModulesRepository {
  _FakeModulesRepository() : super(Dio());

  @override
  Future<List<MobileModuleModel>> fetchModules() async => const [];
}

class _FakeModulesNotifier extends ModulesNotifier {
  _FakeModulesNotifier(ModulesState initialState)
      : super(_FakeModulesRepository(), canLoad: false) {
    state = initialState;
  }
}

void main() {
  Widget createWidget(ModulesState state) {
    return ProviderScope(
      overrides: [
        modulesProvider.overrideWith((ref) => _FakeModulesNotifier(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: QuickActionSheet(),
        ),
      ),
    );
  }

  testWidgets('показывает пустое состояние без модулей', (tester) async {
    await tester.pumpWidget(
      createWidget(
        const ModulesState(
          isLoading: false,
          modules: [],
          error: null,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Быстрые действия'), findsOneWidget);
    expect(find.text('Для вашей роли пока нет мобильных модулей.'), findsOneWidget);
  });

  testWidgets('показывает доступные мобильные модули', (tester) async {
    await tester.pumpWidget(
      createWidget(
        ModulesState(
          isLoading: false,
          modules: const [
            MobileModuleModel(
              slug: 'basic-warehouse',
              title: 'Склад',
              description: 'Остатки и движения',
              icon: 'warehouse',
              supportedOnMobile: true,
              order: 1,
              route: 'warehouse',
            ),
            MobileModuleModel(
              slug: 'schedule-management',
              title: 'График работ',
              description: 'План и задачи',
              icon: 'timeline',
              supportedOnMobile: true,
              order: 2,
              route: 'schedule',
            ),
          ],
          error: null,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Склад'), findsOneWidget);
    expect(find.text('График работ'), findsOneWidget);
  });
}
