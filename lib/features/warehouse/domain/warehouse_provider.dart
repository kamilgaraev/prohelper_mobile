import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/entity_snapshot_provider.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/project_material_delivery_model.dart';
import '../data/warehouse_custody_model.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_summary_model.dart';
import '../data/warehouse_snapshot_adapter.dart';

const _warehouseSentinel = Object();

class WarehouseState {
  const WarehouseState({
    this.isLoading = false,
    this.data,
    this.permissionDenied = false,
    this.fromCache = false,
    this.hasDirtyLocal = false,
    this.error,
    this.custodyBalances = const <WarehouseCustodyBalanceModel>[],
    this.isCustodyLoading = false,
    this.custodyError,
    this.projectMaterialStock,
    this.isProjectMaterialStockLoading = false,
    this.projectMaterialStockError,
  });

  final bool isLoading;
  final WarehouseSummaryModel? data;
  final bool permissionDenied;
  final bool fromCache;
  final bool hasDirtyLocal;
  final String? error;
  final List<WarehouseCustodyBalanceModel> custodyBalances;
  final bool isCustodyLoading;
  final Object? custodyError;
  final ProjectMaterialStockModel? projectMaterialStock;
  final bool isProjectMaterialStockLoading;
  final Object? projectMaterialStockError;

  WarehouseState copyWith({
    bool? isLoading,
    Object? data = _warehouseSentinel,
    bool? permissionDenied,
    bool? fromCache,
    bool? hasDirtyLocal,
    Object? error = _warehouseSentinel,
    List<WarehouseCustodyBalanceModel>? custodyBalances,
    bool? isCustodyLoading,
    Object? custodyError = _warehouseSentinel,
    Object? projectMaterialStock = _warehouseSentinel,
    bool? isProjectMaterialStockLoading,
    Object? projectMaterialStockError = _warehouseSentinel,
  }) {
    return WarehouseState(
      isLoading: isLoading ?? this.isLoading,
      data:
          identical(data, _warehouseSentinel)
              ? this.data
              : data as WarehouseSummaryModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      fromCache: fromCache ?? this.fromCache,
      hasDirtyLocal: hasDirtyLocal ?? this.hasDirtyLocal,
      error:
          identical(error, _warehouseSentinel) ? this.error : error as String?,
      custodyBalances: custodyBalances ?? this.custodyBalances,
      isCustodyLoading: isCustodyLoading ?? this.isCustodyLoading,
      custodyError:
          identical(custodyError, _warehouseSentinel)
              ? this.custodyError
              : custodyError,
      projectMaterialStock:
          identical(projectMaterialStock, _warehouseSentinel)
              ? this.projectMaterialStock
              : projectMaterialStock as ProjectMaterialStockModel?,
      isProjectMaterialStockLoading:
          isProjectMaterialStockLoading ?? this.isProjectMaterialStockLoading,
      projectMaterialStockError:
          identical(projectMaterialStockError, _warehouseSentinel)
              ? this.projectMaterialStockError
              : projectMaterialStockError,
    );
  }
}

class WarehouseNotifier extends StateNotifier<WarehouseState> {
  WarehouseNotifier(
    this._repository, {
    WarehouseSnapshotAdapter? snapshotAdapter,
    bool Function()? isOnline,
  }) : _snapshotAdapter = snapshotAdapter,
       _isOnline = isOnline,
       super(const WarehouseState());

  final WarehouseRepository _repository;
  final WarehouseSnapshotAdapter? _snapshotAdapter;
  final bool Function()? _isOnline;

