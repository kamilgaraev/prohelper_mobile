import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_models.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_model.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/domain/handover_acceptance_provider.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_model.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';
import 'package:prohelpers_mobile/features/machinery_operations/domain/machinery_operations_provider.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_model.dart';
import 'package:prohelpers_mobile/features/production_labor/data/production_labor_repository.dart';
import 'package:prohelpers_mobile/features/production_labor/domain/production_labor_provider.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';
import 'package:prohelpers_mobile/features/quality_control/domain/quality_control_provider.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_model.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';
import 'package:prohelpers_mobile/features/safety/domain/safety_provider.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_model.dart';
import 'package:prohelpers_mobile/features/schedule/data/schedule_repository.dart';
import 'package:prohelpers_mobile/features/schedule/domain/schedule_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_attendance_model.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';
import 'package:prohelpers_mobile/features/workforce/domain/workforce_attendance_provider.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureProHelperIntegrationTestEnvironment();

  testWidgets('creates a site request through mobile repository contract', (
    tester,
  ) async {
    final repository = _FieldSiteRequestsRepository();
    final request = await repository.createSiteRequest({
      'title': 'Concrete delivery',
      'request_type': 'material_request',
      'priority': 'medium',
      'project_id': 15,
    });

    expect(repository.createdPayloads.single['project_id'], 15);
    expect(request.title, 'Concrete delivery');
  });

  testWidgets('receives a warehouse project material delivery', (tester) async {
    final repository = _FieldWarehouseRepository();

    final delivery = await repository.receiveProjectMaterialDelivery(
      deliveryId: 10,
      quantity: 6,
      notes: 'Accepted on site',
    );

    expect(repository.receivedDeliveryId, 10);
    expect(repository.receivedQuantity, 6);
    expect(delivery.status, 'accepted');
  });

  testWidgets('records daily plan fact and submits plan', (tester) async {
    final repository = _FieldScheduleRepository();
    final notifier = DailyWorkPlansNotifier(repository);

    await notifier.load(projectId: 15);
    final plan = notifier.state.plans.single;
    final assignment = plan.assignments.single;

    await notifier.recordFact(
      assignment,
      const DailyWorkFactInput(
        status: 'done',
        completedQuantity: 10,
        actualWorkHours: 8,
        factComment: 'Done',
      ),
    );
    await notifier.submit(notifier.state.plans.single);

    expect(repository.recordedAssignmentId, assignment.id);
    expect(repository.recordedFactPayload?['completed_quantity'], 10);
    expect(notifier.state.plans.single.status, 'submitted');
  });

  testWidgets('creates a construction journal entry', (tester) async {
    final repository = _FieldConstructionJournalRepository();

    final entry = await repository.createEntry(
      journalId: 31,
      entryDate: '2026-05-22',
      workDescription: 'Concrete works',
      workVolumes: const [],
      materials: const [],
    );

    expect(repository.createdJournalId, 31);
    expect(entry.workDescription, 'Concrete works');
  });

  testWidgets('creates quality defect and refreshes defect list', (
    tester,
  ) async {
    final notifier = QualityControlNotifier(_FieldQualityControlRepository());

    notifier.syncProject(15);
    await notifier.createDefect({
      'project_id': 15,
      'title': 'Damaged coating',
      'severity': 'critical',
    });

    expect(notifier.state.defects.single.title, 'Damaged coating');
    expect(notifier.state.projectFilter, 15);
  });

  testWidgets('creates safety incident and refreshes incident list', (
    tester,
  ) async {
    final notifier = SafetyNotifier(_FieldSafetyRepository());

    notifier.syncProject(15);
    await notifier.createIncident({
      'project_id': 15,
      'title': 'Unsafe condition',
      'severity': 'high',
    });

    expect(notifier.state.incidents.single.title, 'Unsafe condition');
    expect(notifier.state.projectFilter, 15);
  });

  testWidgets('records machinery shift actual values', (tester) async {
    final notifier = MachineryOperationsNotifier(
      _FieldMachineryOperationsRepository(),
    );

    notifier.syncProject(15);
    await notifier.load();
    await notifier.createShiftReport(
      notifier.state.assets.single,
      reportDate: DateTime(2026, 5, 22),
      actualHours: 7.5,
      fuelConsumed: 42,
      workDescription: 'Excavation',
    );

    expect(notifier.state.shiftReports.single.actualHours, 7.5);
    expect(notifier.state.shiftReports.single.fuelConsumed, 42);
  });

  testWidgets('submits production labor actual output', (tester) async {
    final notifier = ProductionLaborNotifier(_FieldProductionLaborRepository());

    notifier.syncProject(15);
    await notifier.load();
    final order = notifier.state.workOrders.single;
    final line = order.lines.single;

    await notifier.recordOutput(
      order,
      line,
      workDate: DateTime(2026, 5, 22),
      quantity: 4,
      hours: 8,
      comment: 'Accepted volume',
    );

    expect(notifier.state.workOrders.single.lines.single.acceptedQuantity, 4);
  });

  testWidgets('scans workforce QR and stores confirmed attendance', (
    tester,
  ) async {
    final notifier = WorkforceAttendanceNotifier(_FieldWorkforceRepository());

    await notifier.scanQr('signed-attendance-token');

    expect(notifier.state.scanResult?.scanEventId, 91);
    expect(notifier.state.scanResult?.source, 'qr_scan');
  });

  testWidgets('accepts handover checklist item and reloads scope detail', (
    tester,
  ) async {
    final notifier = HandoverAcceptanceNotifier(
      _FieldHandoverAcceptanceRepository(),
    );

    notifier.syncProject(15);
    await notifier.loadScopes();
    await notifier.loadScopeDetail(10);
    await notifier.reviewChecklistItem(13, status: 'accepted');

    final item = notifier.state.selectedScope!.checklists.single.items.single;
    expect(item.status, 'accepted');
  });
}

