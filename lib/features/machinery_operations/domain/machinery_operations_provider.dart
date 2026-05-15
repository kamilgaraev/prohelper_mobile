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

class MachineryOperationsNotifier extends StateNotifier<MachineryOperationsState> {
  MachineryOperationsNotifier(this._repository) : super(const MachineryOperationsState());

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
      final assets = await _repository.fetchAssets(projectId: state.projectFilter);
      final shifts = await _repository.fetchShiftReports(projectId: state.projectFilter);
      state = state.copyWith(isLoading: false, assets: assets, shiftReports: shifts);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> createShiftReport(MachineryAssetModel asset) async {
    final projectId = state.projectFilter ?? asset.projectId;
    if (projectId == null) {
      throw const FormatException('Выберите объект');
    }

    await _repository.createShiftReport(
      assetId: asset.id,
      projectId: projectId,
      reportDate: DateTime.now().toIso8601String().split('T').first,
      actualHours: 8,
      fuelConsumed: 0,
    );
    await load();
  }

  Future<void> createDowntime(MachineryAssetModel asset) async {
    final projectId = state.projectFilter ?? asset.projectId;
    if (projectId == null) {
      throw const FormatException('Выберите объект');
    }

    await _repository.createDowntime(assetId: asset.id, projectId: projectId, durationMinutes: 30);
    await load();
  }

  Future<void> createFuelIssue(MachineryAssetModel asset) async {
    final projectId = state.projectFilter ?? asset.projectId;
    if (projectId == null) {
      throw const FormatException('Выберите объект');
    }

    await _repository.createFuelIssue(assetId: asset.id, projectId: projectId, quantity: 50);
    await load();
  }
}

final machineryOperationsProvider = StateNotifierProvider<MachineryOperationsNotifier, MachineryOperationsState>((ref) {
  return MachineryOperationsNotifier(ref.read(machineryOperationsRepositoryProvider));
});
