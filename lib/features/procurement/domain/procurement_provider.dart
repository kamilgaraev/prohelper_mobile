import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../data/procurement_model.dart';
import '../data/procurement_repository.dart';

class ProcurementState {
  const ProcurementState({
    this.isLoading = false,
    this.projectId,
    this.summary,
    this.requests = const ProcurementPage<ProcurementPurchaseRequestModel>(
      items: [],
      currentPage: 0,
      lastPage: 0,
      total: 0,
    ),
    this.orders = const ProcurementPage<ProcurementPurchaseOrderModel>(
      items: [],
      currentPage: 0,
      lastPage: 0,
      total: 0,
    ),
    this.loadingRequests = false,
    this.loadingOrders = false,
    this.requestQuery = '',
    this.orderQuery = '',
    this.requestStatus,
    this.orderStatus,
    this.requestsError,
    this.ordersError,
    this.permissionDenied = false,
    this.malformedContract = false,
    this.error,
  });

  final bool isLoading;
  final int? projectId;
  final ProcurementSummaryModel? summary;
  final ProcurementPage<ProcurementPurchaseRequestModel> requests;
  final ProcurementPage<ProcurementPurchaseOrderModel> orders;
  final bool loadingRequests;
  final bool loadingOrders;
  final String requestQuery;
  final String orderQuery;
  final String? requestStatus;
  final String? orderStatus;
  final String? requestsError;
  final String? ordersError;
  final bool permissionDenied;
  final bool malformedContract;
  final String? error;

