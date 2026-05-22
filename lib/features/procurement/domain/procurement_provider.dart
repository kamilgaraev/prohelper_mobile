import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/procurement_model.dart';
import '../data/procurement_repository.dart';

class ProcurementState {
  const ProcurementState({
    this.isLoading = false,
    this.projectId,
    this.summary,
    this.permissionDenied = false,
    this.malformedContract = false,
    this.error,
  });

  final bool isLoading;
  final int? projectId;
  final ProcurementSummaryModel? summary;
  final bool permissionDenied;
  final bool malformedContract;
  final String? error;

  ProcurementState copyWith({
    bool? isLoading,
    Object? projectId = _projectSentinel,
    Object? summary = _summarySentinel,
    bool? permissionDenied,
    bool? malformedContract,
    Object? error = _errorSentinel,
  }) {
    return ProcurementState(
      isLoading: isLoading ?? this.isLoading,
      projectId:
          identical(projectId, _projectSentinel)
              ? this.projectId
              : projectId as int?,
      summary:
          identical(summary, _summarySentinel)
              ? this.summary
              : summary as ProcurementSummaryModel?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      malformedContract: malformedContract ?? this.malformedContract,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _projectSentinel = Object();
const _summarySentinel = Object();
const _errorSentinel = Object();

class ProcurementNotifier extends StateNotifier<ProcurementState> {
  ProcurementNotifier(this._repository) : super(const ProcurementState());

  final ProcurementRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectId == projectId) {
      return;
    }

    state = state.copyWith(projectId: projectId, summary: null, error: null);
  }

  Future<void> loadSummary() async {
    state = state.copyWith(
      isLoading: true,
      permissionDenied: false,
      malformedContract: false,
      error: null,
    );

    try {
      final summary = await _repository.fetchSummary(
        projectId: state.projectId,
      );
      state = state.copyWith(isLoading: false, summary: summary);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        summary: null,
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        error: error.toString(),
      );
    }
  }

  Future<ProcurementOrderDetailModel> fetchOrder(int id) {
    return _repository.fetchOrder(id);
  }

  Future<ProcurementPurchaseOrderModel> receiveMaterials({
    required int orderId,
    required int warehouseId,
    required List<ProcurementReceiveItemPayload> items,
    required String receiptDate,
    String? notes,
  }) async {
    final updated = await _repository.receiveMaterials(
      orderId: orderId,
      warehouseId: warehouseId,
      items: items,
      receiptDate: receiptDate,
      notes: notes,
    );
    await loadSummary();
    return updated;
  }

  Future<ProcurementPurchaseOrderModel> addOrderComment({
    required int orderId,
    required String comment,
  }) async {
    final updated = await _repository.addOrderComment(
      orderId: orderId,
      comment: comment,
    );
    await loadSummary();
    return updated;
  }

  Future<ProcurementApprovalModel> approveApproval({
    required int id,
    String? comment,
  }) async {
    final updated = await _repository.approveApproval(id: id, comment: comment);
    await loadSummary();
    return updated;
  }

  Future<ProcurementApprovalModel> rejectApproval({
    required int id,
    required String comment,
  }) async {
    final updated = await _repository.rejectApproval(id: id, comment: comment);
    await loadSummary();
    return updated;
  }
}

bool _isPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

final procurementProvider =
    StateNotifierProvider<ProcurementNotifier, ProcurementState>((ref) {
      return ProcurementNotifier(ref.read(procurementRepositoryProvider));
    });
