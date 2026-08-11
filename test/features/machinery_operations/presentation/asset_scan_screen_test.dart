import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/features/machinery_operations/presentation/storekeeper/asset_scan_screen.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';
import 'package:prohelpers_mobile/features/warehouse/domain/warehouse_provider.dart';

class _WarehouseNotifier extends WarehouseNotifier {
  _WarehouseNotifier() : super(WarehouseRepository(Dio())) {
    state = const WarehouseState(error: 'Склад временно недоступен');
  }

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('storekeeper gets a dedicated scanner state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          warehouseProvider.overrideWith((ref) => _WarehouseNotifier()),
        ],
        child: const MaterialApp(home: AssetScanScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Сканирование техники'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    expect(find.text('Склад временно недоступен'), findsOneWidget);
  });
}
