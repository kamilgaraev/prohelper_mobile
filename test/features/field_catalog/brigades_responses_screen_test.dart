import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/field_catalog_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/team_expansion_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/presentation/brigades_screen.dart';

void main() {
  testWidgets('loads all brigade responses page by page', (tester) async {
    final repository = _PagedTeamExpansionRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamExpansionRepositoryProvider.overrideWithValue(repository),
          permissionServiceProvider.overrideWithValue(
            PermissionService(
              context: UserContext.office,
              activeModules: const {},
              grantedPermissions: const {'brigades.responses.view'},
            ),
          ),
        ],
        child: const MaterialApp(
          home: BrigadeResponsesScreen(
            requestId: '42',
            requestTitle: 'Монтаж кровли',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Бригада А'), findsOneWidget);
    expect(find.text('Бригада Б'), findsNothing);
    expect(find.text('Загрузить ещё'), findsOneWidget);

    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 2]);
    expect(find.text('Бригада А'), findsOneWidget);
    expect(find.text('Бригада Б'), findsOneWidget);
    expect(find.text('Загрузить ещё'), findsNothing);
  });
}

class _PagedTeamExpansionRepository extends TeamExpansionRepository {
  _PagedTeamExpansionRepository() : super(Dio());

  final requestedPages = <int>[];

  @override
  Future<FieldCatalogPage> fetchPage({
    required String path,
    Map<String, Object?> filters = const {},
    int page = 1,
    int perPage = 20,
  }) async {
    requestedPages.add(page);
    final entry = FieldCatalogEntry.fromJson({
      'id': 'response-$page',
      'brigade': {'name': page == 1 ? 'Бригада А' : 'Бригада Б'},
      'status': 'pending',
    });
    return FieldCatalogPage(
      items: [entry],
      currentPage: page,
      lastPage: 2,
      total: 2,
    );
  }
}
