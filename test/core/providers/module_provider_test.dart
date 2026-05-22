import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';

void main() {
  test('parses every supported backend module slug', () {
    const supportedSlugs = {
      'basic-warehouse': AppModule.basicWarehouse,
      'site-requests': AppModule.siteRequests,
      'schedule-management': AppModule.scheduleManagement,
      'construction-journal': AppModule.constructionJournal,
      'ai-assistant': AppModule.aiAssistant,
      'budget-estimates': AppModule.budgetEstimates,
      'procurement': AppModule.procurement,
      'time-tracking': AppModule.timeTracking,
      'workflow-management': AppModule.workflowManagement,
      'quality-control': AppModule.qualityControl,
      'safety-management': AppModule.safetyManagement,
      'machinery-operations': AppModule.machineryOperations,
      'production-labor': AppModule.productionLabor,
      'workforce-management': AppModule.workforceManagement,
      'handover-acceptance': AppModule.handoverAcceptance,
    };

    for (final entry in supportedSlugs.entries) {
      expect(AppModuleX.fromSlug(entry.key), entry.value);
      expect(entry.value.backendSlug, entry.key);
    }
  });

  test('ignores unknown backend module slugs', () {
    expect(AppModuleX.fromSlug('unknown-module'), isNull);
  });
}
