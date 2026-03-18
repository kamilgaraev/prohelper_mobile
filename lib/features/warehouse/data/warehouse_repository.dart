import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'warehouse_scan_model.dart';
import 'warehouse_summary_model.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(ref.read(dioProvider));
});

class WarehouseRepository {
  WarehouseRepository(this._dio);

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
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить данные по складу.');
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

  Future<WarehouseMovementModel> createReceipt(
    WarehouseReceiptPayload payload,
  ) async {
    try {
      final formData = FormData.fromMap({
        'warehouse_id': payload.warehouseId.toString(),
        'material_id': payload.materialId.toString(),
        'quantity': payload.quantity.toString(),
        'price': payload.price.toString(),
        if (payload.projectId != null)
          'project_id': payload.projectId.toString(),
        if ((payload.documentNumber ?? '').trim().isNotEmpty)
          'document_number': payload.documentNumber!.trim(),
        if ((payload.reason ?? '').trim().isNotEmpty)
          'reason': payload.reason!.trim(),
        if (payload.metadata.isNotEmpty)
          'metadata': jsonEncode(payload.metadata),
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

      return WarehouseMovementModel.fromJson({
        'id': data['movement_id'],
        'movement_type': 'receipt',
        'movement_type_label': 'Приход',
        'quantity': payload.quantity,
        'price': payload.price,
        'document_number': payload.documentNumber,
        'reason': payload.reason,
        'photo_gallery': data['photo_gallery'] ?? const [],
      });
    } on DioException catch (error) {
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
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];

      if (data is Map<String, dynamic>) {
        return data;
      }

      if (data is Map) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
    }

    if (responseData is Map) {
      return responseData.map((key, value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(dynamic responseData) {
    dynamic payload;

    if (responseData is Map<String, dynamic>) {
      payload = responseData['data'];
    } else {
      payload = responseData;
    }

    if (payload is! List) {
      return const <Map<String, dynamic>>[];
    }

    return payload.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', Platform.pathSeparator);
    final segments = normalized.split(Platform.pathSeparator);

    return segments.isEmpty ? 'photo.jpg' : segments.last;
  }
}