class _FieldSiteRequestsRepository extends SiteRequestsRepository {
  _FieldSiteRequestsRepository() : super(Dio());

  final createdPayloads = <Map<String, dynamic>>[];

  @override
  Future<SiteRequestModel> createSiteRequest(Map<String, dynamic> data) async {
    createdPayloads.add(Map<String, dynamic>.from(data));
    return ProHelperTestData.siteRequest(
      id: 1001,
      title: data['title']?.toString() ?? 'Site request',
    );
  }
}

class _FieldWarehouseRepository extends WarehouseRepository {
  _FieldWarehouseRepository() : super(Dio());

  int? receivedDeliveryId;
  double? receivedQuantity;

  @override
  Future<ProjectMaterialDeliveryModel> receiveProjectMaterialDelivery({
    required int deliveryId,
    required double quantity,
    String? notes,
  }) async {
    receivedDeliveryId = deliveryId;
    receivedQuantity = quantity;
    return _delivery(status: 'accepted', acceptedQuantity: quantity);
  }
}

class _FieldScheduleRepository extends ScheduleRepository {
  _FieldScheduleRepository() : super(Dio());

  int? recordedAssignmentId;
  Map<String, dynamic>? recordedFactPayload;

  @override
  Future<List<DailyWorkPlanModel>> fetchDailyWorkPlans({
    required int projectId,
  }) async {
    return [_dailyPlan()];
  }

  @override
  Future<DailyWorkPlanAssignmentModel> recordDailyWorkFact({
    required int assignmentId,
    required DailyWorkFactInput input,
  }) async {
    recordedAssignmentId = assignmentId;
    recordedFactPayload = input.toJson();
    return _assignment(
      status: input.status,
      completedQuantity: input.completedQuantity,
      actualWorkHours: input.actualWorkHours,
      factComment: input.factComment,
    );
  }

  @override
  Future<DailyWorkPlanModel> submitDailyWorkPlan({
    required int dailyPlanId,
    String? summaryComment,
  }) async {
    return _dailyPlan(status: 'submitted', statusLabel: 'Submitted');
  }
}

class _FieldConstructionJournalRepository
    extends ConstructionJournalRepository {
  _FieldConstructionJournalRepository() : super(Dio());

  int? createdJournalId;

  @override
  Future<ConstructionJournalEntryModel> createEntry({
    required int journalId,
    required String entryDate,
    required String workDescription,
    int? scheduleTaskId,
    int? estimateId,
    String? problemsDescription,
    String? safetyNotes,
    String? visitorsNotes,
    String? qualityNotes,
    List<ConstructionJournalWorkVolumeModel> workVolumes = const [],
    List<ConstructionJournalMaterialUsageModel> materials = const [],
  }) async {
    createdJournalId = journalId;
    return _journalEntry(
      journalId: journalId,
      entryDate: entryDate,
      workDescription: workDescription,
    );
  }
}

