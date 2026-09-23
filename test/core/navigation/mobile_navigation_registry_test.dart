import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_destination.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/features/actions/presentation/mobile_action_search.dart';
import 'package:prohelpers_mobile/features/modules/data/mobile_module_model.dart';

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

  test('all nine admin groups have mobile records and working routes', () {
    final destinations = MobileNavigationRegistry.destinations;
    for (final group in MobileAdminGroup.values) {
      final groupDestinations = destinations.where(
        (destination) => destination.adminGroup == group,
      );
      expect(groupDestinations, isNotEmpty, reason: group.name);
      for (final destination in groupDestinations) {
        expect(
          MobileNavigationRegistry.destinationForRoute(destination.route),
          same(destination),
          reason: destination.route,
        );
      }
    }
  });

  test('system and contractor routes require their own permissions', () {
    for (final route in <String>[
      'contractors',
      'one_c_exchange',
      'access_recertification',
      'rate_coefficients',
      'system_events',
    ]) {
      final destination = MobileNavigationRegistry.destinationForRoute(route);
      expect(destination, isNotNull, reason: route);
      expect(destination!.allowsPermissions(const []), isFalse, reason: route);
      expect(
        destination.allowsPermissions(destination.viewPermissions),
        isTrue,
        reason: route,
      );
    }
  });

  test('secondary project and calendar screens appear from module grants', () {
    MobileModuleModel module(
      String slug,
      String route,
      List<String> permissions,
    ) => MobileModuleModel(
      slug: slug,
      title: slug,
      description: '',
      icon: 'grid',
      supportedOnMobile: true,
      order: 0,
      route: route,
      permissions: permissions,
    );

    final routes =
        visibleMobileDestinations([
          module('project-management', 'project_overview', ['projects.view']),
          module('workforce-management', 'workforce_management', [
            'workforce.view',
          ]),
          module('site-requests', 'site_requests', [
            'site_requests.view',
            'site_requests.calendar.view',
          ]),
        ]).map((destination) => destination.route).toSet();

    expect(
      routes,
      containsAll([
        'project_files',
        'project_participants',
        'workforce_roster',
        'site_requests_calendar',
      ]),
    );
    final withoutCalendar = visibleMobileDestinations([
      module('site-requests', 'site_requests', ['site_requests.view']),
    ]).map((destination) => destination.route);
    expect(withoutCalendar, isNot(contains('site_requests_calendar')));
    expect(withoutCalendar, isNot(contains('site_request_approvals')));
    final withApprovals = visibleMobileDestinations([
      module('site-requests', 'site_requests', ['site_requests.approve']),
    ]).map((destination) => destination.route);
    expect(withApprovals, contains('site_request_approvals'));
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
