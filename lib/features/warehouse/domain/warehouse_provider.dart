import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/warehouse_repository.dart';
import '../data/warehouse_summary_model.dart';

const _warehouseSentinel = Object();

class WarehouseState {
  const WarehouseState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  final bool isLoading;
  final WarehouseSummaryModel? data;
  final String? error;

  WarehouseState copyWith({
    bool? isLoading,
    Object? data = _warehouseSentinel,
    Object? error = _warehouseSentinel,
  }) {
    return WarehouseState(
      isLoading: isLoading ?? this.isLoading,
      data: identical(data, _warehouseSentinel) ? this.data : data as WarehouseSummaryModel?,
      error: identical(error, _warehouseSentinel) ? this.error : error as String?,
    );
  }
}

class WarehouseNotifier extends StateNotifier<WarehouseState> {
  WarehouseNotifier(this._repository) : super(const WarehouseState());

  final WarehouseRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _repository.fetchWarehouseSummary();
      state = state.copyWith(
        isLoading: false,
        data: data,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }
}

final warehouseProvider =
    StateNotifierProvider<WarehouseNotifier, WarehouseState>((ref) {
  return WarehouseNotifier(ref.read(warehouseRepositoryProvider));
});
