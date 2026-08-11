import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_model.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_action.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_operations_provider.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/operator/operator_shift_screen.dart';

class _Repository extends MachineryOperationsRepository {
  _Repository() : super(Dio());
}

class _Notifier extends MachineryOperationsNotifier {
  _Notifier() : super(_Repository()) {
    state = const MachineryOperationsState(
      assets: [
        MachineryAssetModel(
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
    );
  }

  MachineryAction? action;

  @override
  Future<void> execute(MachineryAction action) async {
    this.action = action;
  }

  @override
  Future<void> load() async {}
}

void main() {
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
}
