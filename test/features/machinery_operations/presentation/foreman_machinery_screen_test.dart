import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_model.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_operations_provider.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/foreman/foreman_machinery_screen.dart';

class _Repository extends MachineryOperationsRepository {
  _Repository() : super(Dio());

  int? approvedId;
  int? rejectedId;
  String? rejectionReason;

  @override
  Future<void> approveShiftReport(int shiftReportId) async {
    approvedId = shiftReportId;
  }

  @override
  Future<void> rejectShiftReport(int shiftReportId, String reason) async {
    rejectedId = shiftReportId;
    rejectionReason = reason;
  }
}

class _Notifier extends MachineryOperationsNotifier {
  _Notifier(this.repository, {this.reportActions = const []})
    : super(repository) {
    state = MachineryOperationsState(
      assets: const [
        MachineryAssetModel(
          id: 10,
          assetCode: 'EXCAVATOR_ASSET_2026_001',
          name: 'Экскаватор_северный_корпус_участок_17',
          status: 'assigned',
          statusLabel: 'Ожидает подтверждения механика',
          availableActions: [],
          projectId: 30,
        ),
      ],
      shiftReports: [
        MachineryShiftReportModel(
          id: 71,
          assetId: 10,
          projectId: 30,
          reportDate: '2026-09-27',
          status: 'submitted',
          statusLabel: 'На проверке',
          actualHours: 8,
          fuelConsumed: 20,
          availableActions: reportActions,
          assetName: 'Экскаватор',
        ),
      ],
    );
  }

  final _Repository repository;
  final List<String> reportActions;

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('foreman asset card fits long text on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith(
            (ref) => _Notifier(_Repository()),
          ),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const ForemanMachineryScreen(),
        ),
      ),
    );

    expect(find.text('Экскаватор_северный_корпус_участок_17'), findsOneWidget);
    expect(find.text('Ожидает подтверждения механика'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend actions allow review for wildcard grant', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith(
            (ref) => _Notifier(repository, reportActions: ['approve']),
          ),
          permissionServiceProvider.overrideWithValue(
            PermissionService(
              context: UserContext.field,
              activeModules: const {},
              grantedPermissions: const {'machinery-operations.*'},
            ),
          ),
        ],
        child: const MaterialApp(home: ForemanMachineryScreen()),
      ),
    );

    await tester.tap(find.text('Экскаватор'));
    await tester.pumpAndSettle();

    expect(find.text('Проверка сменного рапорта'), findsOneWidget);
    expect(find.text('Подтвердить'), findsOneWidget);
    expect(find.text('Отклонить'), findsNothing);
    expect(repository.approvedId, isNull);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
  });

  testWidgets('wildcard grant cannot open report without allowed actions', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith(
            (ref) => _Notifier(repository),
          ),
          permissionServiceProvider.overrideWithValue(
            PermissionService(
              context: UserContext.field,
              activeModules: const {},
              grantedPermissions: const {'*'},
            ),
          ),
        ],
        child: const MaterialApp(home: ForemanMachineryScreen()),
      ),
    );

    await tester.tap(find.text('Экскаватор'));
    await tester.pumpAndSettle();

    expect(find.text('Проверка сменного рапорта'), findsNothing);
    expect(repository.approvedId, isNull);
    expect(repository.rejectedId, isNull);
  });

  testWidgets('canonical grant can approve submitted shift report', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith(
            (ref) => _Notifier(repository, reportActions: ['approve']),
          ),
          permissionServiceProvider.overrideWithValue(
            PermissionService(
              context: UserContext.field,
              activeModules: const {},
              grantedPermissions: const {'machinery-operations.shifts.approve'},
            ),
          ),
        ],
        child: const MaterialApp(home: ForemanMachineryScreen()),
      ),
    );

    await tester.tap(find.text('Экскаватор'));
    await tester.pumpAndSettle();
    expect(find.text('Отклонить'), findsNothing);
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();

    expect(repository.approvedId, 71);
    expect(find.text('Рапорт подтвержден'), findsOneWidget);
  });

  testWidgets('reject requires reason and sends trimmed reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith(
            (ref) => _Notifier(repository, reportActions: ['reject']),
          ),
          permissionServiceProvider.overrideWithValue(
            PermissionService(
              context: UserContext.field,
              activeModules: const {},
              grantedPermissions: const {'machinery-operations.shifts.approve'},
            ),
          ),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.3),
                  viewInsets: const EdgeInsets.only(bottom: 240),
                ),
                child: child!,
              ),
          home: const ForemanMachineryScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Экскаватор'));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердить'), findsNothing);
    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repository.rejectedId, isNull);
    expect(find.text('Укажите причину'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Нет показаний  ');
    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();

    expect(repository.rejectedId, 71);
    expect(repository.rejectionReason, 'Нет показаний');
    expect(find.text('Рапорт отклонен'), findsOneWidget);
  });
}
