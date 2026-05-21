import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/production_labor_model.dart';
import '../data/production_labor_repository.dart';

const _errorSentinel = Object();

class ProductionLaborState {
  const ProductionLaborState({
    this.isLoading = false,
    this.projectFilter,
    this.workOrders = const [],
    this.error,
  });

  final bool isLoading;
  final int? projectFilter;
  final List<LaborWorkOrderModel> workOrders;
  final String? error;

  ProductionLaborState copyWith({
    bool? isLoading,
    int? projectFilter,
    List<LaborWorkOrderModel>? workOrders,
    Object? error = _errorSentinel,
  }) {
    return ProductionLaborState(
      isLoading: isLoading ?? this.isLoading,
      projectFilter: projectFilter ?? this.projectFilter,
      workOrders: workOrders ?? this.workOrders,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class ProductionLaborNotifier extends StateNotifier<ProductionLaborState> {
  ProductionLaborNotifier(this._repository)
    : super(const ProductionLaborState());

  final ProductionLaborRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectFilter == projectId) {
      return;
    }

    state = state.copyWith(projectFilter: projectId);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final workOrders = await _repository.fetchWorkOrders(
        projectId: state.projectFilter,
      );
      state = state.copyWith(isLoading: false, workOrders: workOrders);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> recordOutput(
    LaborWorkOrderModel workOrder,
    LaborWorkOrderLineModel line, {
    required DateTime workDate,
    required double quantity,
    required double hours,
    String? comment,
  }) async {
    await _repository.recordOutput(
      workOrderLineId: line.id,
      quantity: quantity,
      hours: hours,
      workDate: workDate.toIso8601String().split('T').first,
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

final productionLaborProvider =
    StateNotifierProvider<ProductionLaborNotifier, ProductionLaborState>((ref) {
      return ProductionLaborNotifier(
        ref.read(productionLaborRepositoryProvider),
      );
    });