  ProcurementState copyWith({
    bool? isLoading,
    Object? projectId = _projectSentinel,
    Object? summary = _summarySentinel,
    Object? requests = _requestsSentinel,
    Object? orders = _ordersSentinel,
    bool? loadingRequests,
    bool? loadingOrders,
    String? requestQuery,
    String? orderQuery,
    Object? requestStatus = _requestStatusSentinel,
    Object? orderStatus = _orderStatusSentinel,
    Object? requestsError = _requestsErrorSentinel,
    Object? ordersError = _ordersErrorSentinel,
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
      requests:
          identical(requests, _requestsSentinel)
              ? this.requests
              : requests as ProcurementPage<ProcurementPurchaseRequestModel>,
      orders:
          identical(orders, _ordersSentinel)
              ? this.orders
              : orders as ProcurementPage<ProcurementPurchaseOrderModel>,
      loadingRequests: loadingRequests ?? this.loadingRequests,
      loadingOrders: loadingOrders ?? this.loadingOrders,
      requestQuery: requestQuery ?? this.requestQuery,
      orderQuery: orderQuery ?? this.orderQuery,
      requestStatus:
          identical(requestStatus, _requestStatusSentinel)
              ? this.requestStatus
              : requestStatus as String?,
      orderStatus:
          identical(orderStatus, _orderStatusSentinel)
              ? this.orderStatus
              : orderStatus as String?,
      requestsError:
          identical(requestsError, _requestsErrorSentinel)
              ? this.requestsError
              : requestsError as String?,
      ordersError:
          identical(ordersError, _ordersErrorSentinel)
              ? this.ordersError
              : ordersError as String?,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      malformedContract: malformedContract ?? this.malformedContract,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

const _projectSentinel = Object();
const _summarySentinel = Object();
const _requestsSentinel = Object();
const _ordersSentinel = Object();
const _requestStatusSentinel = Object();
const _orderStatusSentinel = Object();
const _requestsErrorSentinel = Object();
const _ordersErrorSentinel = Object();
const _errorSentinel = Object();

class ProcurementNotifier extends StateNotifier<ProcurementState> {
  ProcurementNotifier(this._repository) : super(const ProcurementState());

  final ProcurementRepository _repository;
  int _contextRevision = 0;
  int _summaryRevision = 0;
  int _requestsRevision = 0;
  int _ordersRevision = 0;

  void syncProject(int? projectId) {
    if (state.projectId == projectId) {
      return;
    }

    _contextRevision++;
    _summaryRevision++;
    _requestsRevision++;
    _ordersRevision++;

    state = state.copyWith(
      isLoading: false,
      projectId: projectId,
      summary: null,
      error: null,
      requests: const ProcurementPage<ProcurementPurchaseRequestModel>(
        items: [],
        currentPage: 0,
        lastPage: 0,
        total: 0,
      ),
      orders: const ProcurementPage<ProcurementPurchaseOrderModel>(
        items: [],
        currentPage: 0,
        lastPage: 0,
        total: 0,
      ),
    );
  }

  Future<void> loadSummary() async {
    final summaryRevision = ++_summaryRevision;
    final contextRevision = _contextRevision;
    _requestsRevision++;
    _ordersRevision++;
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
      if (contextRevision != _contextRevision ||
          summaryRevision != _summaryRevision) {
        return;
      }
      state = state.copyWith(isLoading: false, summary: summary, error: null);
      await Future.wait([_loadRequestPage(), _loadOrderPage()]);
    } catch (error) {
      if (contextRevision != _contextRevision ||
          summaryRevision != _summaryRevision) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        summary: null,
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> loadMoreRequests() async {
    if (state.loadingRequests || !state.requests.hasMore) return;
    final contextRevision = _contextRevision;
    final revision = _requestsRevision;
    final projectId = state.projectId;
    state = state.copyWith(loadingRequests: true, requestsError: null);
    try {
      final next = await _repository.fetchPurchaseRequests(
        projectId: projectId,
        page: state.requests.currentPage + 1,
        status: state.requestStatus,
        query: state.requestQuery,
      );
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision) {
        return;
      }
      state = state.copyWith(
        loadingRequests: false,
        requests: ProcurementPage<ProcurementPurchaseRequestModel>(
          items: [...state.requests.items, ...next.items],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        ),
      );
    } catch (error) {
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision) {
        return;
      }
      state = state.copyWith(
        loadingRequests: false,
        requestsError: UserMessage.fromError(error),
      );
    }
  }

  Future<void> loadMoreOrders() async {
    if (state.loadingOrders || !state.orders.hasMore) return;
    final contextRevision = _contextRevision;
    final revision = _ordersRevision;
    final projectId = state.projectId;
    state = state.copyWith(loadingOrders: true, ordersError: null);
    try {
      final next = await _repository.fetchPurchaseOrders(
        projectId: projectId,
        page: state.orders.currentPage + 1,
        status: state.orderStatus,
        query: state.orderQuery,
      );
      if (contextRevision != _contextRevision || revision != _ordersRevision) {
        return;
      }
      state = state.copyWith(
        loadingOrders: false,
        orders: ProcurementPage<ProcurementPurchaseOrderModel>(
          items: [...state.orders.items, ...next.items],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        ),
      );
    } catch (error) {
      if (contextRevision != _contextRevision || revision != _ordersRevision) {
        return;
      }
      state = state.copyWith(
        loadingOrders: false,
        ordersError: UserMessage.fromError(error),
      );
    }
  }

  Future<void> filterRequests({
    String? status,
    String? query,
    bool clearStatus = false,
  }) async {
    _requestsRevision++;
    state = state.copyWith(
      requestStatus: clearStatus ? null : status ?? state.requestStatus,
      requestQuery: query ?? state.requestQuery,
      requests: const ProcurementPage<ProcurementPurchaseRequestModel>(
        items: [],
        currentPage: 0,
        lastPage: 0,
        total: 0,
      ),
    );
    await _loadRequestPage();
  }

  Future<void> filterOrders({
    String? status,
    String? query,
    bool clearStatus = false,
  }) async {
    _ordersRevision++;
    state = state.copyWith(
      orderStatus: clearStatus ? null : status ?? state.orderStatus,
      orderQuery: query ?? state.orderQuery,
      orders: const ProcurementPage<ProcurementPurchaseOrderModel>(
        items: [],
        currentPage: 0,
        lastPage: 0,
        total: 0,
      ),
    );
    await _loadOrderPage();
  }

  Future<void> _loadRequestPage() async {
    final contextRevision = _contextRevision;
    final revision = _requestsRevision;
    final projectId = state.projectId;
    state = state.copyWith(loadingRequests: true, requestsError: null);
    try {
      final page = await _repository.fetchPurchaseRequests(
        projectId: projectId,
        status: state.requestStatus,
        query: state.requestQuery,
      );
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision) {
        return;
      }
      state = state.copyWith(
        requests: page,
        loadingRequests: false,
        requestsError: null,
      );
    } catch (error) {
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision) {
        return;
      }
      state = state.copyWith(
        loadingRequests: false,
        requestsError: UserMessage.fromError(error),
      );
    }
  }

  Future<void> _loadOrderPage() async {
    final contextRevision = _contextRevision;
    final revision = _ordersRevision;
    final projectId = state.projectId;
    state = state.copyWith(loadingOrders: true, ordersError: null);
    try {
      final page = await _repository.fetchPurchaseOrders(
        projectId: projectId,
        status: state.orderStatus,
        query: state.orderQuery,
      );
      if (contextRevision != _contextRevision || revision != _ordersRevision) {
        return;
      }
      state = state.copyWith(
        orders: page,
        loadingOrders: false,
        ordersError: null,
      );
    } catch (error) {
      if (contextRevision != _contextRevision || revision != _ordersRevision) {
        return;
      }
      state = state.copyWith(
        loadingOrders: false,
        ordersError: UserMessage.fromError(error),
      );
    }
  }

  Future<ProcurementPurchaseRequestModel> fetchPurchaseRequest(int id) {
    return _repository.fetchPurchaseRequest(id);
  }

  Future<ProcurementPurchaseRequestModel> createPurchaseRequest(
    Map<String, dynamic> payload,
  ) async {
    final created = await _repository.createPurchaseRequest(payload);
    await loadSummary();
    return created;
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
