import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/procurement/domain/procurement_provider.dart';
import 'package:prohelpers_mobile/features/procurement/presentation/procurement_screen.dart';
import 'package:prohelpers_mobile/features/projects/data/project_model.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';

import '../procurement_test_data.dart';

class _OfflineSearchRepository extends ProcurementRepository {
  _OfflineSearchRepository() : super(Dio());

  @override
  Future<ProcurementSummaryModel> fetchSummary({int? projectId}) async =>
      ProcurementSummaryModel.fromJson(procurementSummaryJson());

  @override
  Future<ProcurementPage<ProcurementPurchaseRequestModel>>
  fetchPurchaseRequests({
    int? projectId,
    int page = 1,
    String? status,
    String? query,
  }) async {
    if (query != null && query.isNotEmpty) {
      throw const ApiException('Нет соединения с сервером');
    }
    return ProcurementPage(
      items: [
        ProcurementPurchaseRequestModel.fromJson(
          procurementPurchaseRequestJson(),
        ),
      ],
      currentPage: page,
      lastPage: 1,
      total: 1,
    );
  }

  @override
  Future<ProcurementPage<ProcurementPurchaseOrderModel>> fetchPurchaseOrders({
    int? projectId,
    int page = 1,
    String? status,
    String? query,
  }) async => ProcurementPage(
    items: [
      ProcurementPurchaseOrderModel.fromJson(procurementPurchaseOrderJson()),
    ],
    currentPage: page,
    lastPage: 1,
    total: 1,
  );
}

class _ProjectsRepo extends ProjectsRepository {
  _ProjectsRepo() : super(Dio());

  @override
  Future<List<Project>> fetchProjects() async => const [];
}

class _ProjectsNotifier extends ProjectsNotifier {
  _ProjectsNotifier(Project project) : super(_ProjectsRepo()) {
    state = ProjectsState(projects: [project], selectedProject: project);
  }
}

void main() {
  testWidgets('shows previous successful rows and a retryable error', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project =
        Project()
          ..serverId = 9
          ..name = 'Башня'
          ..address = 'Площадка 1';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => _ProjectsNotifier(project)),
          procurementProvider.overrideWith(
            (ref) => ProcurementNotifier(_OfflineSearchRepository()),
          ),
        ],
        child: const MaterialApp(home: ProcurementScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final requestFilter = find.widgetWithText(TextFormField, 'Найти заявку');
    expect(requestFilter, findsOneWidget);
    await tester.tap(requestFilter);
    await tester.enterText(requestFilter, 'бетон');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(
      find.text('Показаны результаты предыдущего запроса.'),
      findsOneWidget,
    );
    expect(find.text('Нет соединения с сервером'), findsOneWidget);
    expect(find.text('Поставка бетона'), findsWidgets);
    expect(find.text('Повторить'), findsOneWidget);
  });
}
