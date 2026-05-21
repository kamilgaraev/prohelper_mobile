import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_model.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_repository.dart';
import 'package:prohelpers_mobile/features/production_labor/domain/production_labor_provider.dart';
import 'package:prohelpers_mobile/features/production_labor/presentation/production_labor_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _RecordingProductionLaborRepository extends ProductionLaborRepository {
  _RecordingProductionLaborRepository() : super(Dio());

  double acceptedQuantity = 3;
  Map<String, dynamic>? outputPayload;
  Map<String, dynamic>? timesheetPayload;

  LaborWorkOrderModel get workOrder => LaborWorkOrderModel(
    id: 5,
    projectId: 9,
    title: 'Монтаж стен',
    orderNumber: 'PL-1',
    status: 'in_progress',
    statusLabel: 'В работе',
    availableActions: const ['submit'],
    assigneeName: 'Бригада 1',
    lines: [
      LaborWorkOrderLineModel(
        id: 7,
        workOrderId: 5,
        name: 'Стены',
        unit: 'м2',
        plannedQuantity: 10.5,
        acceptedQuantity: acceptedQuantity,
        remainingQuantity: 10.5 - acceptedQuantity,
        requiresSafetyPermit: false,
      ),
    ],
  );

  @override
  Future<List<LaborWorkOrderModel>> fetchWorkOrders({int? projectId}) async {
    return [workOrder];
  }

  @override
  Future<LaborOutputModel> recordOutput({
    required int workOrderLineId,
    required double quantity,
    required double hours,
    required String workDate,
    String? comment,
  }) async {
    outputPayload = {
      'work_order_line_id': workOrderLineId,
      'quantity': quantity,
      'hours': hours,
      'work_date': workDate,
      'comment': comment,
    };
    acceptedQuantity += quantity;

    return LaborOutputModel(
      id: 21,
      workOrderId: workOrder.id,
      workOrderLineId: workOrderLineId,
      workDate: workDate,
      quantity: quantity,
      hours: hours,
      statusLabel: 'Принято',
    );
  }

  @override
  Future<LaborTimesheetModel> createTimesheet({
    required int workOrderId,
    required int workOrderLineId,
    required double hours,
    required String shiftDate,
    required bool includeInPayroll,
    int? employeeId,
    String? workerName,
    String? safetyPermitReference,
  }) async {
    timesheetPayload = {
      'work_order_id': workOrderId,
      'work_order_line_id': workOrderLineId,
      'hours': hours,
      'shift_date': shiftDate,
      'include_in_payroll': includeInPayroll,
      'employee_id': employeeId,
      'worker_name': workerName,
      'safety_permit_reference': safetyPermitReference,
    };

    return LaborTimesheetModel(
      id: 31,
      workOrderId: workOrderId,
      shiftDate: shiftDate,
      statusLabel: 'Отправлен',
      totalHours: hours,
    );
  }
}

class _TestProductionLaborNotifier extends ProductionLaborNotifier {
  _TestProductionLaborNotifier(this.repository) : super(repository) {
    state = ProductionLaborState(
      isLoading: false,
      projectFilter: 9,
      workOrders: [repository.workOrder],
      error: null,
    );
  }

  final _RecordingProductionLaborRepository repository;

  @override
  Future<void> load() async {
    state = state.copyWith(
      isLoading: false,
      projectFilter: 9,
      workOrders: [repository.workOrder],
      error: null,
    );
  }
}

class _TestProjectsRepository extends ProjectsRepository {
  _TestProjectsRepository() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _TestProjectsNotifier extends ProjectsNotifier {
  _TestProjectsNotifier(Project project) : super(_TestProjectsRepository()) {
    state = ProjectsState(
      isLoading: false,
      projects: [project],
      selectedProject: project,
      error: null,
    );
  }
}

void main() {
  Project project() {
    return Project()
      ..serverId = 9
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildScreen(_RecordingProductionLaborRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        productionLaborProvider.overrideWith(
          (ref) => _TestProductionLaborNotifier(repository),
        ),
      ],
      child: const MaterialApp(home: ProductionLaborScreen()),
    );
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> submitSheet(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final saveButton = find.text('Сохранить');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await pumpUi(tester);
  }

  testWidgets('requires quantity before submitting production actual', (
    tester,
  ) async {
    final repository = _RecordingProductionLaborRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('Выработка'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '4');
    await submitSheet(tester);

    expect(find.text('Укажите выполненный объем.'), findsOneWidget);
    expect(repository.outputPayload, isNull);
  });

  testWidgets('requires hours before submitting production actual', (
    tester,
  ) async {
    final repository = _RecordingProductionLaborRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('Выработка'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await submitSheet(tester);

    expect(find.text('Укажите трудозатраты.'), findsOneWidget);
    expect(repository.outputPayload, isNull);
  });

  testWidgets('submits selected worker or brigade', (tester) async {
    final repository = _RecordingProductionLaborRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('Табель'));
    await pumpUi(tester);
    await tester.tap(find.byType(ActionChip));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '7,5');
    await submitSheet(tester);

    expect(repository.timesheetPayload?['worker_name'], 'Бригада 1');
    expect(repository.timesheetPayload?['include_in_payroll'], isFalse);
    expect(repository.timesheetPayload?['hours'], 7.5);
  });

  testWidgets('shows remaining quantity after submit', (tester) async {
    final repository = _RecordingProductionLaborRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    expect(find.text('Осталось 7.5 м2'), findsOneWidget);

    await tester.tap(find.text('Выработка'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.enterText(find.byType(TextFormField).at(1), '4');
    await submitSheet(tester);

    expect(repository.outputPayload?['quantity'], 2);
    expect(repository.outputPayload?['hours'], 4);
    expect(find.text('Осталось 5.5 м2'), findsOneWidget);
  });
}