class _FieldQualityControlRepository extends QualityControlRepository {
  _FieldQualityControlRepository() : super(Dio());

  final defects = <QualityDefectModel>[];

  @override
  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async {
    return defects;
  }

  @override
  Future<QualityDefectModel> createDefect(
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    final defect = _qualityDefect(
      title: data['title']?.toString() ?? 'Quality defect',
      severity: data['severity']?.toString() ?? 'critical',
    );
    defects.add(defect);
    return defect;
  }
}

class _FieldSafetyRepository extends SafetyRepository {
  _FieldSafetyRepository() : super(Dio());

  final incidents = <SafetyIncidentModel>[];

  @override
  Future<List<SafetyWorkPermitModel>> fetchPermits({
    int? projectId,
    String? status,
  }) async {
    return const [];
  }

  @override
  Future<List<SafetyIncidentModel>> fetchIncidents({
    int? projectId,
    String? status,
  }) async {
    return incidents;
  }

  @override
  Future<List<SafetyViolationModel>> fetchViolations({
    int? projectId,
    String? status,
  }) async {
    return const [];
  }

  @override
  Future<SafetyIncidentModel> createIncident(Map<String, dynamic> data) async {
    final incident = _safetyIncident(
      title: data['title']?.toString() ?? 'Safety incident',
      severity: data['severity']?.toString() ?? 'high',
    );
    incidents.add(incident);
    return incident;
  }
}

class _FieldMachineryOperationsRepository
    extends MachineryOperationsRepository {
  _FieldMachineryOperationsRepository() : super(Dio());

  final shiftReports = <MachineryShiftReportModel>[];

  @override
  Future<List<MachineryAssetModel>> fetchAssets({int? projectId}) async {
    return [_machineryAsset()];
  }

  @override
  Future<List<MachineryShiftReportModel>> fetchShiftReports({
    int? projectId,
  }) async {
    return shiftReports;
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
    final report = _machineryShiftReport(
      actualHours: actualHours,
      fuelConsumed: fuelConsumed,
    );
    shiftReports.add(report);
    return report;
  }
}

class _FieldProductionLaborRepository extends ProductionLaborRepository {
  _FieldProductionLaborRepository() : super(Dio());

  double acceptedQuantity = 0;

  @override
  Future<List<LaborWorkOrderModel>> fetchWorkOrders({int? projectId}) async {
    return [_laborWorkOrder(acceptedQuantity: acceptedQuantity)];
  }

  @override
  Future<LaborOutputModel> recordOutput({
    required int workOrderLineId,
    required double quantity,
    required double hours,
    required String workDate,
    String? comment,
  }) async {
    acceptedQuantity = quantity;
    return LaborOutputModel.fromJson({
      'id': 21,
      'work_order_id': 5,
      'work_order_line_id': workOrderLineId,
      'output_date': workDate,
      'quantity': quantity,
      'hours': hours,
      'status_label': 'Accepted',
    });
  }
}

class _FieldWorkforceRepository extends WorkforceRepository {
  _FieldWorkforceRepository() : super(Dio());

  @override
  Future<AttendanceScanResultModel> scanAttendanceQr({
    required String qrToken,
    String? deviceId,
  }) async {
    return AttendanceScanResultModel.fromJson(const {
      'scan_event_id': 91,
      'employee_id': 41,
      'employee_label': 'Ivan Foreman',
      'project_id': 15,
      'project_label': 'Tower A',
      'work_date': '2026-05-22',
      'status': 'at_work',
      'status_label': 'Confirmed',
      'source': 'qr_scan',
      'source_label': 'QR scan',
      'confirmed_at': '2026-05-22T10:00:00+03:00',
    });
  }
}

class _FieldHandoverAcceptanceRepository extends HandoverAcceptanceRepository {
  _FieldHandoverAcceptanceRepository() : super(Dio());

