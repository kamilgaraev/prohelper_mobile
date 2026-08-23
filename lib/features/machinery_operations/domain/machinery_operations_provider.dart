import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/sync/queued_sync_operation.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../data/machinery_operations_model.dart';
import '../data/machinery_operations_repository.dart';
import 'machinery_action.dart';

const _errorSentinel = Object();

class MachineryOperationsState {
  const MachineryOperationsState({
    this.isLoading = false,
    this.projectFilter,
    this.assets = const [],
    this.shiftReports = const [],
    this.maintenanceOrders = const [],
    this.syncOperations = const [],
    this.error,
  });

  final bool isLoading;
  final int? projectFilter;
  final List<MachineryAssetModel> assets;
  final List<MachineryShiftReportModel> shiftReports;
  final List<MachineryMaintenanceOrderModel> maintenanceOrders;
  final List<QueuedSyncOperation> syncOperations;
  final String? error;

  MachineryOperationsState copyWith({
    bool? isLoading,
    int? projectFilter,
    List<MachineryAssetModel>? assets,
    List<MachineryShiftReportModel>? shiftReports,
    List<MachineryMaintenanceOrderModel>? maintenanceOrders,
    List<QueuedSyncOperation>? syncOperations,
    Object? error = _errorSentinel,
  }) {
    return MachineryOperationsState(
      isLoading: isLoading ?? this.isLoading,
      projectFilter: projectFilter ?? this.projectFilter,
      assets: assets ?? this.assets,
      shiftReports: shiftReports ?? this.shiftReports,
      maintenanceOrders: maintenanceOrders ?? this.maintenanceOrders,
      syncOperations: syncOperations ?? this.syncOperations,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class MachineryOperationsNotifier
    extends StateNotifier<MachineryOperationsState> {
  MachineryOperationsNotifier(this._repository, [this._syncQueueFuture])
    : super(const MachineryOperationsState());

  final MachineryOperationsRepository _repository;
  final Future<SyncQueueService>? _syncQueueFuture;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(projectFilter: projectId);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final assets = await _repository.fetchAssets(
        projectId: state.projectFilter,
      );
      final results = await Future.wait<dynamic>([
        _repository.fetchShiftReports(projectId: state.projectFilter),
        _repository.fetchMaintenanceOrders(projectId: state.projectFilter),
        _loadSyncOperations(),
      ]);
      state = state.copyWith(
        isLoading: false,
        assets: assets,
        shiftReports: results[0] as List<MachineryShiftReportModel>,
        maintenanceOrders: results[1] as List<MachineryMaintenanceOrderModel>,
        syncOperations: results[2] as List<QueuedSyncOperation>,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: UserMessage.fromError(error),
        syncOperations: await _loadSyncOperations(),
      );
    }
  }

  Future<void> execute(MachineryAction action) async {
    try {
      await _repository.executeAction(action);
    } on SyncQueuedException {
      await load();
      return;
    } catch (error) {
      state = state.copyWith(error: UserMessage.fromError(error));
      rethrow;
    }
    await load();
  }

  Future<void> retryQueuedOperations() async {
    final future = _syncQueueFuture;
    if (future == null) {
      return;
    }
    final queue = await future;
    await queue.retryDueOperations();
    state = state.copyWith(syncOperations: await _loadSyncOperations());
  }

  Future<List<QueuedSyncOperation>> _loadSyncOperations() async {
    final future = _syncQueueFuture;
    if (future == null) {
      return const [];
    }
    final queue = await future;
    final operations = await queue.all();
    return operations
        .where((item) => item.moduleSlug == 'machinery_operations')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> createShiftReport(
    MachineryAssetModel asset, {
    required DateTime reportDate,
    double? plannedHours,
    required double actualHours,
    required double fuelConsumed,
    String? workDescription,
  }) async {
    final projectId = state.projectFilter ?? asset.projectId;
    if (projectId == null) {
      throw const FormatException('Выберите объект.');
    }

    await _repository.createShiftReport(
      assetId: asset.id,
      projectId: projectId,
      reportDate: reportDate.toIso8601String().split('T').first,
      plannedHours: plannedHours,
      actualHours: actualHours,
      fuelConsumed: fuelConsumed,
      workDescription: workDescription,
    );
    await load();
  }

  Future<void> createDowntime(
    MachineryAssetModel asset, {
    int? shiftReportId,
    required String reason,
    required DateTime startedAt,
    required int durationMinutes,
    String? comment,
  }) async {
    final projectId = state.projectFilter ?? asset.projectId;
    if (projectId == null) {
      throw const FormatException('Выберите объект.');
    }

    await _repository.createDowntime(
      assetId: asset.id,
      projectId: projectId,
      shiftReportId: shiftReportId,
      reason: reason,
      startedAt: startedAt.toUtc().toIso8601String(),
      durationMinutes: durationMinutes,
      comment: comment,
    );
    await load();
  }

  Future<void> createFuelIssue(
    MachineryAssetModel asset, {
    required int shiftReportId,
    required int warehouseId,
    required int materialId,
    required DateTime issuedAt,
    required String fuelType,
    required double quantity,
    required String unit,
    String? comment,
  }) async {
    final projectId = state.projectFilter ?? asset.projectId;
    if (projectId == null) {
      throw const FormatException('Выберите объект.');
    }

    await _repository.createFuelIssue(
      assetId: asset.id,
      projectId: projectId,
      shiftReportId: shiftReportId,
      warehouseId: warehouseId,
      materialId: materialId,
      issuedAt: issuedAt.toUtc().toIso8601String(),
      fuelType: fuelType,
      quantity: quantity,
      unit: unit,
      comment: comment,
    );
    await load();
  }

  Future<void> createProductionRecord(
    MachineryAssetModel asset, {
    int? shiftReportId,
    required DateTime recordedAt,
    required double quantity,
    required String unit,
    String? comment,
  }) async {
    final projectId = state.projectFilter ?? asset.projectId;
    if (projectId == null) {
      throw const FormatException('Выберите объект.');
    }

    await _repository.createProductionRecord(
      assetId: asset.id,
      projectId: projectId,
      shiftReportId: shiftReportId,
      recordedAt: recordedAt.toUtc().toIso8601String(),
      quantity: quantity,
      unit: unit,
      comment: comment,
    );
    await load();
  }
}

final machineryOperationsProvider = StateNotifierProvider<
  MachineryOperationsNotifier,
  MachineryOperationsState
>((ref) {
  return MachineryOperationsNotifier(
    ref.read(machineryOperationsRepositoryProvider),
    ref.read(syncQueueServiceProvider.future),
  );
});
