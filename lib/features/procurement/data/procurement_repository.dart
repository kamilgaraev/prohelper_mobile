import 'package:dio/dio.dart';
import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'procurement_model.dart';

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  return ProcurementRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class ProcurementRepository extends SyncQueueAwareRepository {
  ProcurementRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<ProcurementSummaryModel> fetchSummary({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/procurement/summary',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return ProcurementSummaryModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ProcurementPurchaseRequestModel> fetchPurchaseRequest(int id) async {
    try {
      final response = await _dio.get('/procurement/purchase-requests/$id');
      return ProcurementPurchaseRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить заявку на закупку.',
      );
    }
  }

  Future<ProcurementPurchaseRequestModel> createPurchaseRequest(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        '/procurement/purchase-requests',
        data: payload,
      );
      final data = MobileApiResponse.dataMap(response.data);
      final item = data['item'];
      if (item is! Map) {
        throw const FormatException('В ответе не найдена созданная заявка.');
      }
      return ProcurementPurchaseRequestModel.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать заявку на закупку.',
      );
    }
  }

  Future<ProcurementOrderDetailModel> fetchOrder(int id) async {
    try {
      final response = await _dio.get('/procurement/purchase-orders/$id');

      return ProcurementOrderDetailModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ProcurementPurchaseOrderModel> receiveMaterials({
    required int orderId,
    required int warehouseId,
    required List<ProcurementReceiveItemPayload> items,
    required String receiptDate,
    String? notes,
  }) async {
    if (warehouseId <= 0) {
      throw ArgumentError.value(warehouseId, 'warehouseId');
    }

    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items');
    }

    for (final item in items) {
      if (item.itemId <= 0 || item.quantityReceived <= 0 || item.price < 0) {
        throw ArgumentError.value(items, 'items');
      }
    }

    final trimmedReceiptDate = receiptDate.trim();
    if (trimmedReceiptDate.isEmpty) {
      throw ArgumentError.value(receiptDate, 'receiptDate');
    }

    final trimmedNotes = notes?.trim();
    final endpoint = '/procurement/purchase-orders/$orderId/receive-materials';
    final idempotencyKey = _newIdempotencyKey();
    final payload = <String, dynamic>{
      'warehouse_id': warehouseId,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'receipt_date': trimmedReceiptDate,
      if (trimmedNotes != null && trimmedNotes.isNotEmpty)
        'notes': trimmedNotes,
      'idempotency_key': idempotencyKey,
    };

    return executeOrQueue(
      request: () async {
        final response = await _dio.post(
          endpoint,
          data: payload,
          options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        );

        return ProcurementPurchaseOrderModel.fromJson(
          MobileApiResponse.dataMap(response.data),
        );
      },
      draft: SyncQueueDraft(
        moduleSlug: 'procurement',
        operationType: 'receive_materials',
        method: 'POST',
        endpoint: endpoint,
        payload: payload,
      ),
      businessMessage: 'Не удалось принять материалы.',
    );
  }

  Future<ProcurementPurchaseOrderModel> addOrderComment({
    required int orderId,
    required String comment,
  }) async {
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw ArgumentError.value(comment, 'comment');
    }

    try {
      final response = await _dio.post(
        '/procurement/purchase-orders/$orderId/comments',
        data: {'comment': trimmedComment},
      );

      return ProcurementPurchaseOrderModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ProcurementApprovalModel> approveApproval({
    required int id,
    String? comment,
  }) async {
    final trimmedComment = comment?.trim();

    try {
      final response = await _dio.post(
        '/procurement/approvals/$id/approve',
        data: {
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
        },
      );

      return ProcurementApprovalModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ProcurementApprovalModel> rejectApproval({
    required int id,
    required String comment,
  }) async {
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw ArgumentError.value(comment, 'comment');
    }

    try {
      final response = await _dio.post(
        '/procurement/approvals/$id/reject',
        data: {'comment': trimmedComment},
      );

      return ProcurementApprovalModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final Random _secureRandom = Random.secure();

String _newIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
