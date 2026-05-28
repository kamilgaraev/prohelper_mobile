import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_action_recommendation.dart';
import 'package:prohelpers_mobile/core/navigation/mobile_navigation_registry.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';

void main() {
  test('recommendations keep pinned eligible actions and fill five slots', () {
    final context = MobileRecommendationContext(
      permissions: PermissionService(
        context: UserContext.office,
        activeModules: {
          AppModule.siteRequests,
          AppModule.scheduleManagement,
          AppModule.budgetEstimates,
          AppModule.qualityControl,
          AppModule.workflowManagement,
          AppModule.timeTracking,
        },
      ),
      userContext: UserContext.office,
      hasSelectedProject: true,
      pinnedActionIds: const ['approve_request', 'receive_material'],
      urgencyScores: const {'approve_request': 80, 'quality_control': 30},
    );

    final recommendations = MobileActionRecommender.recommend(
      destinations: MobileNavigationRegistry.destinations,
      context: context,
    );

    expect(recommendations, hasLength(5));
    expect(recommendations.first.destination.actionId, 'approve_request');
    expect(recommendations.first.source, MobileActionSource.pinned);
    expect(
      recommendations.map((item) => item.destination.actionId),
      isNot(contains('receive_material')),
      reason: 'Pinned actions without permission must not be shown.',
    );
  });

  test('field user receives field-first actions', () {
    final context = MobileRecommendationContext(
      permissions: PermissionService(
        context: UserContext.field,
        activeModules: {
          AppModule.basicWarehouse,
          AppModule.siteRequests,
          AppModule.scheduleManagement,
          AppModule.workforceManagement,
          AppModule.productionLabor,
          AppModule.machineryOperations,
          AppModule.timeTracking,
        },
      ),
      userContext: UserContext.field,
      hasSelectedProject: true,
      pinnedActionIds: const [],
      urgencyScores: const {},
    );

    final recommendations = MobileActionRecommender.recommend(
      destinations: MobileNavigationRegistry.destinations,
      context: context,
    );

    expect(recommendations, hasLength(5));
    expect(
      recommendations.take(3).map((item) => item.destination.actionId),
      containsAll(['receive_material', 'create_site_request']),
    );
  });
}
