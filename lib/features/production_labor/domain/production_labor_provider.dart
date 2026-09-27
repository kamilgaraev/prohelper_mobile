import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../data/production_labor_model.dart';
import '../data/production_labor_repository.dart';
import '../data/production_labor_snapshot_adapter.dart';

const _errorSentinel = Object();

class ProductionLaborState {
  const ProductionLaborState({
    this.isLoading = false,
    this.projectFilter,
    this.workOrders = const [],
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
  });

  final bool isLoading;
  final int? projectFilter;
  final List<LaborWorkOrderModel> workOrders;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;

  ProductionLaborState copyWith({
    bool? isLoading,
    int? projectFilter,
    List<LaborWorkOrderModel>? workOrders,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _errorSentinel,
  }) {
    return ProductionLaborState(
      isLoading: isLoading ?? this.isLoading,
      projectFilter: projectFilter ?? this.projectFilter,
      workOrders: workOrders ?? this.workOrders,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class ProductionLaborNotifier extends StateNotifier<ProductionLaborState> {
  ProductionLaborNotifier(
    this._repository, {
    ProductionLaborSnapshotAdapter? snapshotAdapter,
  }) : _snapshotAdapter = snapshotAdapter,
       super(const ProductionLaborState());

  final ProductionLaborRepository _repository;
  final ProductionLaborSnapshotAdapter? _snapshotAdapter;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(
      projectFilter: projectId,
      workOrders: const [],
      error: null,
      fromCache: false,
      hasDirtyLocal: false,
    );
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final adapter = _snapshotAdapter;
      if (adapter != null) {
        final read = await adapter.load(
          online: true,
          projectId: state.projectFilter,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          workOrders:
              denied ? const <LaborWorkOrderModel>[] : (read.data ?? const []),
          error: read.error,
          fromCache: read.fromCache,
          hasDirtyLocal: read.hasDirtyLocal,
        );
        return;
      }
      final workOrders = await _repository.fetchWorkOrders(
        projectId: state.projectFilter,
      );
      state = state.copyWith(
        isLoading: false,
        workOrders: workOrders,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: UserMessage.fromError(error),
        fromCache: false,
        hasDirtyLocal: false,
      );
    }
  }

  Future<void> recordOutput(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line, {
    required DateTime workDate,
    required double quantity,
    required double hours,
    required String idempotencyKey,
    String? comment,
  }) async {
    await _repository.recordOutput(
      workOrderLineId: line.id,
      quantity: quantity,
      hours: hours,
      workDate: workDate.toIso8601String().split('T').first,
      idempotencyKey: idempotencyKey,
      comment: comment,
    );
    await load();
  }

  Future<void> createTimesheet(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line, {
    required DateTime shiftDate,
    required double hours,
    required bool includeInPayroll,
    int? employeeId,
    String? workerName,
    String? safetyPermitReference,
  }) async {
    await _repository.createTimesheet(
      workOrderId: workOrder.id,
      workOrderLineId: line.id,
      hours: hours,
      shiftDate: shiftDate.toIso8601String().split('T').first,
      includeInPayroll: includeInPayroll,
      employeeId: employeeId,
      workerName: workerName,
      safetyPermitReference: safetyPermitReference,
    );
    await load();
  }
}

final productionLaborSnapshotAdapterProvider =
    Provider<ProductionLaborSnapshotAdapter>((ref) {
      return ProductionLaborSnapshotAdapter(
        repository: ref.read(productionLaborRepositoryProvider),
        snapshots: ref.read(entitySnapshotServiceProvider.future),
        flushQueue: () async {
          await ref.read(syncQueueProvider.notifier).retryPending();
        },
      );
    });

final productionLaborProvider =
    StateNotifierProvider<ProductionLaborNotifier, ProductionLaborState>((ref) {
      return ProductionLaborNotifier(
        ref.read(productionLaborRepositoryProvider),
        snapshotAdapter: ref.read(productionLaborSnapshotAdapterProvider),
      );
    });
