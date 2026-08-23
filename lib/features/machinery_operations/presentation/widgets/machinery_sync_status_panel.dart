import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/sync/queued_sync_operation.dart';
import '../../domain/machinery_operations_provider.dart';

class MachinerySyncStatusPanel extends ConsumerWidget {
  const MachinerySyncStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(
      machineryOperationsProvider.select((state) => state.syncOperations),
    );
    if (operations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Синхронизация',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...operations
                .take(5)
                .map(
                  (operation) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 48,
                    leading: Icon(_icon(operation.status)),
                    title: Text(_label(operation.status)),
                    subtitle: Text(
                      operation.lastBusinessError ?? _operationLabel(operation),
                    ),
                  ),
                ),
            if (operations.any(
              (operation) => operation.status == SyncOperationStatuses.queued,
            ))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      () =>
                          ref
                              .read(machineryOperationsProvider.notifier)
                              .retryQueuedOperations(),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Повторить безопасно'),
                ),
              ),
            if (operations.any(
              (operation) =>
                  operation.status == SyncOperationStatuses.needsEdit ||
                  operation.status == SyncOperationStatuses.conflict,
            ))
              const Text(
                'Отклонённые сервером операции не повторяются автоматически. Исправьте данные и отправьте заново.',
              ),
          ],
        ),
      ),
    );
  }

  static String _label(String status) => switch (status) {
    SyncOperationStatuses.sending => 'Отправляется',
    SyncOperationStatuses.conflict => 'Конфликт состояния',
    SyncOperationStatuses.needsEdit => 'Отклонено сервером',
    SyncOperationStatuses.permissionDenied => 'Недостаточно прав',
    _ => 'Ожидает отправки',
  };

  static IconData _icon(String status) => switch (status) {
    SyncOperationStatuses.sending => Icons.sync_rounded,
    SyncOperationStatuses.conflict => Icons.compare_arrows_rounded,
    SyncOperationStatuses.needsEdit => Icons.error_outline_rounded,
    SyncOperationStatuses.permissionDenied => Icons.lock_outline_rounded,
    _ => Icons.cloud_upload_outlined,
  };

  static String _operationLabel(QueuedSyncOperation operation) =>
      switch (operation.operationType) {
        'start_shift' => 'Начало смены',
        'finish_shift' => 'Завершение смены',
        'submit_shift' => 'Отправка рапорта',
        'record_downtime' => 'Простой',
        'record_fuel' => 'Заправка',
        'complete_maintenance' => 'Завершение ТО',
        _ => 'Операция с техникой',
      };
}
