import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_summary_model.dart';

const _warehouseSentinel = Object();

class WarehouseState {
  const WarehouseState({
    this.isLoading = false,
    this.data,
    this.permissionDenied = false,
    this.error,
  });

  final bool isLoading;
  final WarehouseSummaryModel? data;
  final bool permissionDenied;
  final String? error;

  WarehouseState copyWith({
    bool? isLoading,
    Object? data = _warehouseSentinel,
    bool? permissionDenied,
    Object? error = _warehouseSentinel,
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
