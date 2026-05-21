import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_model.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_operations_provider.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/machinery_operations_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

class _RecordingMachineryOperationsRepository
    extends MachineryOperationsRepository {
  _RecordingMachineryOperationsRepository() : super(Dio());

  final asset = const MachineryAssetModel(
    id: 10,
    assetCode: 'EX-10',
    name: 'Экскаватор',
    status: 'in_operation',
    statusLabel: 'В работе',
    availableActions: ['return_available'],
    projectId: 7,
  );

  Map<String, dynamic>? shiftPayload;
  Map<String, dynamic>? fuelPayload;
  Map<String, dynamic>? downtimePayload;
  Map<String, dynamic>? productionPayload;

  @override
  Future<List<MachineryAssetModel>> fetchAssets({int? projectId}) async {
    return [asset];
  }

  @override
  Future<List<MachineryShiftReportModel>> fetchShiftReports({
    int? projectId,
  }) async {
    return const [];
  }

  @override
  Future<MachineryShiftReportModel> createShiftReport({
    required int assetId,
    required int projectId,
    required String reportDate,
    double? plannedHours,
    required double actualHours,
    required double fuelConsumed,
    String? workDescription,
  }) async {
    shiftPayload = {
      'asset_id': assetId,
      'project_id': projectId,
      'report_date': reportDate,
      'planned_hours': plannedHours,
      'actual_hours': actualHours,
      'fuel_consumed': fuelConsumed,
      'work_description': workDescription,
    };

    return MachineryShiftReportModel(
      id: 100,
      assetId: assetId,
      projectId: projectId,
      reportDate: reportDate,
      status: 'draft',
      statusLabel: 'Черновик',
      actualHours: actualHours,
      fuelConsumed: fuelConsumed,
      availableActions: const ['submit'],
      assetName: asset.name,
    );
  }

  @override
  Future<void> createFuelIssue({
    required int assetId,
    required int projectId,
    required String issuedAt,
    required String fuelType,
    required double quantity,
    required String unit,
    String? comment,
  }) async {
    fuelPayload = {
      'asset_id': assetId,
      'project_id': projectId,
      'issued_at': issuedAt,
      'fuel_type': fuelType,
      'quantity': quantity,
      'unit': unit,
      'comment': comment,
    };
  }

  @override
  Future<void> createDowntime({
    required int assetId,
    required int projectId,
    int? shiftReportId,
    required String reason,
    required String startedAt,
    required int durationMinutes,
    String? comment,
  }) async {
    downtimePayload = {
      'asset_id': assetId,
      'project_id': projectId,
      'shift_report_id': shiftReportId,
      'reason': reason,
      'started_at': startedAt,
      'duration_minutes': durationMinutes,
      'comment': comment,
    };
  }

  @override
  Future<void> createProductionRecord({
    required int assetId,
    required int projectId,
    int? shiftReportId,
    required String recordedAt,
    required double quantity,
    required String unit,
    String? comment,
  }) async {
    productionPayload = {
      'asset_id': assetId,
      'project_id': projectId,
      'shift_report_id': shiftReportId,
      'recorded_at': recordedAt,
      'quantity': quantity,
      'unit': unit,
      'comment': comment,
    };
  }
}

class _TestMachineryOperationsNotifier extends MachineryOperationsNotifier {
  _TestMachineryOperationsNotifier(this.repository) : super(repository) {
    state = MachineryOperationsState(
      isLoading: false,
      projectFilter: 7,
      assets: [repository.asset],
      shiftReports: const [],
    );
  }

  final _RecordingMachineryOperationsRepository repository;

  @override
  Future<void> load() async {
    state = state.copyWith(
      isLoading: false,
      projectFilter: 7,
      assets: [repository.asset],
      shiftReports: const [],
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
      ..serverId = 7
      ..name = 'Башня'
      ..address = 'Площадка 1';
  }

  Widget buildScreen(_RecordingMachineryOperationsRepository repository) {
    return ProviderScope(
      overrides: [
        projectsProvider.overrideWith(
          (ref) => _TestProjectsNotifier(project()),
        ),
        machineryOperationsProvider.overrideWith(
          (ref) => _TestMachineryOperationsNotifier(repository),
        ),
      ],
      child: const MaterialApp(home: MachineryOperationsScreen()),
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

  testWidgets('does not submit shift finish without actual hours', (
    tester,
  ) async {
    final repository = _RecordingMachineryOperationsRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('Рапорт'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '12');
    await submitSheet(tester);

    expect(find.text('Укажите фактические часы.'), findsOneWidget);
    expect(repository.shiftPayload, isNull);
  });

  testWidgets('submits user-entered fuel value', (tester) async {
    final repository = _RecordingMachineryOperationsRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('ГСМ').last);
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Дизель');
    await tester.enterText(find.byType(TextFormField).at(1), '73,5');
    await tester.enterText(find.byType(TextFormField).at(2), 'л');
    await submitSheet(tester);

    expect(repository.fuelPayload?['quantity'], 73.5);
    expect(repository.fuelPayload?['fuel_type'], 'Дизель');
    expect(repository.fuelPayload?['unit'], 'л');
  });

  testWidgets('submits downtime with reason and duration', (tester) async {
    final repository = _RecordingMachineryOperationsRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('Простой'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ожидание фронта');
    await tester.enterText(find.byType(TextFormField).at(1), '45');
    await submitSheet(tester);

    expect(repository.downtimePayload?['reason'], 'Ожидание фронта');
    expect(repository.downtimePayload?['duration_minutes'], 45);
  });

  testWidgets('submits production quantity entered by user', (tester) async {
    final repository = _RecordingMachineryOperationsRepository();

    await tester.pumpWidget(buildScreen(repository));
    await pumpUi(tester);
    await tester.tap(find.text('Выработка'));
    await pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '128.25');
    await tester.enterText(find.byType(TextFormField).at(1), 'м3');
    await submitSheet(tester);

    expect(repository.productionPayload?['quantity'], 128.25);
    expect(repository.productionPayload?['unit'], 'м3');
  });
}
