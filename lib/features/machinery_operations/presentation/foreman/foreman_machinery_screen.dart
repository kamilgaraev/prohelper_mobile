import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/machinery_operations_provider.dart';
import '../widgets/machinery_sync_status_panel.dart';

class ForemanMachineryScreen extends ConsumerWidget {
  const ForemanMachineryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineryOperationsProvider);
    final review =
        state.shiftReports
            .where((shift) => shift.status == 'submitted')
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Техника на объекте')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(machineryOperationsProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const MachinerySyncStatusPanel(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Техника',
                        value: state.assets.length,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'На проверку',
                        value: review.length,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Проблемы',
                        value:
                            state.assets
                                .where((asset) => asset.problemFlags.isNotEmpty)
                                .length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Рапорты на проверку',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (review.isEmpty)
              const Card(child: ListTile(title: Text('Очередь проверки пуста')))
            else
              ...review.map(
                (shift) => Card(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(shift.assetName ?? 'Техника №${shift.assetId}'),
                    subtitle: Text(
                      '${shift.reportDate} · ${shift.actualHours} ч · ${shift.fuelConsumed} л',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Парк объекта', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (state.assets.isEmpty && !state.isLoading)
              const Card(child: ListTile(title: Text('Техника не назначена')))
            else
              ...state.assets.map(
                (asset) => Card(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: const Icon(Icons.precision_manufacturing_outlined),
                    title: Text(asset.name),
                    subtitle: Text(asset.projectName ?? asset.assetCode),
                    trailing: Text(asset.statusLabel),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$value', style: Theme.of(context).textTheme.headlineSmall),
      Text(label, textAlign: TextAlign.center),
    ],
  );
}
