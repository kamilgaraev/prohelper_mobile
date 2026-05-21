import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/widgets/quick_action_sheet.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/domain/handover_acceptance_provider.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/quality_control_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';
import 'package:prohelpers_mobile/features/safety/domain/safety_provider.dart';
import 'package:prohelpers_mobile/features/safety/presentation/safety_screen.dart';

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

class _FakeQualityControlNotifier extends QualityControlNotifier {
  _FakeQualityControlNotifier() : super(QualityControlRepository(Dio()));

  @override
  Future<void> loadDefects() async {}
}

class _FakeSafetyNotifier extends SafetyNotifier {
  _FakeSafetyNotifier() : super(SafetyRepository(Dio()));

  @override
  Future<void> load() async {}
}

class _FakeHandoverAcceptanceNotifier extends HandoverAcceptanceNotifier {
  _FakeHandoverAcceptanceNotifier()
    : super(HandoverAcceptanceRepository(Dio()));

  @override
  Future<void> loadScopes() async {}
}

void main() {
  Widget createWidget(ModulesState state) {
    return ProviderScope(
      overrides: [
        modulesProvider.overrideWith((ref) => _FakeModulesNotifier(state)),
        qualityControlProvider.overrideWith(
          (ref) => _FakeQualityControlNotifier(),
        ),
        safetyProvider.overrideWith((ref) => _FakeSafetyNotifier()),
        handoverAcceptanceProvider.overrideWith(
          (ref) => _FakeHandoverAcceptanceNotifier(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: QuickActionSheet())),
    );
  }

  Widget createLauncherWidget(ModulesState state) {
    return ProviderScope(
      overrides: [
        modulesProvider.overrideWith((ref) => _FakeModulesNotifier(state)),
        qualityControlProvider.overrideWith(
          (ref) => _FakeQualityControlNotifier(),
        ),
        safetyProvider.overrideWith((ref) => _FakeSafetyNotifier()),
        handoverAcceptanceProvider.overrideWith(
          (ref) => _FakeHandoverAcceptanceNotifier(),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => const Scaffold(body: QuickActionSheet()),
                        ),
                      );
                    },
                    child: const Text('Открыть'),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  testWidgets('показывает пустое состояние без модулей', (tester) async {
    await tester.pumpWidget(
      createWidget(
        const ModulesState(isLoading: false, modules: [], error: null),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Быстрые действия'), findsOneWidget);
    expect(
      find.text('Для вашей роли пока нет мобильных модулей.'),
      findsOneWidget,
    );
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

  testWidgets('показывает модули качества и приемки', (tester) async {
    await tester.pumpWidget(
      createWidget(
        ModulesState(
          isLoading: false,
          modules: const [
            MobileModuleModel(
              slug: 'quality-control',
              title: 'Контроль качества',
              description: 'Замечания',
              icon: 'quality',
              supportedOnMobile: true,
              order: 1,
              route: 'quality-control',
            ),
            MobileModuleModel(
              slug: 'handover-acceptance',
              title: 'Приемка зон',
              description: 'Punch-list',
              icon: 'handover',
              supportedOnMobile: true,
              order: 2,
              route: 'handover-acceptance',
            ),
          ],
          error: null,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Контроль качества'), findsOneWidget);
    expect(find.text('Приемка зон'), findsOneWidget);
  });

  testWidgets('открывает экран контроля качества', (tester) async {
    await tester.pumpWidget(
      createLauncherWidget(
        ModulesState(
          isLoading: false,
          modules: const [
            MobileModuleModel(
              slug: 'quality-control',
              title: 'Контроль качества',
              description: 'Замечания',
              icon: 'quality',
              supportedOnMobile: true,
              order: 1,
              route: 'quality-control',
            ),
          ],
          error: null,
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Контроль качества'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(QualityControlScreen), findsOneWidget);
  });

  testWidgets('открывает экран охраны труда', (tester) async {
    await tester.pumpWidget(
      createLauncherWidget(
        ModulesState(
          isLoading: false,
          modules: const [
            MobileModuleModel(
              slug: 'safety-management',
              title: 'Охрана труда',
              description: 'Происшествия',
              icon: 'shield-check',
              supportedOnMobile: true,
              order: 1,
              route: 'safety-management',
            ),
          ],
          error: null,
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Охрана труда'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SafetyScreen), findsOneWidget);
  });

  testWidgets('открывает экран приемки зон', (tester) async {
    await tester.pumpWidget(
      createLauncherWidget(
        ModulesState(
          isLoading: false,
          modules: const [
            MobileModuleModel(
              slug: 'handover-acceptance',
              title: 'Приемка зон',
              description: 'Punch-list',
              icon: 'handover',
              supportedOnMobile: true,
              order: 1,
              route: 'handover-acceptance',
            ),
          ],
          error: null,
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Приемка зон'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HandoverAcceptanceScreen), findsOneWidget);
  });
}
