import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_model.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_action.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_operations_provider.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/operator/operator_shift_screen.dart';

class _Repository extends MachineryOperationsRepository {
  _Repository() : super(Dio());
}

class _Notifier extends MachineryOperationsNotifier {
  _Notifier({
    MachineryAssetModel? asset,
    bool activeShift = false,
    bool completedShift = false,
  }) : super(_Repository()) {
    state = MachineryOperationsState(
      assets: [
        asset ??
            const MachineryAssetModel(
              id: 10,
              assetCode: 'VP-10',
              name: 'Виброплита',
              status: 'assigned',
              statusLabel: 'Назначена',
              availableActions: ['start_shift'],
              projectId: 30,
              projectName: 'ЖК Север',
              assignmentId: 20,
              meterHours: 125.5,
            ),
      ],
      shiftReports:
          activeShift || completedShift
              ? [
                MachineryShiftReportModel(
                  id: 45,
                  assetId: 10,
                  projectId: 30,
                  reportDate: '2026-09-27',
                  status: completedShift ? 'completed' : 'draft',
                  statusLabel:
                      completedShift ? 'Смена завершена' : 'Смена активна',
                  actualHours: 0,
                  fuelConsumed: 0,
                  availableActions: [completedShift ? 'submit' : 'finish'],
                  meterStart: 125.5,
                  meterEnd: completedShift ? 125.51 : null,
                ),
              ]
              : const [],
    );
  }

  MachineryAction? action;
  final attemptedActions = <MachineryAction>[];
  int failedExecutionsRemaining = 0;
  Completer<void>? pendingExecution;
  int loadCalls = 0;

  @override
  Future<void> execute(MachineryAction action) async {
    attemptedActions.add(action);
    final pending = pendingExecution;
    if (pending != null) await pending.future;
    if (failedExecutionsRemaining > 0) {
      failedExecutionsRemaining--;
      throw const ApiException('Проверьте данные смены.', statusCode: 422);
    }
    this.action = action;
    await load();
  }

  @override
  Future<void> load() async {
    loadCalls++;
  }
}

void main() {
  testWidgets('completed shift can be submitted without starting another', (
    tester,
  ) async {
    final notifier = _Notifier(completedShift: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: OperatorShiftScreen()),
      ),
    );

    expect(find.byKey(const Key('start-shift-button')), findsNothing);
    expect(find.byKey(const Key('submit-shift-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('submit-shift-button')));
    await tester.pump();

    final action = notifier.action as SubmitShiftAction;
    expect(action.assetId, 10);
    expect(action.shiftId, 45);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operator sees assignment and starts shift with meter', (
    tester,
  ) async {
    final notifier = _Notifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: OperatorShiftScreen()),
      ),
    );

    expect(find.text('Смена оператора'), findsOneWidget);
    expect(find.text('Виброплита'), findsOneWidget);
    expect(find.text('Начать смену'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-shift-button')));
    await tester.pump();

    final action = notifier.action as StartShiftAction;
    expect(action.assignmentId, 20);
    expect(action.meterStart, 125.5);
  });

  testWidgets('operator asset header fits long text at larger scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const name = 'Экскаватор_гусеничный_северный_участок_корпус_17';
    const status = 'Ожидает подтверждения механика';
    final notifier = _Notifier(
      asset: const MachineryAssetModel(
        id: 10,
        assetCode: 'EXCAVATOR_VERY_LONG_ASSET_CODE_2026_001',
        name: name,
        status: 'assigned',
        statusLabel: status,
        availableActions: ['start_shift'],
        projectId: 30,
        projectName: 'ЖК Север',
        assignmentId: 20,
        meterHours: 125.5,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const OperatorShiftScreen(),
        ),
      ),
    );

    expect(find.text(name), findsOneWidget);
    expect(find.text(status), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed finish keeps every field for retry on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = _Notifier(activeShift: true)
      ..failedExecutionsRemaining = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith((ref) => notifier),
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
          home: const OperatorShiftScreen(),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('finish-shift-button')),
      180,
    );
    await tester.tap(find.byKey(const Key('finish-shift-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('finish-meter-field')),
      '142.75',
    );
    await tester.enterText(find.byKey(const Key('finish-hours-field')), '7.5');
    await tester.enterText(find.byKey(const Key('finish-fuel-field')), '12.25');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('С ограничениями').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('finish-inspection-notes-field')),
      'Небольшая утечка',
    );
    await tester.ensureVisible(find.byKey(const Key('finish-dialog-submit')));
    await tester.tap(find.byKey(const Key('finish-dialog-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Завершение смены'), findsOneWidget);
    expect(find.text('Проверьте данные смены.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('finish-meter-field')))
          .controller!
          .text,
      '142.75',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('finish-hours-field')))
          .controller!
          .text,
      '7.5',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('finish-fuel-field')))
          .controller!
          .text,
      '12.25',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('finish-inspection-notes-field')),
          )
          .controller!
          .text,
      'Небольшая утечка',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('finish-dialog-submit')));
    await tester.pumpAndSettle();

    expect(notifier.attemptedActions, hasLength(2));
    final action = notifier.action! as FinishShiftAction;
    expect(action.shiftId, 45);
    expect(action.meterEnd, 142.75);
    expect(action.actualHours, 7.5);
    expect(action.fuelConsumed, 12.25);
    expect(action.postShiftInspection, {
      'result': 'restricted',
      'notes': 'Небольшая утечка',
      'defects': const <Map<String, dynamic>>[],
    });
    expect(
      (notifier.attemptedActions.first as FinishShiftAction).payload,
      action.payload,
    );
    expect(find.text('Смена завершена'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending finish ignores a duplicate tap', (tester) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = _Notifier(activeShift: true)
      ..pendingExecution = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: OperatorShiftScreen()),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('finish-shift-button')),
      180,
    );
    await tester.tap(find.byKey(const Key('finish-shift-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-dialog-submit')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('finish-dialog-submit')),
      warnIfMissed: false,
    );
    await tester.pump();

    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(find.text('Завершение смены'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Завершение смены'), findsOneWidget);

    expect(notifier.attemptedActions, hasLength(1));
    notifier.pendingExecution!.complete();
    await tester.pumpAndSettle();
    expect(notifier.action, isA<FinishShiftAction>());
    expect(notifier.loadCalls, 1);
    expect(find.text('Завершение смены'), findsNothing);
    expect(find.text('Смена завершена'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling finish does not send an action', (tester) async {
    final notifier = _Notifier(activeShift: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineryOperationsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: OperatorShiftScreen()),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('finish-shift-button')),
      180,
    );
    await tester.tap(find.byKey(const Key('finish-shift-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(notifier.attemptedActions, isEmpty);
    expect(notifier.action, isNull);
    expect(tester.takeException(), isNull);
  });
}
