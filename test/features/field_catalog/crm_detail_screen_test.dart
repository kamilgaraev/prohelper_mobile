import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/field_catalog/data/field_catalog_repository.dart';
import 'package:prohelpers_mobile/features/field_catalog/presentation/field_catalog_screen.dart';

void main() {
  testWidgets('CRM detail shows business fields without technical metadata', (
    tester,
  ) async {
    final entry = FieldCatalogEntry.fromJson({
      'id': 'c124c9a8-138d-48c8-b9d1-148452fcc911',
      'organization_id': 38,
      'name': 'Тестовая компания',
      'company_type': 'legal_entity',
      'roles': <String>[],
      'status': 'new',
      'phone': '+7 999 000-00-00',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(_Repository(entry)),
          permissionServiceProvider.overrideWithValue(
            PermissionService(
              context: UserContext.office,
              activeModules: const {},
            ),
          ),
        ],
        child: const MaterialApp(
          home: FieldCatalogDetailScreen(
            title: 'Компания',
            catalog: 'crm',
            entity: 'companies',
            uuid: 'c124c9a8-138d-48c8-b9d1-148452fcc911',
            icon: Icons.business,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Новая'), findsWidgets);
    expect(find.text('Тип компании'), findsOneWidget);
    expect(find.text('Юридическое лицо'), findsOneWidget);
    expect(find.text('+7 999 000-00-00'), findsOneWidget);
    expect(find.text('Organization id'), findsNothing);
    expect(find.text('c124c9a8-138d-48c8-b9d1-148452fcc911'), findsNothing);
    expect(find.text('legal_entity'), findsNothing);
    expect(find.text('[]'), findsNothing);
  });

  testWidgets('report template detail translates the report type field', (
    tester,
  ) async {
    final entry = FieldCatalogEntry.fromJson({
      'id': 'template-1',
      'name': 'Ежемесячный отчёт',
      'report_type': 'contractor_detail',
      'is_default': true,
      'columns_config': [
        {'header': 'Номер договора', 'data_key': 'contract_number'},
      ],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fieldCatalogRepositoryProvider.overrideWithValue(_Repository(entry)),
        ],
        child: const MaterialApp(
          home: FieldCatalogDetailScreen(
            title: 'Шаблон отчёта',
            catalog: 'templates',
            uuid: 'template-1',
            icon: Icons.description,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Тип отчёта'), findsOneWidget);
    expect(find.text('Подрядчики: детализация'), findsOneWidget);
    expect(find.text('Стандартный шаблон'), findsOneWidget);
    expect(find.text('Столбцы'), findsOneWidget);
    expect(find.text('Номер договора'), findsOneWidget);
    expect(find.text('Report type'), findsNothing);
    expect(find.text('Columns config'), findsNothing);
    expect(find.text('Id'), findsNothing);
    expect(find.text('Name'), findsNothing);
  });
}

class _Repository extends FieldCatalogRepository {
  _Repository(this.entry) : super(Dio());

  final FieldCatalogEntry entry;

  @override
  Future<FieldCatalogEntry> fetchDetail({
    required String catalog,
    String? apiPrefix,
    String? entity,
    required String uuid,
    int? projectId,
  }) async => entry;
}
