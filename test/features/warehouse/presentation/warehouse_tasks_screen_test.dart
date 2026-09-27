import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_scan_model.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_tasks_screen.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository({this.withMore = false}) : super(Dio());

  final bool withMore;
  final requestedPages = <int>[];

  @override
  Future<List<WarehouseTaskModel>> fetchTasks(
    int warehouseId, {
    String? status,
    String? taskType,
    String? priority,
    String? entityType,
    int? entityId,
    String? query,
    int limit = 50,
  }) async {
    return const <WarehouseTaskModel>[];
  }

  @override
  Future<WarehouseTaskPage> fetchTaskPage(
    int warehouseId, {
    int page = 1,
    int perPage = 60,
    String? status,
    String? taskType,
    String? priority,
    String? entityType,
    int? entityId,
    String? query,
  }) async {
    requestedPages.add(page);
    final items =
        withMore
            ? [_task(page)]
            : const <WarehouseTaskModel>[];

    return WarehouseTaskPage(
      items: items,
      currentPage: page,
      lastPage: withMore ? 2 : 1,
      perPage: perPage,
      total: withMore ? 2 : 0,
    );
  }
}

WarehouseTaskModel _task(int id) => WarehouseTaskModel(
  id: id,
  warehouseId: 1,
  taskNumber: 'WH-$id',
  title: 'Задача $id',
  taskType: 'transfer',
  taskTypeLabel: 'Перемещение',
  status: 'queued',
  statusLabel: 'В очереди',
  priority: 'normal',
  priorityLabel: 'Обычный',
  metadata: const {},
  availableTransitions: const [],
);

const _summary = WarehouseSummaryModel(
  summary: WarehouseSummaryData(
    warehouseCount: 1,
    uniqueItemsCount: 3,
    lowStockCount: 0,
    reservedItemsCount: 0,
    recentMovementsCount: 0,
    totalValue: 0,
  ),
  warehouses: [
    WarehouseCardModel(
      id: 1,
      name: 'Основной склад',
      isMain: true,
      uniqueItemsCount: 3,
      totalValue: 0,
      warehouseType: 'central',
    ),
  ],
  recentMovements: [],
);

void main() {
  testWidgets('кнопка обновления задач склада имеет доступное имя', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          warehouseRepositoryProvider.overrideWithValue(
            _FakeWarehouseRepository(),
          ),
        ],
        child: const MaterialApp(home: WarehouseTasksScreen(summary: _summary)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Задачи склада'), findsOneWidget);
    expect(find.bySemanticsLabel('Обновить список'), findsOneWidget);
    expect(find.text('Задач пока нет'), findsOneWidget);
    expect(find.bySemanticsLabel('Очистить поиск'), findsNothing);

    await tester.enterText(find.byType(TextField), 'перемещение');
    await tester.pump();

    expect(find.bySemanticsLabel('Очистить поиск'), findsOneWidget);
  });

  testWidgets('подгружает следующую страницу задач склада', (tester) async {
    final repository = _FakeWarehouseRepository(withMore: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          warehouseRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: WarehouseTasksScreen(summary: _summary)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Задача 1'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Загрузить ещё задачи'), findsOneWidget);

    await tester.tap(find.text('Загрузить ещё задачи'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 2]);
    expect(find.text('Задача 1'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Задача 2'), findsOneWidget);
    expect(find.text('Загрузить ещё задачи'), findsNothing);
  });
}
