import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
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
  final rejectionAttempts = <String>[];
  Completer<void>? pendingRejection;
  bool failNextRejection = false;

  @override
  Future<void> approveShiftReport(int shiftReportId) async {
    approvedId = shiftReportId;
  }

  @override
  Future<void> rejectShiftReport(int shiftReportId, String reason) async {
    rejectionAttempts.add(reason);
    final pending = pendingRejection;
    if (pending != null) {
      await pending.future;
    }
    if (failNextRejection) {
      failNextRejection = false;
      throw const ApiException(
        'Причина отклонения не принята.',
        statusCode: 422,
      );
    }
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
  int loadCalls = 0;

  @override
  Future<void> load() async {
    loadCalls++;
  }
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

    await tester.scrollUntilVisible(
      find.text('Экскаватор_северный_корпус_участок_17'),
      200,
    );
    expect(find.text('Экскаватор_северный_корпус_участок_17'), findsOneWidget);
    expect(find.text('Ожидает подтверждения механика'), findsOneWidget);
    for (final label in ['Техника', 'На проверку', 'Проблемы']) {
      expect(tester.getSize(find.text(label)).width, greaterThanOrEqualTo(120));
    }
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

    await tester.scrollUntilVisible(
      find.byKey(const Key('shift-report-review-71')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('shift-report-review-71')));
    await tester.tap(find.byKey(const Key('shift-report-review-71')));
    await tester.pumpAndSettle();

    expect(find.text('Проверка сменного рапорта'), findsOneWidget);
    expect(find.text('Подтвердить'), findsOneWidget);
    expect(find.text('Отклонить'), findsNothing);
    expect(repository.approvedId, isNull);
    expect(repository.rejectedId, isNull);
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

    await tester.scrollUntilVisible(
      find.byKey(const Key('shift-report-review-71')),
      200,
    );
    await tester.tap(find.byKey(const Key('shift-report-review-71')));
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

    await tester.scrollUntilVisible(find.text('Экскаватор'), 200);
    await tester.tap(find.text('Экскаватор'));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердить'), findsNothing);
    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repository.rejectedId, isNull);
    expect(find.text('Укажите причину'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('shift-review-reason')),
      '  Нет показаний  ',
    );
    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();

    expect(repository.rejectedId, 71);
    expect(repository.rejectionReason, 'Нет показаний');
    expect(find.text('Рапорт отклонен'), findsOneWidget);
  });

  testWidgets('failed rejection keeps its reason open for a guarded retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository()..failNextRejection = true;
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

    await tester.scrollUntilVisible(
      find.byKey(const Key('shift-report-review-71')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('shift-report-review-71')));
    await tester.tap(find.byKey(const Key('shift-report-review-71')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('shift-review-reason')),
      'Причина должна сохраниться',
    );
    await tester.ensureVisible(find.text('Отклонить'));
    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();

    expect(find.text('Проверка сменного рапорта'), findsOneWidget);
    expect(
      find.textContaining('Причина отклонения не принята.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('shift-review-reason')))
          .controller!
          .text,
      'Причина должна сохраниться',
    );
    expect(repository.rejectionAttempts, ['Причина должна сохраниться']);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();

    expect(repository.rejectionAttempts, [
      'Причина должна сохраниться',
      'Причина должна сохраниться',
    ]);
    expect(repository.rejectedId, 71);
    expect(find.text('Рапорт отклонен'), findsOneWidget);
  });

  testWidgets('pending rejection ignores a duplicate tap', (tester) async {
    final repository = _Repository()..pendingRejection = Completer<void>();
    final notifier = _Notifier(repository, reportActions: ['reject']);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith((ref) => notifier),
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

    await tester.scrollUntilVisible(
      find.byKey(const Key('shift-report-review-71')),
      200,
    );
    await tester.tap(find.byKey(const Key('shift-report-review-71')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('shift-review-reason')),
      'Одна отправка',
    );
    await tester.tap(find.text('Отклонить'));
    await tester.pump();
    await tester.tap(find.text('Отклонить'), warnIfMissed: false);
    await tester.pump();

    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(find.text('Проверка сменного рапорта'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Проверка сменного рапорта'), findsOneWidget);

    expect(repository.rejectionAttempts, ['Одна отправка']);
    repository.pendingRejection!.complete();
    await tester.pumpAndSettle();
    expect(repository.rejectedId, 71);
    expect(repository.rejectionReason, 'Одна отправка');
    expect(notifier.loadCalls, 1);
    expect(find.text('Проверка сменного рапорта'), findsNothing);
    expect(find.text('Рапорт отклонен'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
