import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../warehouse/domain/warehouse_provider.dart';
import '../../../warehouse/presentation/warehouse_scan_screen.dart';

class AssetScanScreen extends ConsumerStatefulWidget {
  const AssetScanScreen({super.key});

  @override
  ConsumerState<AssetScanScreen> createState() => _AssetScanScreenState();
}

class _AssetScanScreenState extends ConsumerState<AssetScanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(warehouseProvider);
      if (state.data == null && !state.isLoading) {
        ref.read(warehouseProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    if (state.data != null) {
      return WarehouseScanScreen(summary: state.data!);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Сканирование техники')),
      body: Center(
        child:
            state.isLoading
                ? const CircularProgressIndicator()
                : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        state.error ?? 'Не удалось загрузить склады.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed:
                            () => ref.read(warehouseProvider.notifier).load(),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
