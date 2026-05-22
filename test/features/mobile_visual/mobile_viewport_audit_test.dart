import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/construction_journal/presentation/construction_journal_screen.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/presentation/handover_acceptance_screen.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/machinery_operations_screen.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:prohelpers_mobile/features/production_labor/presentation/production_labor_screen.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';
import 'package:prohelpers_mobile/features/quality_control/presentation/quality_control_screen.dart';
import 'package:prohelpers_mobile/features/safety/presentation/safety_screen.dart';
import 'package:prohelpers_mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_form_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_requests_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';
import 'package:prohelpers_mobile/features/workflow_management/presentation/workflow_management_screen.dart';
import 'package:prohelpers_mobile/features/workforce/presentation/workforce_attendance_screen.dart';

import '../../helpers/mobile_integration_test_helpers.dart';

void main() {
  final project = ProHelperTestData.project(
    name: 'Жилой комплекс с длинным названием',
  );

  final screens = <_ViewportAuditScreen>[
    _ViewportAuditScreen('project selection', const ProjectSelectionScreen()),
    _ViewportAuditScreen('dashboard', const DashboardScreen()),
    _ViewportAuditScreen('notifications', const NotificationsScreen()),
    _ViewportAuditScreen('site requests', const SiteRequestsScreen()),
    _ViewportAuditScreen('site request form', const SiteRequestFormScreen()),
    _ViewportAuditScreen('warehouse', const WarehouseScreen()),
    _ViewportAuditScreen('schedule', const ScheduleScreen()),
    _ViewportAuditScreen(
      'construction journal',
      const ConstructionJournalScreen(),
    ),
    _ViewportAuditScreen('quality control', const QualityControlScreen()),
    _ViewportAuditScreen('safety', const SafetyScreen()),
    _ViewportAuditScreen(
      'machinery operations',
      const MachineryOperationsScreen(),
    ),
    _ViewportAuditScreen('production labor', const ProductionLaborScreen()),
    _ViewportAuditScreen('workforce', const WorkforceAttendanceScreen()),
    _ViewportAuditScreen(
      'handover acceptance',
      const HandoverAcceptanceScreen(),
    ),
    _ViewportAuditScreen(
      'workflow management',
      const WorkflowManagementScreen(),
    ),
  ];

  const viewportSizes = <Size>[
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
  ];

  for (final viewportSize in viewportSizes) {
    testWidgets('major mobile screens render without viewport errors at '
        '${viewportSize.width.toInt()}x${viewportSize.height.toInt()}', (
      tester,
    ) async {
      for (final screen in screens) {
        await pumpProHelperWidget(
          tester,
          screen.widget,
          surfaceSize: viewportSize,
          overrides: proHelperCoreOverrides(selectedProject: project),
        );
        await _pumpStableFrames(tester);
        _expectNoFlutterException(tester, screen, viewportSize);
      }
    });
  }
}

Future<void> _pumpStableFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _expectNoFlutterException(
  WidgetTester tester,
  _ViewportAuditScreen screen,
  Size viewportSize,
) {
  final exception = tester.takeException();
  if (exception is FlutterError) {
    debugPrint(exception.toStringDeep());
  }

  expect(
    exception,
    isNull,
    reason:
        '${screen.name} produced a Flutter error at '
        '${viewportSize.width.toInt()}x${viewportSize.height.toInt()}',
  );
}

class _ViewportAuditScreen {
  const _ViewportAuditScreen(this.name, this.widget);

  final String name;
  final Widget widget;
}
