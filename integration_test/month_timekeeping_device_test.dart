import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/month_timekeeping_repository.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/month_timekeeping_screen.dart';

import '../test/features/workforce/timekeeping_fixture.dart';

class _Repository extends MonthTimekeepingRepository {
  _Repository() : super(Dio());
  int minutes = 0;
  int revision = 1;
  @override
  Future<TimekeepingPeriod> period(int id) async => TimekeepingPeriod.fromJson(
    timekeepingFixture(id: id, revision: revision, minutes: minutes),
  );
  @override
  Future<TimekeepingPeriod> saveCell(
    TimekeepingPeriod period,
    Map<String, dynamic> data,
  ) async {
    expect(period.revision, revision);
    expect(data['employee_id'], 12);
    expect(data['work_date'], '2026-09-02');
    expect(data['intervals'], isEmpty);
    minutes = data['duration_minutes'] as int;
    revision++;
    return this.period(period.id);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final dark in [false, true]) {
    testWidgets(
      'месячный табель на Android: тема ${dark ? 'тёмная' : 'светлая'}',
      (tester) async {
        final repository = _Repository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              monthTimekeepingRepositoryProvider.overrideWithValue(repository),
              permissionServiceProvider.overrideWithValue(
                PermissionService(
                  context: UserContext.field,
                  activeModules: {AppModule.workforceManagement},
                  grantedPermissions: {
                    'workforce.timekeeping.view',
                    'workforce.timekeeping.manage',
                  },
                ),
              ),
            ],
            child: MaterialApp(
              theme: MostTheme.lightTheme,
              darkTheme: MostTheme.darkTheme,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const TimekeepingPeriodScreen(periodId: 7),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Иван Петров'));
        await tester.tap(find.text('Иван Петров'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('02'));
        await tester.tap(find.text('02'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Часы за день'),
          '7,5',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Сохранить часы'));
        await tester.tap(find.text('Сохранить часы'));
        await tester.pumpAndSettle();
        expect(repository.minutes, 450);
        await tester.scrollUntilVisible(
          find.textContaining('Часов: 7,5'),
          -240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('Часов: 7,5'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
