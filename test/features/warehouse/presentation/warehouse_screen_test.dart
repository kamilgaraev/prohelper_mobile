import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_media_picker.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_receipt_sheet.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository() : super(Dio());

  WarehouseReceiptPayload? createdReceipt;
  Object? createReceiptError;

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
  Future<void> createReceipt(WarehouseReceiptPayload payload) async {
    createdReceipt = payload;
    final error = createReceiptError;
    if (error != null) {
      throw error;
    }
  }
}

class _FakeWarehouseNotifier extends WarehouseNotifier {
  _FakeWarehouseNotifier(super.repository) {
    state = const WarehouseState(isLoading: false, data: _summary, error: null);
  }

  @override
  Future<void> load() async {}
}

class _FakeMediaPicker extends WarehouseMediaPicker {
  _FakeMediaPicker({this.cameraPath, this.galleryPaths = const <String>[]});

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
      mediaPicker: _FakeMediaPicker(galleryPaths: const ['/tmp/gallery.jpg']),
    );

    expect(find.text('Склад'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Оприходовать'), findsOneWidget);
    await _ensureVisible(tester, find.text('Склады'));
    expect(find.text('Склады'), findsOneWidget);
    expect(find.text('Основной склад'), findsWidgets);
    await _ensureVisible(tester, find.text('Остатки').last);
    expect(find.text('Остатки'), findsWidgets);
  });

  testWidgets('позволяет открыть форму прихода и добавить фото с камеры', (
    tester,
  ) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(cameraPath: '/tmp/camera-photo.jpg'),
    );

    await tester.tap(find.text('Оприходовать'));
    await tester.pumpAndSettle();

    expect(find.text('Оприходование'), findsOneWidget);
    final quantityField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Количество',
      ),
    );
    expect(quantityField.controller?.text, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'Цем');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Цемент М500'), findsWidgets);
    await tester.tap(find.text('Цемент М500').last);
    await tester.pumpAndSettle();

    await _ensureVisible(tester, find.byIcon(Icons.camera_alt_outlined));
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

    final balancesButton = find.text('Остатки').last;

    await _ensureVisible(tester, balancesButton);
    await tester.tap(balancesButton);
    await tester.pumpAndSettle();

    expect(find.text('Цемент М500'), findsWidgets);
    expect(find.text('Галерея (1)'), findsOneWidget);
  });

  testWidgets('форма прихода показывает inline-ошибки обязательных полей', (
    tester,
  ) async {
    await _pumpReceiptSheet(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
    );

    await _ensureVisible(tester, find.text('Провести приход'));
    await tester.tap(find.text('Провести приход'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите склад'), findsOneWidget);
    expect(find.text('Выберите материал из списка'), findsOneWidget);
    expect(find.text('Укажите количество'), findsOneWidget);
    expect(find.text('Укажите цену'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('форма прихода очищает техническую ошибку отправки', (
    tester,
  ) async {
    final repository =
        _FakeWarehouseRepository()
          ..createReceiptError = const FormatException('payload warehouse_id');

    await _pumpReceiptSheet(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
      initialWarehouseId: 1,
    );

    await tester.enterText(find.byType(TextField).first, 'Цем');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Цемент М500').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Количество',
      ),
      '4',
    );
    await _ensureVisible(tester, find.text('Провести приход'));
    await tester.tap(find.text('Провести приход'));
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось выполнить действие. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('payload'), findsNothing);
    expect(repository.createdReceipt?.quantity, 4);
  });

  testWidgets('receipt sheet passes accessibility guidelines', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final semantics = tester.ensureSemantics();

    try {
      await _pumpReceiptSheet(
        tester,
        repository: _FakeWarehouseRepository(),
        mediaPicker: _FakeMediaPicker(),
        initialWarehouseId: 1,
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
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
      child: MaterialApp(
        theme: MostTheme.lightTheme,
        home: const WarehouseScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _pumpReceiptSheet(
  WidgetTester tester, {
  required _FakeWarehouseRepository repository,
  required _FakeMediaPicker mediaPicker,
  int? initialWarehouseId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(repository),
        warehouseMediaPickerProvider.overrideWithValue(mediaPicker),
      ],
      child: MaterialApp(
        theme: MostTheme.lightTheme,
        home: Scaffold(
          body: WarehouseReceiptSheet(
            summary: _summary,
            initialWarehouseId: initialWarehouseId,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 8; i++) {
    if (_hasMatches(finder)) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -250),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }
}

bool _hasMatches(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}
