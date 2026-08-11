import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/machinery_action.dart';
import '../../domain/machinery_operations_provider.dart';
import '../widgets/machinery_sync_status_panel.dart';

class MaintenanceQueueScreen extends ConsumerWidget {
  const MaintenanceQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineryOperationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ТО и дефекты')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(machineryOperationsProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const MachinerySyncStatusPanel(),
            if (state.maintenanceOrders.isEmpty && !state.isLoading)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.task_alt_rounded),
                  title: Text('Очередь ТО пуста'),
                  subtitle: Text('Новых дефектов и работ нет.'),
                ),
              )
            else
              ...state.maintenanceOrders.map(
                (order) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.statusLabel} · приоритет ${order.priority}',
                        ),
                        if (order.description != null) ...[
                          const SizedBox(height: 8),
                          Text(order.description!),
                        ],
                        if (order.availableActions.contains('complete')) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  () => ref
                                      .read(
                                        machineryOperationsProvider.notifier,
                                      )
                                      .execute(
                                        CompleteMaintenanceAction(
                                          order.assetId,
                                          orderId: order.id,
                                          completionComment:
                                              'Работы выполнены в мобильном приложении',
                                        ),
                                      ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Завершить ТО'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
