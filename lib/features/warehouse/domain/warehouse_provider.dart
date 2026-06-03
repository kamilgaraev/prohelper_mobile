import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/project_material_delivery_model.dart';
import '../data/warehouse_custody_model.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_summary_model.dart';

const _warehouseSentinel = Object();

class WarehouseState {
  const WarehouseState({
    this.isLoading = false,
    this.data,
    this.permissionDenied = false,
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
  WarehouseNotifier(this._repository) : super(const WarehouseState());

  final WarehouseRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      error: null,
    );

    try {
      final data = await _repository.fetchWarehouseSummary();
      state = state.copyWith(isLoading: false, data: data);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        permissionDenied: _isPermissionDenied(error),
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

final warehouseProvider =
    StateNotifierProvider<WarehouseNotifier, WarehouseState>((ref) {
      return WarehouseNotifier(ref.read(warehouseRepositoryProvider));
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