  bool accepted = false;

  @override
  Future<List<AcceptanceScopeModel>> fetchScopes({
    int? projectId,
    String? status,
    String? plannedFrom,
    String? plannedTo,
  }) async {
    return [_acceptanceScope(accepted: accepted)];
  }

  @override
  Future<AcceptanceScopeModel> fetchScope(int scopeId) async {
    return _acceptanceScope(accepted: accepted);
  }

  @override
  Future<AcceptanceChecklistModel> reviewChecklistItem(
    int itemId, {
    required String status,
    String? comment,
  }) async {
    accepted = status == 'accepted';
    return _acceptanceScope(accepted: accepted).checklists.single;
  }
}

ProjectMaterialDeliveryModel _delivery({
  String status = 'in_transit',
  double acceptedQuantity = 2,
}) {
  return ProjectMaterialDeliveryModel.fromJson({
    'id': 10,
    'source_type': 'purchase_order',
    'status': status,
    'status_label': status == 'accepted' ? 'Accepted' : 'In transit',
    'requested_quantity': 12,
    'reserved_quantity': 10,
    'shipped_quantity': 8,
    'accepted_quantity': acceptedQuantity,
    'used_quantity': 0,
    'available_quantity': acceptedQuantity,
    'remaining_to_ship': 4,
    'remaining_to_accept': 12 - acceptedQuantity,
    'can_receive': status != 'accepted',
    'project': {'id': 15, 'name': 'Tower A'},
    'material': {
      'id': 42,
      'name': 'Concrete M300',
      'measurement_unit': {'short_name': 'm3'},
    },
    'warehouse': {'id': 3, 'name': 'Main warehouse'},
    'linked_entities': const {},
    'events': const [],
  });
}

DailyWorkPlanModel _dailyPlan({
  String status = 'published',
  String statusLabel = 'Published',
}) {
  return DailyWorkPlanModel.fromJson({
    'id': 41,
    'project_id': 15,
    'schedule_id': 5,
    'schedule_name': 'Tower schedule',
    'lookahead_plan_id': 9,
    'work_date': '2026-05-22',
    'status': status,
    'status_label': statusLabel,
    'available_actions': const [
      {'action': 'record_fact', 'label': 'Record fact'},
      {'action': 'submit', 'label': 'Submit'},
    ],
    'assignments': [_assignmentPayload()],
  });
}

DailyWorkPlanAssignmentModel _assignment({
  String status = 'planned',
  double? completedQuantity,
  double? actualWorkHours,
  String? factComment,
}) {
  return DailyWorkPlanAssignmentModel.fromJson(
    _assignmentPayload(
      status: status,
      completedQuantity: completedQuantity,
      actualWorkHours: actualWorkHours,
      factComment: factComment,
    ),
  );
}

Map<String, dynamic> _assignmentPayload({
  String status = 'planned',
  double? completedQuantity,
  double? actualWorkHours,
  String? factComment,
}) {
  return {
    'id': 51,
    'daily_work_plan_id': 41,
    'lookahead_plan_task_id': 17,
    'schedule_task_id': 7,
    'journal_entry_id': null,
    'status': status,
    'status_label': status == 'done' ? 'Done' : 'Planned',
    'planned_quantity': '10',
    'completed_quantity': completedQuantity,
    'planned_work_hours': '8',
    'actual_work_hours': actualWorkHours,
    'fact_comment': factComment,
    'fact_status_options': const [
      {'status': 'done', 'label': 'Done'},
      {'status': 'partially_done', 'label': 'Partially done'},
      {'status': 'not_done', 'label': 'Not done'},
    ],
    'schedule_task': const {'id': 7, 'name': 'Foundation reinforcement'},
    'linked_blocking_entities': const [],
    'constraints': const [],
  };
}

ConstructionJournalEntryModel _journalEntry({
  required int journalId,
  required String entryDate,
  required String workDescription,
}) {
  return ConstructionJournalEntryModel.fromJson({
    'id': 71,
    'journal_id': journalId,
    'entry_date': entryDate,
    'entry_number': 1,
    'work_description': workDescription,
    'status': 'draft',
    'status_label': 'Draft',
    'workflow_state': 'ready',
    'workVolumes': const [],
    'blockers': const [],
    'available_actions': const [
      {'action': 'submit', 'label': 'Submit'},
    ],
  });
}

