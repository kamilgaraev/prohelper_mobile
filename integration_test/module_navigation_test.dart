import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prohelpers_mobile/features/ai_assistant/presentation/ai_assistant_home_screen.dart';
import 'package:prohelpers_mobile/features/brigades/presentation/brigades_screen.dart';
import 'package:prohelpers_mobile/features/budget_estimates/presentation/budget_estimates_screen.dart';
import 'package:prohelpers_mobile/features/catalog_management/presentation/catalog_management_screen.dart';
import 'package:prohelpers_mobile/features/change_management/presentation/change_management_screen.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/construction_journal_screen.dart';
import 'package:prohelpers_mobile/features/contract_management/presentation/contract_management_screen.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:prohelpers_mobile/features/executive_documentation/presentation/executive_documentation_screen.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/machinery_operations_screen.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_screen.dart';
import 'package:prohelpers_mobile/features/production_labor/presentation/production_labor_screen.dart';
import 'package:prohelpers_mobile/features/project_management/presentation/project_management_screen.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';
import 'package:prohelpers_mobile/features/safety/presentation/safety_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';
import 'package:prohelpers_mobile/features/time_tracking/presentation/time_tracking_screen.dart';
import 'package:prohelpers_mobile/features/video_monitoring/presentation/video_monitoring_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';
import 'package:prohelpers_mobile/features/workflow_management/presentation/workflow_management_screen.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/workforce_attendance_screen.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureProHelperIntegrationTestEnvironment();

  testWidgets('dashboard cards open every active mobile module', (
    tester,
  ) async {
    await pumpProHelperWidget(
      tester,
      const DashboardScreen(),
      overrides: proHelperCoreOverrides(
        selectedProject: ProHelperTestData.project(),
      ),
    );

    expect(find.byType(DashboardScreen), findsOneWidget);

    for (final entry in _navigationTargets.entries) {
      await _openDashboardModule(tester, entry.key, entry.value);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.byType(DashboardScreen), findsOneWidget);
    }
  });
}

const _navigationTargets = <String, Type>{
  'project_selection': ProjectSelectionScreen,
  'site_requests': SiteRequestsScreen,
  'site_request_approvals': SiteRequestsScreen,
  'warehouse': WarehouseScreen,
  'schedule': ScheduleScreen,
  'ai_assistant': AiAssistantHomeScreen,
  'construction_journal': ConstructionJournalScreen,
  'quality-control': QualityControlScreen,
  'safety-management': SafetyScreen,
  'machinery-operations': MachineryOperationsScreen,
  'production-labor': ProductionLaborScreen,
  'workforce-management': WorkforceAttendanceScreen,
  'handover-acceptance': HandoverAcceptanceScreen,
  'workflow-management': WorkflowManagementScreen,
  'time-tracking': TimeTrackingScreen,
  'budget-estimates': BudgetEstimatesScreen,
  'procurement': ProcurementScreen,
  'contract-management': ContractManagementScreen,
  'change-management': ChangeManagementScreen,
  'executive-documentation': ExecutiveDocumentationScreen,
  'project-management': ProjectManagementScreen,
  'catalog-management': CatalogManagementScreen,
  'brigades': BrigadesScreen,
  'video-monitoring': VideoMonitoringScreen,
};

Future<void> _openDashboardModule(
  WidgetTester tester,
  String route,
  Type targetType,
) async {
  final finder = find.text('Module $route');

  await tester.scrollUntilVisible(
    finder,
    320,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();

  expect(find.byType(targetType), findsOneWidget);
}
