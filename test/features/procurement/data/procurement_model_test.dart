import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';

import '../procurement_test_data.dart';

void main() {
  test('parses procurement summary contract', () {
    final summary = ProcurementSummaryModel.fromJson(procurementSummaryJson());

    expect(summary.counters.pendingApprovalsCount, 1);
    expect(summary.counters.receivableOrdersCount, 1);
    expect(summary.purchaseRequests.single.title, 'Поставка бетона');
    expect(summary.purchaseRequests.single.lines.single.quantity, 5);
    expect(summary.purchaseOrders.single.canReceiveMaterials, isTrue);
    expect(summary.purchaseOrders.single.canComment, isTrue);
    expect(summary.purchaseOrders.single.remainingQuantity, 3);
    expect(summary.purchaseOrders.single.pricingBreakdown?.totalAmount, 400000);
    expect(summary.assignedApprovals.single.canApprove, isTrue);
    expect(summary.assignedApprovals.single.contextSummary.deltaAmount, 50000);
    expect(summary.warehouses.single.name, 'Основной склад');
  });

  test('parses order detail with receipts and comments', () {
    final detail = ProcurementOrderDetailModel.fromJson(
      procurementOrderDetailJson(),
    );

    expect(detail.order.orderNumber, 'PO-61');
    expect(detail.order.items.single.materialName, 'Бетон М300');
    expect(detail.order.receipts.single.lines.single.totalAmount, 160000);
    expect(
      detail.order.comments.single.comment,
      'Поставка ожидается до обеда.',
    );
    expect(detail.warehouses.single.id, 44);
  });

  test('parses order pricing breakdown with delivery amount', () {
    final order = ProcurementPurchaseOrderModel.fromJson(
      procurementPurchaseOrderJson(
        subtotalAmount: 162500,
        deliveryAmount: 3,
      ),
    );

    expect(order.totalAmount, 162503);
    expect(order.pricingBreakdown?.subtotalAmount, 162500);
    expect(order.pricingBreakdown?.deliveryAmount, 3);
    expect(order.pricingBreakdown?.hasVisibleAdjustments, isTrue);
  });

  test('rejects malformed summary contract', () {
    final json = procurementSummaryJson()..remove('summary');

    expect(
      () => ProcurementSummaryModel.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
