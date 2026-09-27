import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/sync/queued_sync_operation.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../auth/domain/auth_provider.dart';

class PendingSyncState {
  const PendingSyncState({
    this.isLoading = false,
    this.operations = const [],
    this.error,
  });

  final bool isLoading;
  final List<QueuedSyncOperation> operations;
  final String? error;

  PendingSyncState copyWith({
    bool? isLoading,
    List<QueuedSyncOperation>? operations,
    String? error,
    bool clearError = false,
  }) {
    return PendingSyncState(
      isLoading: isLoading ?? this.isLoading,
      operations: operations ?? this.operations,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final pendingSyncProvider =
    StateNotifierProvider<PendingSyncNotifier, PendingSyncState>((ref) {
      final notifier = PendingSyncNotifier(ref);
      ref.listen<AuthState>(authProvider, (_, __) {
        unawaited(notifier.load());
      });
      ref.listen<SyncQueueProcessResult?>(syncQueueProvider, (previous, next) {
        if (previous != next) unawaited(notifier.load());
      });
      return notifier;
    });

class PendingSyncNotifier extends StateNotifier<PendingSyncState> {
  PendingSyncNotifier(this._ref) : super(const PendingSyncState()) {
    unawaited(load());
  }

  final Ref _ref;
  StreamSubscription<int>? _queueChangesSubscription;
  SyncQueueService? _observedQueue;
  int _loadGeneration = 0;

  Future<void> load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final queue = await _ref.read(syncQueueServiceProvider.future);
      if (!mounted) return;
      _observeQueue(queue);
      final operations = await queue.forCurrentOwner();
      if (!mounted || generation != _loadGeneration) return;
      operations.sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      );
      state = state.copyWith(isLoading: false, operations: operations);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> retryQueued() async {
    try {
      final queue = await _ref.read(syncQueueServiceProvider.future);
      await queue.retryDueOperations();
    } catch (error) {
      state = state.copyWith(error: UserMessage.fromError(error));
      return;
    }
    await load();
  }

  Future<void> discardReviewed(int id) async {
    try {
      final queue = await _ref.read(syncQueueServiceProvider.future);
      await queue.discardReviewedForCurrentOwner(id);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(error: UserMessage.fromError(error));
      return;
    }
    await load();
  }

  void _observeQueue(SyncQueueService queue) {
    if (identical(_observedQueue, queue)) return;
    _observedQueue = queue;
    unawaited(_queueChangesSubscription?.cancel());
    _queueChangesSubscription = queue.changes.listen((_) {
      unawaited(load());
    });
  }

  @override
  void dispose() {
    _loadGeneration++;
    unawaited(_queueChangesSubscription?.cancel());
    super.dispose();
  }
}
