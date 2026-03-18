import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_media_picker.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository() : super(Dio());

  @override
  Future<WarehouseSummaryModel> fetchWarehouseSummary() async => _summary;

  @override
  Future<List<WarehouseBalanceModel>> fetchBalances(int warehouseId) async {
    return const [
      WarehouseBalanceModel(
        warehouseId: 1,
        warehouseName: 'Основной склад',
        materialId: 7,
        materialName: 'Цемент М500',
        availableQuantity: 15,
        reservedQuantity: 2,
        totalQuantity: 17,
        averagePrice: 320,
        totalValue: 4800,
        isLowStock: false,
        photoGallery: [
          WarehousePhotoModel(id: 1, url: 'https://example.com/balance.jpg'),
        ],
        assetPhotoGallery: [],
        measurementUnit: 'меш.',
      ),
    ];
  }

  @override
  Future<List<WarehouseMaterialOption>> searchMaterials(
    String query, {
    int limit = 10,
  }) async {
    return const [
      WarehouseMaterialOption(
        id: 7,
        name: 'Цемент М500',
        defaultPrice: 320,
        code: 'CEM-500',
        measurementUnitShortName: 'меш.',
      ),
    ];
  }

  @override
  Future<WarehouseMovementModel> createReceipt(
    WarehouseReceiptPayload payload,
  ) async {
    return WarehouseMovementModel(
      id: 99,
      movementType: 'receipt',
      movementTypeLabel: 'Приход',
      quantity: payload.quantity,
      price: payload.price,
      photoGallery: payload.photos
          .asMap()
          .entries
          .map(
            (entry) => WarehousePhotoModel(
              id: entry.key + 1,
              url: 'https://example.com/${entry.key + 1}.jpg',
            ),
          )
          .toList(),
      materialName: 'Цемент М500',
    );
  }
}

class _FakeWarehouseNotifier extends WarehouseNotifier {
  _FakeWarehouseNotifier(WarehouseRepository repository) : super(repository) {
    state = const WarehouseState(isLoading: false, data: _summary, error: null);
  }

  @override
  Future<void> load() async {}
}

class _FakeMediaPicker extends WarehouseMediaPicker {
  _FakeMediaPicker({
    this.cameraPath,
    this.galleryPaths = const <String>[],
  });

  final String? cameraPath;
  final List<String> galleryPaths;

  @override
  Future<String?> pickFromCamera() async => cameraPath;

  @override
  Future<List<String>> pickFromGallery({int limit = 4}) async {
    return galleryPaths.take(limit).toList();
  }
}

const _summary = WarehouseSummaryModel(
  summary: WarehouseSummaryData(
    warehouseCount: 1,
    uniqueItemsCount: 48,
    lowStockCount: 3,
    reservedItemsCount: 5,
    recentMovementsCount: 7,
    totalValue: 125000,
  ),
  warehouses: [
    WarehouseCardModel(
      id: 1,
      name: 'Основной склад',
      isMain: true,
      uniqueItemsCount: 31,
      totalValue: 98000,
      address: 'Казань, Лесная улица, 15',
      warehouseType: 'central',
    ),
  ],
  recentMovements: [
    WarehouseMovementModel(
      id: 10,
      movementType: 'receipt',
      movementTypeLabel: 'Приход',
      quantity: 12,
      price: 5600,
      photoGallery: [],
      warehouseName: 'Основной склад',
      materialName: 'Цемент М500',
      measurementUnit: 'меш.',
      projectName: 'Дом 300м Царево',
      documentNumber: 'М-15-204',
    ),
  ],
);

void main() {
  testWidgets('показывает сводку и действия склада', (tester) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
    );

    expect(find.text('Склад'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Склады'), findsOneWidget);
    expect(find.text('Основной склад'), findsOneWidget);
    expect(
      find.widgetWithIcon(OutlinedButton, Icons.photo_library_outlined),
      findsWidgets,
    );
  });

  testWidgets('позволяет открыть форму прихода и добавить фото с камеры', (
    tester,
  ) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(cameraPath: '/tmp/camera-photo.jpg'),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Оприходование'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Цем');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Цемент М500'), findsWidgets);
    await tester.tap(find.text('Цемент М500').last);
    await tester.pumpAndSettle();

    await _ensureVisible(
      tester,
      find.byIcon(Icons.camera_alt_outlined).last,
    );
    await tester.tap(find.byIcon(Icons.camera_alt_outlined).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Выбрано 1 из 4'), findsOneWidget);
  });

  testWidgets('открывает остатки склада и галерею позиции', (tester) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
    );

    final balancesButton =
        find.widgetWithIcon(OutlinedButton, Icons.photo_library_outlined).first;

    await _ensureVisible(tester, balancesButton);
    await tester.tap(balancesButton);
    await tester.pumpAndSettle();

    expect(find.text('Цемент М500'), findsWidgets);
    expect(find.text('Галерея (1)'), findsOneWidget);
  });
}

Future<void> _pumpWarehouseScreen(
  WidgetTester tester, {
  required _FakeWarehouseRepository repository,
  required _FakeMediaPicker mediaPicker,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(repository),
        warehouseMediaPickerProvider.overrideWithValue(mediaPicker),
        warehouseProvider.overrideWith(
          (ref) => _FakeWarehouseNotifier(repository),
        ),
      ],
      child: const MaterialApp(home: WarehouseScreen()),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 5; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
}
