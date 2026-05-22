import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';
import 'package:prohelpers_mobile/features/procurement/domain/procurement_provider.dart';

import '../procurement_test_data.dart';

class _RecordingProcurementRepository extends ProcurementRepository {
  _RecordingProcurementRepository({this.error}) : super(Dio());

  final Object? error;

  int? loadedProjectId;
  int? fetchedOrderId;
  int? receivedOrderId;
  int? receivedWarehouseId;
  String? receivedReceiptDate;
  List<ProcurementReceiveItemPayload> receivedItems = const [];
  int? commentedOrderId;
  String? orderComment;
  int? approvedApprovalId;
  String? approvedComment;
  int? rejectedApprovalId;
  String? rejectionComment;
  int refreshCount = 0;

  @override
  Future<ProcurementSummaryModel> fetchSummary({int? projectId}) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }

    loadedProjectId = projectId;
    refreshCount++;
    return ProcurementSummaryModel.fromJson(procurementSummaryJson());
  }

  @override
  Future<ProcurementOrderDetailModel> fetchOrder(int id) async {
    fetchedOrderId = id;
    return ProcurementOrderDetailModel.fromJson(procurementOrderDetailJson());
  }

  @override
  Future<ProcurementPurchaseOrderModel> receiveMaterials({
    required int orderId,
    required int warehouseId,
    required List<ProcurementReceiveItemPayload> items,
    required String receiptDate,
    String? notes,
  }) async {
    receivedOrderId = orderId;
    receivedWarehouseId = warehouseId;
    receivedReceiptDate = receiptDate;
    receivedItems = items;
    return ProcurementPurchaseOrderModel.fromJson(
      procurementPurchaseOrderJson(
        status: 'partially_delivered',
        receivedQuantity: 5,
        remainingQuantity: 0,
      ),
    );
  }

  @override
  Future<ProcurementPurchaseOrderModel> addOrderComment({
    required int orderId,
    required String comment,
  }) async {
    commentedOrderId = orderId;
    orderComment = comment;
    return ProcurementPurchaseOrderModel.fromJson(
      procurementPurchaseOrderJson(),
    );
  }

  @override
  Future<ProcurementApprovalModel> approveApproval({
    required int id,
    String? comment,
  }) async {
    approvedApprovalId = id;
    approvedComment = comment;
    return ProcurementApprovalModel.fromJson(
      procurementApprovalJson(status: 'approved', actions: const []),
    );
  }

  @override
  Future<ProcurementApprovalModel> rejectApproval({
    required int id,
    required String comment,
  }) async {
    rejectedApprovalId = id;
    rejectionComment = comment;
    return ProcurementApprovalModel.fromJson(
      procurementApprovalJson(status: 'rejected', actions: const []),
    );
  }
}

void main() {
  test('loads summary for selected project', () async {
    final repository = _RecordingProcurementRepository();
    final notifier = ProcurementNotifier(repository)..syncProject(9);

    await notifier.loadSummary();

    expect(repository.loadedProjectId, 9);
    expect(notifier.state.summary?.purchaseOrders.single.orderNumber, 'PO-61');
    expect(notifier.state.error, isNull);
  });

  test('loads organization summary when project is not selected', () async {
    final repository = _RecordingProcurementRepository();
    final notifier = ProcurementNotifier(repository);

    await notifier.loadSummary();

    expect(repository.loadedProjectId, isNull);
    expect(
      notifier.state.summary?.purchaseRequests.single.requestNumber,
      'PR-12',
    );
  });

  test('runs procurement actions and refreshes summary', () async {
    final repository = _RecordingProcurementRepository();
    final notifier = ProcurementNotifier(repository)..syncProject(9);

    await notifier.receiveMaterials(
      orderId: 61,
      warehouseId: 44,
      receiptDate: '2026-05-22',
      items: const [
        ProcurementReceiveItemPayload(
          itemId: 701,
          quantityReceived: 3,
          price: 80000,
        ),
      ],
    );
    await notifier.addOrderComment(orderId: 61, comment: 'Комментарий');
    await notifier.approveApproval(id: 21, comment: 'Согласовано');
    await notifier.rejectApproval(id: 21, comment: 'Причина');

    expect(repository.receivedOrderId, 61);
    expect(repository.receivedWarehouseId, 44);
    expect(repository.receivedReceiptDate, '2026-05-22');
    expect(repository.receivedItems.single.itemId, 701);
    expect(repository.commentedOrderId, 61);
    expect(repository.orderComment, 'Комментарий');
    expect(repository.approvedApprovalId, 21);
    expect(repository.approvedComment, 'Согласовано');
    expect(repository.rejectedApprovalId, 21);
    expect(repository.rejectionComment, 'Причина');
    expect(repository.refreshCount, 4);
  });

  test('marks permission and malformed contract states', () async {
    final denied = ProcurementNotifier(
      _RecordingProcurementRepository(
        error: const ApiException('Нет доступа', statusCode: 403),
      ),
    );
    await denied.loadSummary();

    expect(denied.state.permissionDenied, isTrue);
    expect(denied.state.summary, isNull);

    final malformed = ProcurementNotifier(
      _RecordingProcurementRepository(error: const FormatException('bad data')),
    );
    await malformed.loadSummary();

    expect(malformed.state.malformedContract, isTrue);
    expect(malformed.state.summary, isNull);
  });

  test('loads order detail by id', () async {
    final repository = _RecordingProcurementRepository();
    final notifier = ProcurementNotifier(repository);

    final detail = await notifier.fetchOrder(61);

    expect(repository.fetchedOrderId, 61);
    expect(detail.order.items.single.materialName, 'Бетон М300');
  });
}
