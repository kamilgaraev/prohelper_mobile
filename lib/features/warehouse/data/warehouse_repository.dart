import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'warehouse_custody_model.dart';
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

  Future<List<WarehouseCustodyBalanceModel>> fetchCustodyBalances({
    int? projectId,
    int? responsibleUserId,
  }) async {
    try {
      final response = await _dio.get(
        '/warehouse/custody/balances',
        queryParameters: <String, dynamic>{
          if (projectId != null) 'project_id': projectId,
          if (responsibleUserId != null)
            'responsible_user_id': responsibleUserId,
        },
      );
      final payload = _extractList(response.data);

      return payload.map(WarehouseCustodyBalanceModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить материалы у ответственных.',
      );
    }
  }

  Future<void> issueToResponsible({
    required int projectId,
    required int projectWarehouseId,
    required int materialId,
    required int responsibleUserId,
    required double quantity,
    String? documentNumber,
    String? reason,
  }) async {
    const endpoint = '/warehouse/custody/issue';
    final idempotencyKey = _newWarehouseIdempotencyKey();
    final payload = <String, dynamic>{
      'project_id': projectId,
      'project_warehouse_id': projectWarehouseId,
      'material_id': materialId,
      'responsible_user_id': responsibleUserId,
      'quantity': quantity,
      if ((documentNumber ?? '').trim().isNotEmpty)
        'document_number': documentNumber!.trim(),
      if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
      'idempotency_key': idempotencyKey,
    };

    return executeOrQueue(
      request:
          () => _dio.post<void>(
            endpoint,
            data: payload,
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          ),
      draft: SyncQueueDraft(
        moduleSlug: 'warehouse',
        operationType: 'custody_issue',
        method: 'POST',
        endpoint: endpoint,
        payload: payload,
      ),
      businessMessage: 'Не удалось выдать материал ответственному.',
    );
  }

  Future<void> writeOff({
    required int warehouseId,
    required int materialId,
    required double quantity,
    String? documentNumber,
    required String reason,
  }) async {
    const endpoint = '/warehouse/operations/write-off';
    final idempotencyKey = _newWarehouseIdempotencyKey();
    final payload = <String, dynamic>{
      'warehouse_id': warehouseId,
      'material_id': materialId,
      'quantity': quantity,
      'reason': reason.trim(),
      if ((documentNumber ?? '').trim().isNotEmpty)
        'document_number': documentNumber!.trim(),
      'idempotency_key': idempotencyKey,
    };
    try {
      await _dio.post(
        endpoint,
        data: payload,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'warehouse',
            operationType: 'write_off',
            method: 'POST',
            endpoint: endpoint,
            payload: payload,
          ),
        );
      }
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось списать материал.',
      );
    }
  }

  Future<void> returnFromResponsible({
    required int projectId,
    required int custodyWarehouseId,
    required int materialId,
    required double quantity,
    String? documentNumber,
    String? reason,
  }) async {
    const endpoint = '/warehouse/custody/return';
    final idempotencyKey = _newWarehouseIdempotencyKey();
    final payload = <String, dynamic>{
      'project_id': projectId,
      'custody_warehouse_id': custodyWarehouseId,
      'material_id': materialId,
      'quantity': quantity,
      if ((documentNumber ?? '').trim().isNotEmpty)
        'document_number': documentNumber!.trim(),
      if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
      'idempotency_key': idempotencyKey,
    };

    return executeOrQueue(
      request:
          () => _dio.post<void>(
            endpoint,
            data: payload,
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          ),
      draft: SyncQueueDraft(
        moduleSlug: 'warehouse',
        operationType: 'custody_return',
        method: 'POST',
        endpoint: endpoint,
        payload: payload,
      ),
      businessMessage: 'Не удалось вернуть материал на объект.',
    );
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
    final endpoint =
        '/warehouse/project-material-deliveries/$deliveryId/receive';
    final idempotencyKey = _newWarehouseIdempotencyKey();
    final payload = <String, dynamic>{
      'idempotency_key': idempotencyKey,
      'quantity': quantity,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    };
    final response = await executeOrQueue(
      request:
          () => _dio.post(
            endpoint,
            data: payload,
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          ),
      draft: SyncQueueDraft(
        moduleSlug: 'warehouse',
        operationType: 'receive_project_delivery',
        method: 'POST',
        endpoint: endpoint,
        payload: payload,
      ),
      businessMessage: 'Не удалось подтвердить приемку материала.',
    );

    return ProjectMaterialDeliveryModel.fromJson(_extractData(response.data));
  }

  Future<void> createReceipt(WarehouseReceiptPayload payload) async {
    final idempotencyKey = _newWarehouseIdempotencyKey();
    final receiptPayload = <String, dynamic>{
      'idempotency_key': idempotencyKey,
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
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
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
    const endpoint = '/warehouse/operations/transfer';
    final idempotencyKey = _newWarehouseIdempotencyKey();
    final requestPayload = <String, dynamic>{
      ...payload.toJson(),
      'idempotency_key': idempotencyKey,
    };

    final response = await executeOrQueue(
      request:
          () => _dio.post(
            endpoint,
            data: requestPayload,
            options: Options(headers: {'Idempotency-Key': idempotencyKey}),
          ),
      draft: SyncQueueDraft(
        moduleSlug: 'warehouse',
        operationType: 'create_transfer',
        method: 'POST',
        endpoint: endpoint,
        payload: requestPayload,
      ),
      businessMessage: 'Не удалось выполнить перемещение по складу.',
    );

    return WarehouseTransferResultModel.fromJson(_extractData(response.data));
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

final Random _warehouseSecureRandom = Random.secure();

String _newWarehouseIdempotencyKey() {
  final bytes = List<int>.generate(
    16,
    (_) => _warehouseSecureRandom.nextInt(256),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
