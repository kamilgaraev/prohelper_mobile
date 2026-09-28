import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_model.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_repository.dart';
import 'package:prohelpers_mobile/features/production_labor/domain/production_labor_provider.dart';
import 'package:prohelpers_mobile/features/production_labor/presentation/production_labor_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _RecordingProductionLaborRepository extends ProductionLaborRepository {
  _RecordingProductionLaborRepository({this.outputError}) : super(Dio());

  Object? outputError;
  String workOrderTitle = 'Монтаж стен';
  String workOrderStatus = 'В работе';
  double acceptedQuantity = 3;
  Map<String, dynamic>? outputPayload;
  Map<String, dynamic>? timesheetPayload;
  int outputCallCount = 0;
  final List<String> outputIdempotencyKeys = [];

  LaborWorkOrderModel get workOrder => LaborWorkOrderModel(
    id: 5,
    projectId: 9,
    title: workOrderTitle,
    orderNumber: 'PL-1',
    status: 'in_progress',
    statusLabel: workOrderStatus,
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
    required String idempotencyKey,
    String? comment,
  }) async {
    outputCallCount++;
    outputIdempotencyKeys.add(idempotencyKey);
    final error = outputError;
    if (error != null) throw error;

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

  Widget buildScreen(
    _RecordingProductionLaborRepository repository, {
    double textScale = 1,
  }) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        productionLaborProvider.overrideWith(
          (ref) => _TestProductionLaborNotifier(repository),
        ),
      ],
      child: MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: const ProductionLaborScreen(),
      ),
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

  testWidgets('work order header fits long text on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository =
        _RecordingProductionLaborRepository()
          ..workOrderTitle = 'Монтаж_плиты_перекрытия_секции_А_северный_корпус'
          ..workOrderStatus = 'Ожидает подтверждения прораба';

    await tester.pumpWidget(buildScreen(repository, textScale: 1.3));
    await pumpUi(tester);

    expect(find.text(repository.workOrderTitle), findsOneWidget);
    expect(find.text(repository.workOrderStatus), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows remaining production quantity below one tenth', (
    tester,
  ) async {
    final repository =
        _RecordingProductionLaborRepository()..acceptedQuantity = 10.4999;

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);

    expect(find.text('Осталось 0.0001 м2'), findsOneWidget);
    expect(find.textContaining('Принято 10.4999 из 10.5 м2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets(
    'closes output form and shows review after ambiguous queue result',
    (tester) async {
      final repository = _RecordingProductionLaborRepository(
        outputError: const SyncQueuedException(
          queueId: 12,
          requiresReview: true,
        ),
      );

      await tester.pumpWidget(buildScreen(repository));
      await pumpUi(tester);
      await tester.tap(find.text('Выработка'));
      await pumpUi(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '2');
      await tester.enterText(find.byType(TextFormField).at(1), '4');
      await submitSheet(tester);

      expect(repository.outputCallCount, 1);
      expect(repository.outputIdempotencyKeys, hasLength(1));
      expect(find.text('Факт выработки'), findsNothing);
      expect(find.text(SyncQueueMessages.unknownOutcome), findsOneWidget);
      expect(find.text('Выработка'), findsOneWidget);
    },
  );

  testWidgets(
    'reuses the output key for a retry and rotates it for a new fact',
    (tester) async {
      final repository = _RecordingProductionLaborRepository(
        outputError: const ApiException('Повторите попытку.'),
      );

      await tester.pumpWidget(buildScreen(repository));
      await pumpUi(tester);
      await tester.tap(find.text('Выработка'));
      await pumpUi(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '2');
      await tester.enterText(find.byType(TextFormField).at(1), '4');
      await submitSheet(tester);

      expect(find.text('Факт выработки'), findsOneWidget);
      expect(repository.outputIdempotencyKeys, hasLength(1));
      await tester.tap(find.byTooltip('Закрыть сообщение'));
      await tester.pump();

      repository.outputError = null;
      await submitSheet(tester);
      expect(repository.outputIdempotencyKeys, hasLength(2));
      expect(
        repository.outputIdempotencyKeys[1],
        repository.outputIdempotencyKeys[0],
      );

      await tester.tap(find.text('Выработка'));
      await pumpUi(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '1');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await submitSheet(tester);

      expect(repository.outputIdempotencyKeys, hasLength(3));
      expect(
        repository.outputIdempotencyKeys[2],
        isNot(repository.outputIdempotencyKeys[0]),
      );
    },
  );
}
