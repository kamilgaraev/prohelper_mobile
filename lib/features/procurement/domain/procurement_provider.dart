import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../auth/domain/auth_provider.dart';
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
    this.hasSuccessfulRequestsPage = false,
    this.requestsPageProjectId,
    this.requestsPageQuery = '',
    this.requestsPageStatus,
    this.hasSuccessfulOrdersPage = false,
    this.ordersPageProjectId,
    this.ordersPageQuery = '',
    this.ordersPageStatus,
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
  final bool hasSuccessfulRequestsPage;
  final int? requestsPageProjectId;
  final String requestsPageQuery;
  final String? requestsPageStatus;
  final bool hasSuccessfulOrdersPage;
  final int? ordersPageProjectId;
  final String ordersPageQuery;
  final String? ordersPageStatus;
  final String? requestsError;
  final String? ordersError;
  final bool permissionDenied;
  final bool malformedContract;
  final String? error;

  bool get requestsShowingPreviousQuery =>
      requests.items.isNotEmpty &&
      hasSuccessfulRequestsPage &&
      (requestsPageProjectId != projectId ||
          requestsPageQuery != requestQuery ||
          requestsPageStatus != requestStatus);

  bool get ordersShowingPreviousQuery =>
      orders.items.isNotEmpty &&
      hasSuccessfulOrdersPage &&
      (ordersPageProjectId != projectId ||
          ordersPageQuery != orderQuery ||
          ordersPageStatus != orderStatus);

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
    bool? hasSuccessfulRequestsPage,
    Object? requestsPageProjectId = _requestsPageProjectSentinel,
    String? requestsPageQuery,
    Object? requestsPageStatus = _requestsPageStatusSentinel,
    bool? hasSuccessfulOrdersPage,
    Object? ordersPageProjectId = _ordersPageProjectSentinel,
    String? ordersPageQuery,
    Object? ordersPageStatus = _ordersPageStatusSentinel,
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
      hasSuccessfulRequestsPage:
          hasSuccessfulRequestsPage ?? this.hasSuccessfulRequestsPage,
      requestsPageProjectId:
          identical(requestsPageProjectId, _requestsPageProjectSentinel)
              ? this.requestsPageProjectId
              : requestsPageProjectId as int?,
      requestsPageQuery: requestsPageQuery ?? this.requestsPageQuery,
      requestsPageStatus:
          identical(requestsPageStatus, _requestsPageStatusSentinel)
              ? this.requestsPageStatus
              : requestsPageStatus as String?,
      hasSuccessfulOrdersPage:
          hasSuccessfulOrdersPage ?? this.hasSuccessfulOrdersPage,
      ordersPageProjectId:
          identical(ordersPageProjectId, _ordersPageProjectSentinel)
              ? this.ordersPageProjectId
              : ordersPageProjectId as int?,
      ordersPageQuery: ordersPageQuery ?? this.ordersPageQuery,
      ordersPageStatus:
          identical(ordersPageStatus, _ordersPageStatusSentinel)
              ? this.ordersPageStatus
              : ordersPageStatus as String?,
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
const _requestsPageProjectSentinel = Object();
const _requestsPageStatusSentinel = Object();
const _ordersPageProjectSentinel = Object();
const _ordersPageStatusSentinel = Object();
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
      hasSuccessfulRequestsPage: false,
      requestsPageProjectId: null,
      requestsPageQuery: '',
      requestsPageStatus: null,
      hasSuccessfulOrdersPage: false,
      ordersPageProjectId: null,
      ordersPageQuery: '',
      ordersPageStatus: null,
    );
  }

  Future<void> loadSummary() async {
    if (!mounted) return;
    final summaryRevision = ++_summaryRevision;
    final contextRevision = _contextRevision;
    _requestsRevision++;
    _ordersRevision++;
    state = state.copyWith(
      isLoading: true,
      loadingRequests: false,
      loadingOrders: false,
      permissionDenied: false,
      malformedContract: false,
      error: null,
    );
    final projectId = state.projectId;

    try {
      final summary = await _repository.fetchSummary(projectId: projectId);
      if (contextRevision != _contextRevision ||
          summaryRevision != _summaryRevision ||
          !mounted) {
        return;
      }
      state = state.copyWith(isLoading: false, summary: summary, error: null);
      await Future.wait([_loadRequestPage(), _loadOrderPage()]);
    } catch (error) {
      if (contextRevision != _contextRevision ||
          summaryRevision != _summaryRevision ||
          !mounted) {
        return;
      }
      final preserveSummary =
          isSnapshotOffline(error) &&
          state.summary != null &&
          state.projectId == projectId;
      state = state.copyWith(
        isLoading: false,
        summary: preserveSummary ? state.summary : null,
        requests:
            preserveSummary
                ? state.requests
                : const ProcurementPage<ProcurementPurchaseRequestModel>(
                  items: [],
                  currentPage: 0,
                  lastPage: 0,
                  total: 0,
                ),
        hasSuccessfulRequestsPage:
            preserveSummary && state.hasSuccessfulRequestsPage,
        requestsPageProjectId:
            preserveSummary ? state.requestsPageProjectId : null,
        requestsPageQuery: preserveSummary ? state.requestsPageQuery : '',
        requestsPageStatus: preserveSummary ? state.requestsPageStatus : null,
        orders:
            preserveSummary
                ? state.orders
                : const ProcurementPage<ProcurementPurchaseOrderModel>(
                  items: [],
                  currentPage: 0,
                  lastPage: 0,
                  total: 0,
                ),
        hasSuccessfulOrdersPage:
            preserveSummary && state.hasSuccessfulOrdersPage,
        ordersPageProjectId: preserveSummary ? state.ordersPageProjectId : null,
        ordersPageQuery: preserveSummary ? state.ordersPageQuery : '',
        ordersPageStatus: preserveSummary ? state.ordersPageStatus : null,
        permissionDenied: _isPermissionDenied(error),
        malformedContract: error is FormatException,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<void> loadMoreRequests() async {
    if (state.loadingRequests ||
        state.requestsShowingPreviousQuery ||
        !state.requests.hasMore) {
      return;
    }
    final contextRevision = _contextRevision;
    final revision = _requestsRevision;
    final projectId = state.projectId;
    final query = state.requestQuery;
    final status = state.requestStatus;
    state = state.copyWith(loadingRequests: true, requestsError: null);
    try {
      final next = await _repository.fetchPurchaseRequests(
        projectId: projectId,
        page: state.requests.currentPage + 1,
        status: status,
        query: query,
      );
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision ||
          !mounted) {
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
        hasSuccessfulRequestsPage: true,
        requestsPageProjectId: projectId,
        requestsPageQuery: query,
        requestsPageStatus: status,
      );
    } catch (error) {
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision ||
          !mounted) {
        return;
      }
      if (isSnapshotOffline(error)) {
        state = state.copyWith(
          loadingRequests: false,
          requestsError: UserMessage.fromError(error),
        );
      } else {
        state = state.copyWith(
          loadingRequests: false,
          requestsError: UserMessage.fromError(error),
          requests: const ProcurementPage<ProcurementPurchaseRequestModel>(
            items: [],
            currentPage: 0,
            lastPage: 0,
            total: 0,
          ),
          hasSuccessfulRequestsPage: false,
          requestsPageProjectId: null,
          requestsPageQuery: '',
          requestsPageStatus: null,
        );
      }
    }
  }

  Future<void> loadMoreOrders() async {
    if (state.loadingOrders ||
        state.ordersShowingPreviousQuery ||
        !state.orders.hasMore) {
      return;
    }
    final contextRevision = _contextRevision;
    final revision = _ordersRevision;
    final projectId = state.projectId;
    final query = state.orderQuery;
    final status = state.orderStatus;
    state = state.copyWith(loadingOrders: true, ordersError: null);
    try {
      final next = await _repository.fetchPurchaseOrders(
        projectId: projectId,
        page: state.orders.currentPage + 1,
        status: status,
        query: query,
      );
      if (contextRevision != _contextRevision ||
          revision != _ordersRevision ||
          !mounted) {
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
        hasSuccessfulOrdersPage: true,
        ordersPageProjectId: projectId,
        ordersPageQuery: query,
        ordersPageStatus: status,
      );
    } catch (error) {
      if (contextRevision != _contextRevision ||
          revision != _ordersRevision ||
          !mounted) {
        return;
      }
      if (isSnapshotOffline(error)) {
        state = state.copyWith(
          loadingOrders: false,
          ordersError: UserMessage.fromError(error),
        );
      } else {
        state = state.copyWith(
          loadingOrders: false,
          ordersError: UserMessage.fromError(error),
          orders: const ProcurementPage<ProcurementPurchaseOrderModel>(
            items: [],
            currentPage: 0,
            lastPage: 0,
            total: 0,
          ),
          hasSuccessfulOrdersPage: false,
          ordersPageProjectId: null,
          ordersPageQuery: '',
          ordersPageStatus: null,
        );
      }
    }
  }

  Future<void> filterRequests({
    String? status,
    String? query,
    bool clearStatus = false,
  }) async {
    if (!mounted) return;
    _requestsRevision++;
    state = state.copyWith(
      requestStatus: clearStatus ? null : status ?? state.requestStatus,
      requestQuery: query ?? state.requestQuery,
    );
    await _loadRequestPage();
  }

  Future<void> filterOrders({
    String? status,
    String? query,
    bool clearStatus = false,
  }) async {
    if (!mounted) return;
    _ordersRevision++;
    state = state.copyWith(
      orderStatus: clearStatus ? null : status ?? state.orderStatus,
      orderQuery: query ?? state.orderQuery,
    );
    await _loadOrderPage();
  }

  Future<void> _loadRequestPage() async {
    final contextRevision = _contextRevision;
    final revision = _requestsRevision;
    final projectId = state.projectId;
    final query = state.requestQuery;
    final status = state.requestStatus;
    state = state.copyWith(loadingRequests: true, requestsError: null);
    try {
      final page = await _repository.fetchPurchaseRequests(
        projectId: projectId,
        status: status,
        query: query,
      );
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision ||
          !mounted) {
        return;
      }
      state = state.copyWith(
        requests: page,
        loadingRequests: false,
        requestsError: null,
        hasSuccessfulRequestsPage: true,
        requestsPageProjectId: projectId,
        requestsPageQuery: query,
        requestsPageStatus: status,
      );
    } catch (error) {
      if (contextRevision != _contextRevision ||
          revision != _requestsRevision ||
          !mounted) {
        return;
      }
      final preservePage =
          isSnapshotOffline(error) &&
          state.hasSuccessfulRequestsPage &&
          state.requestsPageProjectId == projectId;
      if (preservePage) {
        state = state.copyWith(
          loadingRequests: false,
          requestsError: UserMessage.fromError(error),
        );
      } else {
        state = state.copyWith(
          loadingRequests: false,
          requestsError: UserMessage.fromError(error),
          requests: const ProcurementPage<ProcurementPurchaseRequestModel>(
            items: [],
            currentPage: 0,
            lastPage: 0,
            total: 0,
          ),
          hasSuccessfulRequestsPage: false,
          requestsPageProjectId: null,
          requestsPageQuery: '',
          requestsPageStatus: null,
        );
      }
    }
  }

  Future<void> _loadOrderPage() async {
    final contextRevision = _contextRevision;
    final revision = _ordersRevision;
    final projectId = state.projectId;
    final query = state.orderQuery;
    final status = state.orderStatus;
    state = state.copyWith(loadingOrders: true, ordersError: null);
    try {
      final page = await _repository.fetchPurchaseOrders(
        projectId: projectId,
        status: status,
        query: query,
      );
      if (contextRevision != _contextRevision ||
          revision != _ordersRevision ||
          !mounted) {
        return;
      }
      state = state.copyWith(
        orders: page,
        loadingOrders: false,
        ordersError: null,
        hasSuccessfulOrdersPage: true,
        ordersPageProjectId: projectId,
        ordersPageQuery: query,
        ordersPageStatus: status,
      );
    } catch (error) {
      if (contextRevision != _contextRevision ||
          revision != _ordersRevision ||
          !mounted) {
        return;
      }
      final preservePage =
          isSnapshotOffline(error) &&
          state.hasSuccessfulOrdersPage &&
          state.ordersPageProjectId == projectId;
      if (preservePage) {
        state = state.copyWith(
          loadingOrders: false,
          ordersError: UserMessage.fromError(error),
        );
      } else {
        state = state.copyWith(
          loadingOrders: false,
          ordersError: UserMessage.fromError(error),
          orders: const ProcurementPage<ProcurementPurchaseOrderModel>(
            items: [],
            currentPage: 0,
            lastPage: 0,
            total: 0,
          ),
          hasSuccessfulOrdersPage: false,
          ordersPageProjectId: null,
          ordersPageQuery: '',
          ordersPageStatus: null,
        );
      }
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
      ref.watch(
        authProvider.select(
          (state) => state is AuthAuthenticated ? state.sessionIdentity : null,
        ),
      );
      return ProcurementNotifier(ref.read(procurementRepositoryProvider));
    });
