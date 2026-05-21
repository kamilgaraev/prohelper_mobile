import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/machinery_operations_model.dart';
import '../data/machinery_operations_repository.dart';

const _errorSentinel = Object();

class MachineryOperationsState {
  const MachineryOperationsState({
    this.isLoading = false,
    this.projectFilter,
    this.assets = const [],
    this.shiftReports = const [],
    this.error,
  });

  final bool isLoading;
  final int? projectFilter;
  final List<MachineryAssetModel> assets;
  final List<MachineryShiftReportModel> shiftReports;
  final String? error;

  MachineryOperationsState copyWith({
    bool? isLoading,
    int? projectFilter,
    List<MachineryAssetModel>? assets,
    List<MachineryShiftReportModel>? shiftReports,
    Object? error = _errorSentinel,
  }) {
    return MachineryOperationsState(
      isLoading: isLoading ?? this.isLoading,
      projectFilter: projectFilter ?? this.projectFilter,
      assets: assets ?? this.assets,
      shiftReports: shiftReports ?? this.shiftReports,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class MachineryOperationsNotifier
    extends StateNotifier<MachineryOperationsState> {
  MachineryOperationsNotifier(this._repository)
    : super(const MachineryOperationsState());

  final MachineryOperationsRepository _repository;

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
      final shifts = await _repository.fetchShiftReports(
        projectId: state.projectFilter,
      );
      state = state.copyWith(
        isLoading: false,
        assets: assets,
        shiftReports: shifts,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
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
      startedAt: startedAt.toIso8601String(),
      durationMinutes: durationMinutes,
      comment: comment,
    );
    await load();
  }

  Future<void> createFuelIssue(
    MachineryAssetModel asset, {
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
      issuedAt: issuedAt.toIso8601String(),
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
      recordedAt: recordedAt.toIso8601String(),
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
  );
});
