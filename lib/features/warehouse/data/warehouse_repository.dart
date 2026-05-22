import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'project_material_delivery_model.dart';
import 'warehouse_scan_model.dart';
import 'warehouse_summary_model.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class WarehouseRepository extends SyncQueueAwareRepository {
  WarehouseRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<WarehouseSummaryModel> fetchWarehouseSummary() async {
    try {
      final response = await _dio.get('/warehouse');
      final payload = _extractData(response.data);

      if (payload.isEmpty) {
        throw const ApiException('Сервер вернул пустой ответ по складу.');
      }

      return WarehouseSummaryModel.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить данные по складу.',
      );
    }
  }

  Future<List<WarehouseBalanceModel>> fetchBalances(int warehouseId) async {
    try {
      final response = await _dio.get(
        '/warehouse/warehouses/$warehouseId/balances',
      );
      final payload = _extractList(response.data);

      return payload.map(WarehouseBalanceModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить остатки склада.',
      );
    }
  }

  Future<List<WarehouseMaterialOption>> searchMaterials(
    String query, {
    int limit = 10,
  }) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return const <WarehouseMaterialOption>[];
    }

    try {
      final response = await _dio.get(
        '/warehouse/materials/autocomplete',
        queryParameters: {'q': normalizedQuery, 'limit': limit},
      );
      final payload = _extractList(response.data);

      return payload.map(WarehouseMaterialOption.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось найти материалы для оприходования.',
      );
    }
  }

  Future<List<ProjectMaterialDeliveryModel>> fetchProjectMaterialDeliveries({
    int? projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/warehouse/project-material-deliveries',
        queryParameters: <String, dynamic>{
          if (projectId != null) 'project_id': projectId,
        },
      );
      final payload = _extractList(response.data);

      return payload.map(ProjectMaterialDeliveryModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить ожидаемые материалы.',
      );
    }
  }

  Future<ProjectMaterialStockModel> fetchProjectMaterialStock({
    int? projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/warehouse/project-material-deliveries/project-stock',
        queryParameters: <String, dynamic>{
          if (projectId != null) 'project_id': projectId,
        },
      );

      return ProjectMaterialStockModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить остатки материалов на объекте.',
      );
    }
  }

  Future<ProjectMaterialDeliveryModel> fetchProjectMaterialDelivery(
    int deliveryId,
  ) async {
    try {
      final response = await _dio.get(
        '/warehouse/project-material-deliveries/$deliveryId',
      );

      return ProjectMaterialDeliveryModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить поставку материала.',
      );
    }
  }

  Future<ProjectMaterialDeliveryModel> receiveProjectMaterialDelivery({
    required int deliveryId,
    required double quantity,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/warehouse/project-material-deliveries/$deliveryId/receive',
        data: <String, dynamic>{
          'quantity': quantity,
          if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
        },
      );

      return ProjectMaterialDeliveryModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось подтвердить приемку материала.',
      );
    }
  }

  Future<void> createReceipt(WarehouseReceiptPayload payload) async {
    final receiptPayload = <String, dynamic>{
      'warehouse_id': payload.warehouseId.toString(),
      'material_id': payload.materialId.toString(),
      'quantity': payload.quantity.toString(),
      'price': payload.price.toString(),
      if (payload.projectId != null) 'project_id': payload.projectId.toString(),
      if ((payload.documentNumber ?? '').trim().isNotEmpty)
        'document_number': payload.documentNumber!.trim(),
      if ((payload.reason ?? '').trim().isNotEmpty)
        'reason': payload.reason!.trim(),
      if (payload.metadata.isNotEmpty) 'metadata': jsonEncode(payload.metadata),
    };
    final attachments =
        payload.photos
            .map(
              (path) => SyncAttachmentRef(
                field: 'photos[]',
                path: path,
                filename: _fileNameFromPath(path),
              ),
            )
            .toList();

    try {
      final formData = FormData.fromMap({
        ...receiptPayload,
        'photos[]': await Future.wait(
          payload.photos.map(
            (path) =>
                MultipartFile.fromFile(path, filename: _fileNameFromPath(path)),
          ),
        ),
      });

      final response = await _dio.post(
        '/warehouse/operations/receipt',
        data: formData,
      );
      final data = _extractData(response.data);

      _requirePositiveInt(data, 'movement_id');
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'warehouse',
            operationType: 'create_receipt',
            method: 'POST',
            endpoint: '/warehouse/operations/receipt',
            payload: receiptPayload,
            attachments: attachments,
          ),
        );
      }

      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось выполнить оприходование.',
      );
    }
  }

  Future<WarehouseScanResultModel> resolveScan(
    WarehouseScanPayload payload,
  ) async {
    try {
      final response = await _dio.post(
        '/warehouse/scan/resolve',
        data: payload.toJson(),
      );

      return WarehouseScanResultModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось распознать отсканированный код.',
      );
    }
  }

  Future<List<WarehouseTaskModel>> fetchTasks(
    int warehouseId, {
    String? status,
    String? taskType,
    String? priority,
    String? entityType,
    int? entityId,
    String? query,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/warehouse/warehouses/$warehouseId/tasks',
        queryParameters: <String, dynamic>{
          if ((status ?? '').trim().isNotEmpty) 'status': status,
          if ((taskType ?? '').trim().isNotEmpty) 'task_type': taskType,
          if ((priority ?? '').trim().isNotEmpty) 'priority': priority,
          if ((entityType ?? '').trim().isNotEmpty) 'entity_type': entityType,
          if (entityId != null) 'entity_id': entityId,
          if ((query ?? '').trim().isNotEmpty) 'q': query,
          'limit': limit,
        },
      );

      final payload = _extractList(response.data);
      return payload.map(WarehouseTaskModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить задачи склада.',
      );
    }
  }

  Future<WarehouseTaskModel> fetchTask(int warehouseId, int taskId) async {
    try {
      final response = await _dio.get(
        '/warehouse/warehouses/$warehouseId/tasks/$taskId',
      );

      return WarehouseTaskModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить карточку складской задачи.',
      );
    }
  }

  Future<WarehouseTaskModel> updateTaskStatus(
    int warehouseId,
    int taskId,
    WarehouseTaskStatusPayload payload,
  ) async {
    try {
      final response = await _dio.post(
        '/warehouse/warehouses/$warehouseId/tasks/$taskId/status',
        data: payload.toJson(),
      );

      return WarehouseTaskModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось обновить статус складской задачи.',
      );
    }
  }

  Future<WarehouseTransferResultModel> createTransfer(
    WarehouseTransferPayload payload,
  ) async {
    try {
      final response = await _dio.post(
        '/warehouse/operations/transfer',
        data: payload.toJson(),
      );

      return WarehouseTransferResultModel.fromJson(_extractData(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось выполнить перемещение по складу.',
      );
    }
  }

  Future<List<WarehousePhotoModel>> getMovementPhotos(int movementId) async {
    return _loadPhotos('/warehouse/movements/$movementId/photos');
  }

  Future<List<WarehousePhotoModel>> uploadMovementPhotos(
    int movementId,
    List<String> photoPaths,
  ) async {
    return _uploadPhotos('/warehouse/movements/$movementId/photos', photoPaths);
  }

  Future<void> deleteMovementPhoto(int movementId, int fileId) async {
    await _deletePhoto('/warehouse/movements/$movementId/photos/$fileId');
  }

  Future<List<WarehousePhotoModel>> getBalancePhotos(
    int warehouseId,
    int materialId,
  ) async {
    return _loadPhotos('/warehouse/balances/$warehouseId/$materialId/photos');
  }

  Future<List<WarehousePhotoModel>> uploadBalancePhotos(
    int warehouseId,
    int materialId,
    List<String> photoPaths,
  ) async {
    return _uploadPhotos(
      '/warehouse/balances/$warehouseId/$materialId/photos',
      photoPaths,
    );
  }

  Future<void> deleteBalancePhoto(
    int warehouseId,
    int materialId,
    int fileId,
  ) async {
    await _deletePhoto(
      '/warehouse/balances/$warehouseId/$materialId/photos/$fileId',
    );
  }

  Future<List<WarehousePhotoModel>> _loadPhotos(String path) async {
    try {
      final response = await _dio.get(path);
      final payload = _extractList(response.data);

      return payload.map(WarehousePhotoModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить фотографии.',
      );
    }
  }

  Future<List<WarehousePhotoModel>> _uploadPhotos(
    String path,
    List<String> photoPaths,
  ) async {
    final attachments =
        photoPaths
            .map(
              (photoPath) => SyncAttachmentRef(
                field: 'photos[]',
                path: photoPath,
                filename: _fileNameFromPath(photoPath),
              ),
            )
            .toList();

    try {
      final formData = FormData.fromMap({
        'photos[]': await Future.wait(
          photoPaths.map(
            (photoPath) => MultipartFile.fromFile(
              photoPath,
              filename: _fileNameFromPath(photoPath),
            ),
          ),
        ),
      });

      final response = await _dio.post(path, data: formData);
      final payload = _extractList(response.data);

      return payload.map(WarehousePhotoModel.fromJson).toList();
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'warehouse',
            operationType: 'upload_photos',
            method: 'POST',
            endpoint: path,
            payload: const <String, dynamic>{},
            attachments: attachments,
          ),
        );
      }

      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить фотографии.',
      );
    }
  }

  Future<void> _deletePhoto(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось удалить фотографию.',
      );
    }
  }

  Map<String, dynamic> _extractData(dynamic responseData) {
    return MobileApiResponse.dataMap(responseData);
  }

  List<Map<String, dynamic>> _extractList(dynamic responseData) {
    return MobileApiResponse.dataList(responseData);
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', Platform.pathSeparator);
    final segments = normalized.split(Platform.pathSeparator);

    return segments.isEmpty ? 'photo.jpg' : segments.last;
  }

  void _requirePositiveInt(Map<String, dynamic> data, String key) {
    final raw = data[key];
    final value =
        raw is int
            ? raw
            : raw is num
            ? raw.toInt()
            : int.tryParse(raw?.toString() ?? '');

    if (value == null || value <= 0) {
      throw FormatException('Warehouse receipt field "$key" is required.');
    }
  }
}
