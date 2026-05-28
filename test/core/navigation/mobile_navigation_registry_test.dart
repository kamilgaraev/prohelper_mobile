import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';

void main() {
  test('registry resolves every primary dashboard route once', () {
    final routes = <String>{
      'project_overview',
      'site_requests',
      'site_request_approvals',
      'warehouse',
      'schedule',
      'ai_assistant',
      'construction_journal',
      'quality_control',
      'safety_management',
      'machinery_operations',
      'production_labor',
      'workforce_management',
      'handover_acceptance',
      'workflow_management',
      'time_tracking',
      'budget_estimates',
      'procurement',
      'contract_management',
      'change_management',
      'executive_documentation',
      'catalog_management',
      'brigades',
      'video_monitoring',
    };

    for (final route in routes) {
      final destination = MobileNavigationRegistry.destinationForRoute(route);
      expect(destination, isNotNull, reason: route);
      expect(destination!.title.trim(), isNotEmpty, reason: route);
      expect(destination.icon, isA<IconData>(), reason: route);
    }
  });

  test('registry groups modules into user-oriented navigation groups', () {
    final groups =
        MobileNavigationRegistry.destinations
            .map((destination) => destination.group)
            .toSet();

    expect(groups, contains(MobileModuleGroup.fieldWork));
    expect(groups, contains(MobileModuleGroup.warehouseAndSupply));
    expect(groups, contains(MobileModuleGroup.approvalsAndDocs));
    expect(groups, contains(MobileModuleGroup.management));
  });

  test('route aliases resolve to the same destination', () {
    expect(
      MobileNavigationRegistry.destinationForRoute('time-tracking')?.route,
      MobileNavigationRegistry.destinationForRoute('time_tracking')?.route,
    );

    expect(
      MobileNavigationRegistry.destinationForRoute(
        'contract-management',
      )?.route,
      MobileNavigationRegistry.destinationForRoute(
        'contract_management',
      )?.route,
    );
  });
}
