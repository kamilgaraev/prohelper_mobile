import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'procurement_model.dart';

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  return ProcurementRepository(ref.read(dioProvider));
});

class ProcurementRepository {
  ProcurementRepository(this._dio);

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

    try {
      final response = await _dio.post(
        '/procurement/purchase-orders/$orderId/receive-materials',
        data: {
          'warehouse_id': warehouseId,
          'items': items.map((item) => item.toJson()).toList(growable: false),
          'receipt_date': trimmedReceiptDate,
          if (trimmedNotes != null && trimmedNotes.isNotEmpty)
            'notes': trimmedNotes,
        },
      );

      return ProcurementPurchaseOrderModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
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
