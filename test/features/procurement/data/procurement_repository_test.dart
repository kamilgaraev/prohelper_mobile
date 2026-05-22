import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_model.dart';
import 'package:prohelpers_mobile/features/procurement/data/procurement_repository.dart';

import '../procurement_test_data.dart';

void main() {
  test('fetches procurement summary with project filter', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return _responseData(procurementSummaryJson());
    });

    final repository = ProcurementRepository(dio);
    final summary = await repository.fetchSummary(projectId: 9);

    expect(request.method, 'GET');
    expect(request.path, '/procurement/summary');
    expect(request.queryParameters['project_id'], 9);
    expect(summary.purchaseOrders.single.orderNumber, 'PO-61');
  });

  test('fetches purchase order detail', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return _responseData(procurementOrderDetailJson());
    });

    final repository = ProcurementRepository(dio);
    final detail = await repository.fetchOrder(61);

    expect(request.path, '/procurement/purchase-orders/61');
    expect(detail.order.items.single.remainingQuantity, 3);
    expect(detail.warehouses.single.name, 'Основной склад');
  });

  test(
    'sends receive materials with explicit warehouse date and items',
    () async {
      late RequestOptions request;
      late Map<String, dynamic> payload;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        payload = Map<String, dynamic>.from(options.data as Map);
        return _responseData(
          procurementPurchaseOrderJson(
            status: 'partially_delivered',
            receivedQuantity: 5,
            remainingQuantity: 0,
          ),
        );
      });

      final repository = ProcurementRepository(dio);
      final order = await repository.receiveMaterials(
        orderId: 61,
        warehouseId: 44,
        receiptDate: ' 2026-05-22 ',
        items: const [
          ProcurementReceiveItemPayload(
            itemId: 701,
            quantityReceived: 3,
            price: 80000,
          ),
        ],
        notes: ' Принята первая часть ',
      );

      expect(request.method, 'POST');
      expect(request.path, '/procurement/purchase-orders/61/receive-materials');
      expect(payload['warehouse_id'], 44);
      expect(payload['receipt_date'], '2026-05-22');
      expect(payload['notes'], 'Принята первая часть');
      expect((payload['items'] as List).single['item_id'], 701);
      expect(order.remainingQuantity, 0);
    },
  );

  test('sends comments and approval decisions with trimmed comments', () async {
    final requests = <RequestOptions>[];
    final payloads = <Map<String, dynamic>>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      payloads.add(Map<String, dynamic>.from(options.data as Map));

      if (options.path.contains('/purchase-orders/')) {
        return _responseData(procurementPurchaseOrderJson());
      }

      return _responseData(procurementApprovalJson(status: 'approved'));
    });

    final repository = ProcurementRepository(dio);
    await repository.addOrderComment(
      orderId: 61,
      comment: ' Поставка подтверждена ',
    );
    final approved = await repository.approveApproval(
      id: 21,
      comment: ' Согласовано ',
    );

    expect(requests.first.path, '/procurement/purchase-orders/61/comments');
    expect(payloads.first['comment'], 'Поставка подтверждена');
    expect(requests.last.path, '/procurement/approvals/21/approve');
    expect(payloads.last['comment'], 'Согласовано');
    expect(approved.status, 'approved');
  });

  test('rejects empty write inputs before network call', () async {
    var calls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      calls++;
      return _responseData(procurementPurchaseOrderJson());
    });

    final repository = ProcurementRepository(dio);

    expect(
      () => repository.addOrderComment(orderId: 61, comment: '   '),
      throwsArgumentError,
    );
    expect(
      () => repository.rejectApproval(id: 21, comment: '   '),
      throwsArgumentError,
    );
    expect(
      () => repository.receiveMaterials(
        orderId: 61,
        warehouseId: 44,
        receiptDate: '   ',
        items: const [
          ProcurementReceiveItemPayload(
            itemId: 701,
            quantityReceived: 3,
            price: 80000,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _responseData(Map<String, dynamic> data) {
  return {'success': true, 'message': null, 'data': data};
}
