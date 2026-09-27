import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/sync/queued_sync_operation.dart';
import '../../../core/sync/sync_operation_presentation.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/pro_page_scaffold.dart';
import '../domain/pending_sync_provider.dart';

class PendingSyncScreen extends ConsumerWidget {
  const PendingSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingSyncProvider);
    final hasQueued = state.operations.any(
      (operation) => operation.status == SyncOperationStatuses.queued,
    );
    final notifier = ref.read(pendingSyncProvider.notifier);

    return ProPageScaffold(
      title: 'Не отправлено',
      subtitle: 'Сохранённые на устройство операции',
      onRefresh: notifier.load,
      actions: [
        if (hasQueued)
          IconButton(
            tooltip: 'Повторить отправку',
            onPressed: () => unawaited(notifier.retryQueued()),
            icon: const Icon(Icons.sync_rounded),
          ),
      ],
      body: _PendingSyncBody(state: state, notifier: notifier),
    );
  }
}

class _PendingSyncBody extends StatelessWidget {
  const _PendingSyncBody({required this.state, required this.notifier});

  final PendingSyncState state;
  final PendingSyncNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.operations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.operations.isEmpty && state.error != null) {
      return AppErrorState(
        title: 'Не удалось загрузить очередь',
        description: state.error,
        onRetry: () => unawaited(notifier.load()),
      );
    }

    if (state.operations.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Все операции отправлены',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь появятся действия, которые сохранились на устройство, пока не было связи.',
            style: AppTypography.bodyMedium(context),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.error != null) _LoadErrorNotice(error: state.error!),
        for (final operation in state.operations)
          _PendingSyncTile(
            operation: operation,
            onRetry:
                operation.status == SyncOperationStatuses.queued
                    ? () => unawaited(notifier.retryQueued())
                    : null,
            onDiscard:
                operation.status == SyncOperationStatuses.conflict ||
                        operation.status == SyncOperationStatuses.needsEdit
                    ? () =>
                        unawaited(_confirmDiscard(context, notifier, operation))
                    : null,
          ),
      ],
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    PendingSyncNotifier notifier,
    QueuedSyncOperation operation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Удалить сохранённое действие?'),
            content: const Text(
              'Проверьте результат на объекте перед удалением. Действие исчезнет только с устройства; данные на сервере останутся.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await notifier.discardReviewed(operation.id);
    }
  }
}

class _LoadErrorNotice extends StatelessWidget {
  const _LoadErrorNotice({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.error_outline_rounded,
          color: theme.colorScheme.error,
        ),
        title: const Text('Не удалось обновить список'),
        subtitle: Text(error),
      ),
    );
  }
}

class _PendingSyncTile extends StatelessWidget {
  const _PendingSyncTile({
    required this.operation,
    this.onRetry,
    this.onDiscard,
  });

  final QueuedSyncOperation operation;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConflict =
        operation.status == SyncOperationStatuses.conflict ||
        operation.status == SyncOperationStatuses.needsEdit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isConflict
                    ? Icons.compare_arrows_rounded
                    : Icons.cloud_upload_outlined,
              ),
              title: Text(
                SyncOperationPresentation.operationLabel(operation),
                style: AppTypography.bodyMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                SyncOperationPresentation.statusLabel(operation.status),
              ),
              trailing:
                  onRetry == null
                      ? null
                      : IconButton(
                        tooltip: 'Повторить отправку',
                        onPressed: onRetry,
                        icon: const Icon(Icons.sync_rounded),
                      ),
            ),
            if (operation.lastBusinessError != null)
              Text(
                operation.lastBusinessError!,
                style: AppTypography.caption(context).copyWith(
                  color:
                      isConflict
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (operation.status == SyncOperationStatuses.conflict)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  operation.lastBusinessError == null
                      ? 'Проверьте состояние операции на объекте, затем решите, нужно ли повторить действие.'
                      : 'Проверьте состояние операции на объекте. Не отправляйте её повторно, пока не убедитесь, что действие не выполнено.',
                  style: AppTypography.caption(context),
                ),
              ),
            if (onDiscard != null)
              TextButton.icon(
                onPressed: onDiscard,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Удалить с устройства'),
              ),
          ],
        ),
      ),
    );
  }
}