  bool get isLoading => state.isLoading;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final snapshotAdapter = _snapshotAdapter;
      if (snapshotAdapter != null) {
        final read = await snapshotAdapter.load(
          online: _isOnline?.call() ?? false,
        );
        final denied = read.presence == SnapshotPresence.permissionDenied;
        state = state.copyWith(
          isLoading: false,
          data: denied ? null : read.data,
          permissionDenied: denied,
          fromCache: !denied && read.fromCache,
          hasDirtyLocal: !denied && read.hasDirtyLocal,
          error: read.error,
        );
        return;
      }
      final data = await _repository.fetchWarehouseSummary();
      state = state.copyWith(
        isLoading: false,
        data: data,
        fromCache: false,
        hasDirtyLocal: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
        fromCache: false,
        error: _errorMessage(error),
      );
    }
  }

  Future<void> loadCustodyBalances({
    int? projectId,
    int? responsibleUserId,
  }) async {
    state = state.copyWith(isCustodyLoading: true, custodyError: null);

    try {
      final balances = await _repository.fetchCustodyBalances(
        projectId: projectId,
        responsibleUserId: responsibleUserId,
      );
      state = state.copyWith(
        isCustodyLoading: false,
        custodyBalances: balances,
      );
    } catch (error) {
      state = state.copyWith(
        isCustodyLoading: false,
        custodyError: _errorMessage(error),
      );
    }
  }

  Future<void> loadProjectMaterialStock({int? projectId}) async {
    state = state.copyWith(
      isProjectMaterialStockLoading: true,
      projectMaterialStockError: null,
    );

    try {
      final stock = await _repository.fetchProjectMaterialStock(
        projectId: projectId,
      );
      state = state.copyWith(
        isProjectMaterialStockLoading: false,
        projectMaterialStock: stock,
      );
    } catch (error) {
      state = state.copyWith(
        isProjectMaterialStockLoading: false,
        projectMaterialStockError: _errorMessage(error),
      );
    }
  }

  Future<void> issueToResponsible({
    required int projectId,
    required int projectWarehouseId,
    required int materialId,
    required int responsibleUserId,
    required double quantity,
    String? documentNumber,
    String? reason,
  }) async {
    state = state.copyWith(custodyError: null);

    try {
      await _repository.issueToResponsible(
        projectId: projectId,
        projectWarehouseId: projectWarehouseId,
        materialId: materialId,
        responsibleUserId: responsibleUserId,
        quantity: quantity,
        documentNumber: documentNumber,
        reason: reason,
      );
      await Future.wait([
        loadCustodyBalances(projectId: projectId),
        loadProjectMaterialStock(projectId: projectId),
      ]);
    } catch (error) {
      state = state.copyWith(custodyError: _errorMessage(error));
      rethrow;
    }
  }

  Future<void> returnFromResponsible({
    required int projectId,
    required int custodyWarehouseId,
    required int materialId,
    required double quantity,
    String? documentNumber,
    String? reason,
  }) async {
    state = state.copyWith(custodyError: null);

    try {
      await _repository.returnFromResponsible(
        projectId: projectId,
        custodyWarehouseId: custodyWarehouseId,
        materialId: materialId,
        quantity: quantity,
        documentNumber: documentNumber,
        reason: reason,
      );
      await Future.wait([
        loadCustodyBalances(projectId: projectId),
        loadProjectMaterialStock(projectId: projectId),
      ]);
    } catch (error) {
      state = state.copyWith(custodyError: _errorMessage(error));
      rethrow;
    }
  }
}

final warehouseSnapshotAdapterProvider = Provider<WarehouseSnapshotAdapter>((
  ref,
) {
  return WarehouseSnapshotAdapter(
    repository: ref.read(warehouseRepositoryProvider),
    snapshots: ref.read(entitySnapshotServiceProvider.future),
    flushQueue: () async {
      await ref.read(syncQueueProvider.notifier).retryPending();
    },
  );
});

final warehouseProvider =
    StateNotifierProvider<WarehouseNotifier, WarehouseState>((ref) {
      final notifier = WarehouseNotifier(
        ref.read(warehouseRepositoryProvider),
        snapshotAdapter: ref.read(warehouseSnapshotAdapterProvider),
        isOnline: () {
          final auth = ref.read(authProvider);
          return auth is AuthAuthenticated && auth.isOnlineVerified;
        },
      );
      ref.listen<AuthState>(authProvider, (previous, next) {
        final wasOnline =
            previous is AuthAuthenticated && previous.isOnlineVerified;
        final isOnline = next is AuthAuthenticated && next.isOnlineVerified;
        if (!wasOnline && isOnline && !notifier.isLoading) {
          unawaited(notifier.load());
        }
      });
      ref.listen(syncQueueProvider, (previous, next) {
        if (next != null && !notifier.isLoading) {
          unawaited(notifier.load());
        }
      });
      return notifier;
    });

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

String _errorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }

  if (error is FormatException) {
    return 'Данные склада пришли неполными. Обновите экран и повторите попытку.';
  }

  return 'Не удалось обработать данные склада.';
}
