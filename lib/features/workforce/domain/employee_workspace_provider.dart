import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/employee_workspace_model.dart';
import '../data/employee_workspace_repository.dart';

final employeeWorkspaceProvider = StateNotifierProvider.autoDispose<
  EmployeeWorkspaceNotifier,
  AsyncValue<EmployeeWorkspaceModel>
>(
  (ref) =>
      EmployeeWorkspaceNotifier(ref.read(employeeWorkspaceRepositoryProvider)),
);

class EmployeeWorkspaceNotifier
    extends StateNotifier<AsyncValue<EmployeeWorkspaceModel>> {
  EmployeeWorkspaceNotifier(this._repository) : super(const AsyncLoading()) {
    load();
  }
  final EmployeeWorkspaceRepository _repository;
  int _loadGeneration = 0;
  String month =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

  Future<void> load({String? selectedMonth}) async {
    if (selectedMonth != null) {
      month = selectedMonth;
    }
    final generation = ++_loadGeneration;
    state = const AsyncLoading();
    try {
      final value = await _repository.fetch(month);
      if (mounted && generation == _loadGeneration) {
        state = AsyncData(value);
      }
    } catch (error, stack) {
      if (mounted && generation == _loadGeneration) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> submit({
    required String idempotencyKey,
    required String kind,
    required String dateFrom,
    required String dateTo,
    required String basis,
    required Map<String, dynamic> requestedData,
  }) async {
    await _repository.submit(
      idempotencyKey: idempotencyKey,
      kind: kind,
      dateFrom: dateFrom,
      dateTo: dateTo,
      basis: basis,
      requestedData: requestedData,
    );
    if (mounted) {
      await load();
    }
  }

  Future<Uri> download(int documentId) => _repository.download(documentId);
}

final employeeRequestsProvider = StateNotifierProvider.autoDispose<
  EmployeeRequestsNotifier,
  AsyncValue<EmployeeRequestPageModel>
>(
  (ref) =>
      EmployeeRequestsNotifier(ref.read(employeeWorkspaceRepositoryProvider)),
);

class EmployeeRequestsNotifier
    extends StateNotifier<AsyncValue<EmployeeRequestPageModel>> {
  EmployeeRequestsNotifier(this._repository) : super(const AsyncLoading()) {
    load();
  }
  final EmployeeWorkspaceRepository _repository;
  int _generation = 0;
  int _page = 1;
  Future<void> load({int? page}) async {
    if (page != null) {
      _page = page;
    }
    final generation = ++_generation;
    state = const AsyncLoading();
    try {
      final result = await _repository.fetchRequests(page: _page);
      if (mounted && generation == _generation) {
        state = AsyncData(result);
      }
    } catch (error, stack) {
      if (mounted && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }
}
