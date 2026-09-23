import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/warehouse/data/project_material_delivery_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/project_resource_analytics_screen.dart';

class _WarehouseRepository extends WarehouseRepository {
  _WarehouseRepository() : super(Dio());

  int? requestedProjectId;

  @override
  Future<ProjectMaterialStockModel> fetchProjectMaterialStock({
    int? projectId,
  }) async {
    requestedProjectId = projectId;
    return _stock;
  }
}

const _stock = ProjectMaterialStockModel(
  items: [
    ProjectMaterialStockItemModel(
      projectId: 21,
      projectName: 'Северный корпус',
      materialId: 8,
      materialName: 'Бетон B25',
      materialUnit: 'м³',
      acceptedQuantity: 18,
      usedQuantity: 6.5,
      availableQuantity: 11.5,
      deliveries: [],
      usages: [
        ProjectMaterialStockUsageModel(
          deliveryId: 4,
          entryNumber: 12,
          workDescription: 'Заливка фундамента',
          quantity: 6.5,
          measurementUnit: 'м³',
        ),
      ],
    ),
    ProjectMaterialStockItemModel(
      projectId: 22,
      projectName: 'Южный корпус',
      materialId: 9,
      materialName: 'Кирпич',
      acceptedQuantity: 100,
      usedQuantity: 10,
      availableQuantity: 90,
      deliveries: [],
      usages: [],
    ),
  ],
  summary: ProjectMaterialStockSummaryModel(
    materialsCount: 1,
    deliveriesCount: 1,
    acceptedQuantity: 18,
    usedQuantity: 6.5,
    availableQuantity: 11.5,
  ),
);

void main() {
  testWidgets('loads selected project stock and shows usage from journal', (
    tester,
  ) async {
    final repository = _WarehouseRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [warehouseRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: MostTheme.lightTheme,
          home: const ProjectResourceAnalyticsScreen(
            projectId: 21,
            projectName: 'Северный корпус',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedProjectId, 21);
    expect(find.text('Бетон B25'), findsOneWidget);
    expect(find.text('Кирпич'), findsNothing);
    expect(find.text('11.5 м³'), findsOneWidget);
    expect(find.text('6.5 м³'), findsWidgets);
    expect(find.textContaining('Заливка фундамента'), findsOneWidget);
  });
}
