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

    expect(find.text('Действия'), findsOneWidget);
    expect(
      find.text('Для вашей роли пока нет мобильных разделов.'),
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

    expect(find.text('Склад'), findsWidgets);
    expect(find.text('График'), findsOneWidget);
  });

  testWidgets('прокручивает длинный список модулей до нижних действий', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      createWidget(
        ModulesState(
          isLoading: false,
          modules: const [
            MobileModuleModel(
              slug: 'site-requests',
              title: 'Site requests',
              description: 'Requests',
              icon: 'clipboard',
              supportedOnMobile: true,
              order: 1,
              route: 'site_requests',
            ),
            MobileModuleModel(
              slug: 'basic-warehouse',
              title: 'Warehouse',
              description: 'Warehouse',
              icon: 'warehouse',
              supportedOnMobile: true,
              order: 2,
              route: 'warehouse',
            ),
            MobileModuleModel(
              slug: 'schedule-management',
              title: 'Schedule',
              description: 'Schedule',
              icon: 'timeline',
              supportedOnMobile: true,
              order: 3,
              route: 'schedule',
            ),
            MobileModuleModel(
              slug: 'ai-assistant',
              title: 'AI assistant',
              description: 'Assistant',
              icon: 'spark',
              supportedOnMobile: true,
              order: 4,
              route: 'ai_assistant',
            ),
            MobileModuleModel(
              slug: 'workflow-management',
              title: 'Workflow',
              description: 'Workflow',
              icon: 'hub',
              supportedOnMobile: true,
              order: 5,
              route: 'workflow_management',
            ),
            MobileModuleModel(
              slug: 'time-tracking',
              title: 'Time tracking',
              description: 'Time',
              icon: 'timer',
              supportedOnMobile: true,
              order: 6,
              route: 'time_tracking',
            ),
            MobileModuleModel(
              slug: 'construction-journal',
              title: 'Journal',
              description: 'Journal',
              icon: 'journal',
              supportedOnMobile: true,
              order: 7,
              route: 'construction_journal',
            ),
            MobileModuleModel(
              slug: 'budget-estimates',
              title: 'Budget',
              description: 'Budget',
              icon: 'calculate',
              supportedOnMobile: true,
              order: 8,
              route: 'budget_estimates',
            ),
            MobileModuleModel(
              slug: 'quality-control',
              title: 'Quality',
              description: 'Quality',
              icon: 'quality',
              supportedOnMobile: true,
              order: 9,
              route: 'quality-control',
            ),
            MobileModuleModel(
              slug: 'safety-management',
              title: 'Safety',
              description: 'Safety',
              icon: 'shield-check',
              supportedOnMobile: true,
              order: 10,
              route: 'safety-management',
            ),
            MobileModuleModel(
              slug: 'machinery-operations',
              title: 'Machinery',
              description: 'Machinery',
              icon: 'machinery',
              supportedOnMobile: true,
              order: 11,
              route: 'machinery-operations',
            ),
            MobileModuleModel(
              slug: 'production-labor',
              title: 'Production',
              description: 'Production',
              icon: 'engineer',
              supportedOnMobile: true,
              order: 12,
              route: 'production-labor',
            ),
            MobileModuleModel(
              slug: 'workforce-management',
              title: 'Workforce',
              description: 'Workforce',
              icon: 'workforce',
              supportedOnMobile: true,
              order: 13,
              route: 'workforce-management',
            ),
            MobileModuleModel(
              slug: 'handover-acceptance',
              title: 'Handover',
              description: 'Handover',
              icon: 'handover',
              supportedOnMobile: true,
              order: 14,
              route: 'handover-acceptance',
            ),
            MobileModuleModel(
              slug: 'procurement',
              title: 'Procurement',
              description: 'Procurement',
              icon: 'procurement',
              supportedOnMobile: true,
              order: 15,
              route: 'procurement',
            ),
            MobileModuleModel(
              slug: 'video-monitoring',
              title: 'Video monitoring',
              description: 'Video',
              icon: 'video',
              supportedOnMobile: true,
              order: 16,
              route: 'video-monitoring',
            ),
          ],
          error: null,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Все разделы'), findsOneWidget);
    expect(find.text('Полевые работы'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('quick-action-sheet-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    expect(find.text('Управление'), findsOneWidget);
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

    expect(find.text('Качество'), findsWidgets);
    expect(find.text('Приемка'), findsOneWidget);
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
    await tester.tap(find.text('Качество'));
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
    await tester.tap(find.text('Безопасность'));
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
    await tester.tap(find.text('Приемка'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HandoverAcceptanceScreen), findsOneWidget);
  });
}