QualityDefectModel _qualityDefect({
  required String title,
  required String severity,
}) {
  return QualityDefectModel.fromJson({
    'id': 7,
    'project_id': 15,
    'defect_number': 'QD-202605-0007',
    'title': title,
    'severity': severity,
    'status': 'open',
    'inspection_required': true,
    'location_name': 'Section A',
    'project': const {'id': 15, 'name': 'Tower A'},
    'workflow_summary': const {
      'status': 'open',
      'available_actions': ['start'],
      'problem_flags': [],
      'meta': {'overdue': false},
    },
    'photos': const [],
    'status_history': const [],
    'problem_flags': const [],
    'available_actions': const ['start'],
  });
}

SafetyIncidentModel _safetyIncident({
  required String title,
  required String severity,
}) {
  return SafetyIncidentModel.fromJson({
    'id': 20,
    'project_id': 15,
    'incident_number': 'INC-15-001',
    'title': title,
    'incident_type': 'unsafe_condition',
    'severity': severity,
    'status': 'reported',
    'status_label': 'Reported',
    'occurred_at': '2026-05-22T10:00:00Z',
    'immediate_actions': 'Area isolated',
    'problem_flags': const [],
  });
}

MachineryAssetModel _machineryAsset() {
  return MachineryAssetModel.fromJson({
    'id': 7,
    'asset_code': 'EXC-001',
    'name': 'Excavator',
    'status': 'assigned',
    'status_label': 'Assigned',
    'available_actions': const ['start_operation'],
    'project_id': 15,
    'project': const {'id': 15, 'name': 'Tower A'},
    'problem_flags': const [],
  });
}

MachineryShiftReportModel _machineryShiftReport({
  required double actualHours,
  required double fuelConsumed,
}) {
  return MachineryShiftReportModel.fromJson({
    'id': 11,
    'asset_id': 7,
    'project_id': 15,
    'report_date': '2026-05-22',
    'status': 'submitted',
    'status_label': 'Submitted',
    'actual_hours': actualHours,
    'fuel_consumed': fuelConsumed,
    'available_actions': const ['approve'],
    'asset': const {'id': 7, 'name': 'Excavator'},
  });
}

LaborWorkOrderModel _laborWorkOrder({required double acceptedQuantity}) {
  return LaborWorkOrderModel.fromJson({
    'id': 5,
    'project_id': 15,
    'order_number': 'PL-1',
    'title': 'Installation',
    'status': 'issued',
    'status_label': 'Issued',
    'available_actions': const ['start', 'submit'],
    'assignee_name': 'Crew 1',
    'lines': [
      {
        'id': 7,
        'work_order_id': 5,
        'name': 'Walls',
        'unit': 'm2',
        'planned_quantity': '10',
        'accepted_quantity': acceptedQuantity,
        'remaining_quantity': 10 - acceptedQuantity,
        'requires_safety_permit': true,
      },
    ],
    'problem_flags': const [],
  });
}

AcceptanceScopeModel _acceptanceScope({required bool accepted}) {
  return AcceptanceScopeModel.fromJson({
    'id': 10,
    'project_id': 15,
    'title': 'Section A',
    'description': 'Clean area handover',
    'status': accepted ? 'accepted' : 'in_progress',
    'project': const {'id': 15, 'name': 'Tower A'},
    'workflow_summary': {
      'status': accepted ? 'accepted' : 'in_progress',
      'available_actions': const ['accept'],
      'problem_flags': const [],
    },
    'checklists': [
      {
        'id': 12,
        'acceptance_scope_id': 10,
        'title': 'Apartment checklist',
        'status': accepted ? 'completed' : 'active',
        'items': [
          {
            'id': 13,
            'title': 'Windows checked',
            'is_required': true,
            'status': accepted ? 'accepted' : 'pending',
            'available_actions': accepted ? const [] : const ['accept'],
          },
        ],
      },
    ],
    'sessions': const [],
    'findings': const [],
    'handover_package': const {
      'id': 40,
      'title': 'Package',
      'status': 'draft',
      'documents': [],
    },
  });
}
