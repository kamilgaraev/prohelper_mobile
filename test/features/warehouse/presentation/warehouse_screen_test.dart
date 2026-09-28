import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/core/theme/pro_theme.dart';
import 'package:prohelpers_mobile/core/widgets/pro_metric_tile.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_media_picker.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_summary_model.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_receipt_sheet.dart';
import 'package:prohelpers_mobile/features/warehouse/presentation/warehouse_screen.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository({this.summary = _summary, this.balanceQuantity = 15})
    : super(Dio());

  final WarehouseSummaryModel summary;
  final double balanceQuantity;

  WarehouseReceiptPayload? createdReceipt;
  Object? createReceiptError;
  WarehouseWriteOffCategory? writtenOffCategory;
  Object? writeOffError;
  Completer<void>? writeOffCompleter;
  final List<_WriteOffAttempt> writeOffAttempts = [];

  @override
  Future<WarehouseSummaryModel> fetchWarehouseSummary() async => summary;

  @override
  Future<List<WarehouseBalanceModel>> fetchBalances(int warehouseId) async {
    return [
      WarehouseBalanceModel(
        warehouseId: 1,
        warehouseName: 'Основной склад',
        materialId: 7,
        materialName: 'Цемент М500',
        availableQuantity: balanceQuantity,
        reservedQuantity: 2,
        totalQuantity: balanceQuantity + 2,
        averagePrice: 320,
        totalValue: 4800,
        isLowStock: false,
        photoGallery: const [
          WarehousePhotoModel(id: 1, url: 'https://example.com/balance.jpg'),
        ],
        assetPhotoGallery: const [],
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

  @override
  Future<void> writeOff({
    required int warehouseId,
    required int materialId,
    required double quantity,
    String? documentNumber,
    required String reason,
    required WarehouseWriteOffCategory operationCategory,
  }) async {
    writeOffAttempts.add(
      _WriteOffAttempt(
        warehouseId: warehouseId,
        materialId: materialId,
        quantity: quantity,
        documentNumber: documentNumber,
        reason: reason,
        operationCategory: operationCategory,
      ),
    );
    final completer = writeOffCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = writeOffError;
    if (error != null) {
      writeOffError = null;
      throw error;
    }
    writtenOffCategory = operationCategory;
  }
}

class _WriteOffAttempt {
  const _WriteOffAttempt({
    required this.warehouseId,
    required this.materialId,
    required this.quantity,
    required this.documentNumber,
    required this.reason,
    required this.operationCategory,
  });

  final int warehouseId;
  final int materialId;
  final double quantity;
  final String? documentNumber;
  final String reason;
  final WarehouseWriteOffCategory operationCategory;
}

class _FakeWarehouseNotifier extends WarehouseNotifier {
  _FakeWarehouseNotifier(_FakeWarehouseRepository repository)
    : super(repository) {
    state = WarehouseState(
      isLoading: false,
      data: repository.summary,
      error: null,
    );
  }

  void showCachedError() {
    state = state.copyWith(error: 'Нет связи с сервером.');
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

const _longWarehouseSummary = WarehouseSummaryModel(
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
      name: 'Склад_материалов_северного_строительного_участка',
      isMain: true,
      uniqueItemsCount: 31,
      totalValue: 98000,
      address: 'Казань, Лесная улица, 15',
      warehouseType: 'central',
    ),
  ],
  recentMovements: [],
);

const _narrowWarehouseSummary = WarehouseSummaryModel(
  summary: WarehouseSummaryData(
    warehouseCount: 1,
    uniqueItemsCount: 1,
    lowStockCount: 0,
    reservedItemsCount: 0,
    recentMovementsCount: 0,
    totalValue: 0,
  ),
  warehouses: [
    WarehouseCardModel(
      id: 1,
      name: 'Склад',
      isMain: true,
      uniqueItemsCount: 1,
      totalValue: 0,
      warehouseType: 'central',
    ),
  ],
  recentMovements: [],
);

WarehouseSummaryModel _summaryWithMovementQuantity(double quantity) {
  final movement = _summary.recentMovements.single;
  return WarehouseSummaryModel(
    summary: _summary.summary,
    warehouses: _summary.warehouses,
    recentMovements: [
      WarehouseMovementModel(
        id: movement.id,
        movementType: movement.movementType,
        movementTypeLabel: movement.movementTypeLabel,
        quantity: quantity,
        price: movement.price,
        photoGallery: movement.photoGallery,
        warehouseName: movement.warehouseName,
        materialName: movement.materialName,
        measurementUnit: movement.measurementUnit,
        projectName: movement.projectName,
        documentNumber: movement.documentNumber,
        reason: movement.reason,
        movementDate: movement.movementDate,
      ),
    ],
  );
}

void main() {
  testWidgets('keeps thousandth precision for movement and balance', (
    tester,
  ) async {
    final repository = _FakeWarehouseRepository(
      summary: _summaryWithMovementQuantity(0.001),
      balanceQuantity: 0.001,
    );
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
    );

    await _ensureVisible(tester, find.text('0.001 меш.'));
    expect(find.text('0.001 меш.'), findsOneWidget);

    final balancesButton = find.text('Остатки').last;
    await _ensureVisible(tester, balancesButton);
    await tester.tap(balancesButton);
    await tester.pumpAndSettle();

    expect(find.text('0.001 меш.'), findsNWidgets(2));
  });

  testWidgets('warehouse metric grid adapts to narrow and regular widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeWarehouseRepository(
      summary: _narrowWarehouseSummary,
    );
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
      textScale: 1.3,
    );

    final tiles = find.byType(ProMetricTile);
    expect(tiles, findsNWidgets(4));
    for (final label in ['Складов', 'Позиций', 'Низкий остаток', 'Резерв']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.getTopLeft(tiles.at(1)).dy,
      greaterThan(tester.getBottomLeft(tiles.first).dy),
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 900);
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
    );
    expect(
      tester.getTopLeft(tiles.at(1)).dy,
      closeTo(tester.getTopLeft(tiles.first).dy, 1),
    );
    expect(
      tester.getTopLeft(tiles.at(2)).dy,
      greaterThan(tester.getBottomLeft(tiles.first).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('warehouse card keeps long name below its badges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(summary: _longWarehouseSummary),
      mediaPicker: _FakeMediaPicker(),
      textScale: 1.3,
    );
    await tester.scrollUntilVisible(
      find.text('Склад_материалов_северного_строительного_участка'),
      300,
    );

    expect(
      find.text('Склад_материалов_северного_строительного_участка'),
      findsOneWidget,
    );
    expect(find.text('Основной'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warehouse card actions fit 240dp with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
      textScale: 1.3,
      permissions: const {'warehouse.receipts'},
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Остатки'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.widgetWithText(OutlinedButton, 'Остатки'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Приход'), findsOneWidget);
    final balanceLabel = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.widgetWithText(OutlinedButton, 'Остатки'),
        matching: find.text('Остатки'),
      ),
    );
    expect(
      balanceLabel.size.height,
      lessThanOrEqualTo(balanceLabel.preferredLineHeight * 2.1),
    );
    final receiptLabel = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'Приход'),
        matching: find.text('Приход'),
      ),
    );
    expect(receiptLabel.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('write-off form submits the selected category', (tester) async {
    final repository = _FakeWarehouseRepository();
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
      canWriteOff: true,
    );
    await _ensureVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Остатки'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Остатки').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Списать').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.text('Категория списания'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Списать').first);
    await tester.pumpAndSettle();

    expect(find.text('Категория списания'), findsOneWidget);
    await tester.tap(find.text('Потеря').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повреждение').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Количество'),
      '1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Основание'),
      'Повреждено',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Списать').last);
    await tester.pumpAndSettle();

    expect(repository.writtenOffCategory, WarehouseWriteOffCategory.damage);
  });

  testWidgets('write-off keeps values on 422 and retries the same request', (
    tester,
  ) async {
    final repository =
        _FakeWarehouseRepository()
          ..writeOffError = const ApiException(
            'Количество превышает остаток',
            statusCode: 422,
          );
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
      canWriteOff: true,
    );
    await _openWriteOffDialog(tester);

    await tester.tap(find.byKey(const ValueKey('warehouse-write-off-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Укажите количество больше нуля'), findsOneWidget);
    expect(find.text('Укажите основание списания'), findsOneWidget);
    expect(repository.writeOffAttempts, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Количество'),
      '4',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Основание'),
      'Повреждено при перевозке',
    );
    await tester.tap(find.byKey(const ValueKey('warehouse-write-off-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Количество превышает остаток'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Количество'),
          )
          .controller
          ?.text,
      '4',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Основание'),
          )
          .controller
          ?.text,
      'Повреждено при перевозке',
    );
    expect(repository.writeOffAttempts, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('warehouse-write-off-submit')));
    await tester.pumpAndSettle();

    expect(repository.writeOffAttempts, hasLength(2));
    expect(
      repository.writeOffAttempts[0].quantity,
      repository.writeOffAttempts[1].quantity,
    );
    expect(
      repository.writeOffAttempts[0].reason,
      repository.writeOffAttempts[1].reason,
    );
    expect(repository.writeOffAttempts[1].quantity, 4);
    expect(repository.writeOffAttempts[1].reason, 'Повреждено при перевозке');
    expect(find.text('Списание · Цемент М500'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('write-off blocks a second tap while the request is pending', (
    tester,
  ) async {
    final repository =
        _FakeWarehouseRepository()..writeOffCompleter = Completer<void>();
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
      canWriteOff: true,
    );
    await _openWriteOffDialog(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Количество'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Основание'),
      'Контроль двойного нажатия',
    );

    await tester.tap(find.byKey(const ValueKey('warehouse-write-off-submit')));
    await tester.pump();
    expect(repository.writeOffAttempts, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('warehouse-write-off-submit')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('warehouse-balance-write-off')),
          )
          .onPressed,
      isNull,
    );

    await tester.tapAt(const Offset(1, 1));
    await tester.pump();
    expect(find.text('Списание · Цемент М500'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Списание · Цемент М500'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('warehouse-write-off-submit')));
    repository.writeOffCompleter!.complete();
    await tester.pumpAndSettle();

    expect(repository.writeOffAttempts, hasLength(1));
    expect(find.text('Списание · Цемент М500'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('write-off dialog fits 240dp at 1.3 text scale and disposes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeWarehouseRepository(
      summary: _narrowWarehouseSummary,
    );
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
      canWriteOff: true,
      textScale: 1.3,
    );
    await _openWriteOffDialog(tester);
    final submitCenter = tester.getCenter(
      find.byKey(const ValueKey('warehouse-write-off-submit')),
    );
    expect(submitCenter.dy, lessThan(900));
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(repository.writeOffAttempts, isEmpty);
    expect(find.text('Списание · Цемент М500'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('показывает предупреждение поверх сохранённых данных', (
    tester,
  ) async {
    final repository = _FakeWarehouseRepository();
    await _pumpWarehouseScreen(
      tester,
      repository: repository,
      mediaPicker: _FakeMediaPicker(),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WarehouseScreen)),
    );
    (container.read(warehouseProvider.notifier) as _FakeWarehouseNotifier)
        .showCachedError();
    await tester.pumpAndSettle();

    expect(find.text('Показаны сохранённые данные'), findsOneWidget);
    expect(find.text('Нет связи с сервером.'), findsOneWidget);
    expect(find.text('Складов'), findsWidgets);
  });

  testWidgets('показывает сводку и действия склада', (tester) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(galleryPaths: const ['/tmp/gallery.jpg']),
    );

    expect(find.text('Склад'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Оприходовать'), findsNothing);
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
      permissions: const {'warehouse.receipts'},
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

  testWidgets('warehouse entries stay hidden without their grants', (
    tester,
  ) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
    );

    expect(find.text('Оприходовать'), findsNothing);
    expect(find.text('У меня на ответственности'), findsNothing);
    await _ensureVisible(tester, find.text('Остатки').last);
    expect(find.widgetWithText(FilledButton, 'Приход'), findsNothing);
    await tester.tap(find.text('Остатки').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Приход'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Списать'), findsNothing);
  });

  testWidgets('write-off permission enables write-off without receipt grant', (
    tester,
  ) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
      permissions: const {'warehouse.write_offs'},
    );

    expect(find.text('Оприходовать'), findsNothing);
    final balancesButton = find.widgetWithText(OutlinedButton, 'Остатки');
    await _ensureVisible(tester, balancesButton);
    await tester.tap(balancesButton);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Списать'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Приход'), findsNothing);
  });

  testWidgets('receipt grant exposes all warehouse receipt entry points', (
    tester,
  ) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
      permissions: const {'warehouse.receipts'},
    );

    expect(find.text('Оприходовать'), findsOneWidget);
    await _ensureVisible(tester, find.text('Материалы на объект'));
    expect(find.text('Материалы на объект'), findsOneWidget);
    await _ensureVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Остатки'),
    );
    expect(find.widgetWithText(FilledButton, 'Приход'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Остатки'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Приход'), findsNWidgets(2));
  });

  testWidgets('granular custody-view grant exposes custody entry', (
    tester,
  ) async {
    await _pumpWarehouseScreen(
      tester,
      repository: _FakeWarehouseRepository(),
      mediaPicker: _FakeMediaPicker(),
      permissions: const {'warehouse.view_custody'},
    );

    await _ensureVisible(tester, find.text('У меня на ответственности'));
    expect(find.text('У меня на ответственности'), findsOneWidget);
  });
}

Future<void> _pumpWarehouseScreen(
  WidgetTester tester, {
  required _FakeWarehouseRepository repository,
  required _FakeMediaPicker mediaPicker,
  double textScale = 1,
  bool canWriteOff = false,
  Set<String> permissions = const <String>{},
}) async {
  final grants = <String>{
    ...permissions,
    if (canWriteOff) 'warehouse.manage_stock',
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        warehouseRepositoryProvider.overrideWithValue(repository),
        warehouseMediaPickerProvider.overrideWithValue(mediaPicker),
        warehouseProvider.overrideWith(
          (ref) => _FakeWarehouseNotifier(repository),
        ),
        permissionServiceProvider.overrideWithValue(
          PermissionService(
            context: UserContext.field,
            activeModules: const {AppModule.basicWarehouse},
            grantedPermissions: grants,
          ),
        ),
      ],
      child: MaterialApp(
        theme: MostTheme.lightTheme,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
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

Future<void> _openWriteOffDialog(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.widgetWithText(OutlinedButton, 'Остатки'),
    300,
    scrollable:
        find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first,
  );
  await tester.ensureVisible(
    find.widgetWithText(OutlinedButton, 'Остатки').last,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Остатки').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Списать').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Списать').first);
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
