import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prohelpers_mobile/features/auth/presentation/login_screen.dart';
import 'package:prohelpers_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:prohelpers_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:prohelpers_mobile/features/projects/presentation/project_selection_screen.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';
import 'package:prohelpers_mobile/features/site_requests/presentation/screens/site_request_detail_screen.dart';
import 'package:prohelpers_mobile/main.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureProHelperIntegrationTestEnvironment();

  testWidgets('app starts on login without a saved session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: proHelperCoreOverrides(
          authenticated: false,
          selectedProject: null,
        ),
        child: const ProHelperApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('authenticated user without project reaches project selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: proHelperCoreOverrides(selectedProject: null),
        child: const ProHelperApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(ProjectSelectionScreen), findsOneWidget);
  });

  testWidgets('selected project reaches dashboard', (tester) async {
    final project = ProHelperTestData.project();

    await tester.pumpWidget(
      ProviderScope(
        overrides: proHelperCoreOverrides(selectedProject: project),
        child: const ProHelperApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('notifications open linked site request detail', (tester) async {
    final project = ProHelperTestData.project();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...proHelperCoreOverrides(selectedProject: project),
          siteRequestsRepositoryProvider.overrideWith(
            (ref) => _SmokeSiteRequestsRepository(),
          ),
        ],
        child: const ProHelperApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await _pumpFrames(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    await tester.tap(find.text('Site request needs attention'));
    await _pumpFrames(tester);

    expect(find.byType(NotificationDetailScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.open_in_new_rounded));
    await _pumpFrames(tester);

    expect(find.byType(SiteRequestDetailScreen), findsOneWidget);
    expect(find.text('Concrete delivery'), findsWidgets);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _SmokeSiteRequestsRepository extends SiteRequestsRepository {
  _SmokeSiteRequestsRepository() : super(Dio());

  @override
  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    return [ProHelperTestData.siteRequest()];
  }

  @override
  Future<SiteRequestModel> fetchSiteRequestDetails(int id) async {
    return ProHelperTestData.siteRequest(id: id);
  }
}
