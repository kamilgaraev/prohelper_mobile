import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../domain/machinery_action.dart';
import 'machinery_operations_model.dart';

final machineryOperationsRepositoryProvider =
    Provider<MachineryOperationsRepository>((ref) {
      return MachineryOperationsRepository(
        ref.read(dioProvider),
        syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
      );
    });

const _machineryListPageSize = 100;
const _maxMachineryListPages = 100;

class MachineryOperationsRepository extends SyncQueueAwareRepository {
  MachineryOperationsRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<MachineryAssetModel>> fetchAssets({int? projectId}) async {
    try {
      final items = await _fetchAllPages('/machinery-operations/assets', {
        if (projectId != null) 'project_id': projectId,
      });

      return items.map(MachineryAssetModel.fromJson).toList();
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось загрузить технику.');
    }
  }

  Future<List<MachineryShiftReportModel>> fetchShiftReports({
    int? projectId,
  }) async {
    try {
      final items = await _fetchAllPages(
        '/machinery-operations/shift-reports',
        {if (projectId != null) 'project_id': projectId},
      );

      return items.map(MachineryShiftReportModel.fromJson).toList();
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось загрузить сменные рапорты.');
    }
  }

  Future<void> approveShiftReport(int shiftReportId) async {
    try {
      await _dio.post(
        '/machinery-operations/shift-reports/$shiftReportId/approve',
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось подтвердить рапорт.',
      );
    } catch (_) {
      throw const ApiException('Не удалось подтвердить рапорт.');
    }
  }

  Future<void> rejectShiftReport(int shiftReportId, String reason) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw const FormatException('Укажите причину отклонения.');
    }

    try {
      await _dio.post(
        '/machinery-operations/shift-reports/$shiftReportId/reject',
        data: {'reason': normalizedReason},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отклонить рапорт.',
      );
    } catch (_) {
      throw const ApiException('Не удалось отклонить рапорт.');
    }
  }

  Future<List<MachineryMaintenanceOrderModel>> fetchMaintenanceOrders({
    int? projectId,
  }) async {
    try {
      final items = await _fetchAllPages(
        '/machinery-operations/maintenance-orders',
        {if (projectId != null) 'project_id': projectId},
      );
      return items.map(MachineryMaintenanceOrderModel.fromJson).toList();
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось загрузить задания на ТО.');
    }
  }

  Future<Map<String, dynamic>?> executeAction(MachineryAction action) async {
    final payload = <String, dynamic>{
      ...action.payload,
      'idempotency_key': action.idempotencyKey,
    };

    try {
      final response = await _dio.request<dynamic>(
        action.endpoint,
        data: payload,
        options: Options(
          method: action.method,
          headers: {'Idempotency-Key': action.idempotencyKey},
        ),
      );
      final data = MobileApiResponse.dataMap(response.data);
      return data.isEmpty ? null : data;
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'machinery_operations',
            operationType: action.operationType,
            method: action.method,
            endpoint: action.endpoint,
            payload: payload,
          ),
          cause: error,
        );
      }
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось выполнить действие с техникой.');
    }
  }

  Future<MachineryShiftReportModel> createShiftReport({
    required int assetId,
    required int projectId,
    required String reportDate,
    double? plannedHours,
    required double actualHours,
    required double fuelConsumed,
    String? workDescription,
  }) async {
    final payload = <String, dynamic>{
      'asset_id': assetId,
      'project_id': projectId,
      'report_date': reportDate,
      if (plannedHours != null) 'planned_hours': plannedHours,
      'actual_hours': actualHours,
      'fuel_consumed': fuelConsumed,
      if (workDescription != null && workDescription.trim().isNotEmpty)
        'work_description': workDescription.trim(),
    };

    try {
      final response = await _dio.post(
        '/machinery-operations/shift-reports',
        data: payload,
      );

      return MachineryShiftReportModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'machinery_operations',
            operationType: 'create_shift_report',
            method: 'POST',
            endpoint: '/machinery-operations/shift-reports',
            payload: payload,
          ),
          cause: error,
        );
      }

      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось создать сменный рапорт.');
    }
  }

  Future<void> createDowntime({
    required int assetId,
    required int projectId,
    int? shiftReportId,
    required String reason,
    required String startedAt,
    required int durationMinutes,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/machinery-operations/downtimes',
        data: {
          'asset_id': assetId,
          'project_id': projectId,
          if (shiftReportId != null) 'shift_report_id': shiftReportId,
          'reason': reason.trim(),
          'started_at': startedAt,
          'duration_minutes': durationMinutes,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось зафиксировать простой.');
    }
  }

  Future<void> createFuelIssue({
    required int assetId,
    required int projectId,
    required int shiftReportId,
    required int warehouseId,
    required int materialId,
    required String issuedAt,
    required String fuelType,
    required double quantity,
    required String unit,
    String? comment,
  }) async {
    await executeAction(
      RecordFuelAction(
        assetId,
        projectId: projectId,
        shiftId: shiftReportId,
        warehouseId: warehouseId,
        materialId: materialId,
        issuedAt: DateTime.parse(issuedAt),
        fuelType: fuelType,
        quantity: quantity,
        unit: unit,
        comment: comment,
      ),
    );
  }

  Future<void> createProductionRecord({
    required int assetId,
    required int projectId,
    int? shiftReportId,
    required String recordedAt,
    required double quantity,
    required String unit,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/machinery-operations/production-records',
        data: {
          'asset_id': assetId,
          'project_id': projectId,
          if (shiftReportId != null) 'shift_report_id': shiftReportId,
          'recorded_at': recordedAt,
          'quantity': quantity,
          'unit': unit.trim(),
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось зафиксировать выработку.');
    }
  }

  List<Map<String, dynamic>> _list(dynamic responseData) {
    return machineryMapList(MobileApiResponse.dataList(responseData));
  }

  Future<List<Map<String, dynamic>>> _fetchAllPages(
    String path,
    Map<String, dynamic> filters,
  ) async {
    final result = <Map<String, dynamic>>[];
    final seenPages = <String>{};
    var page = 1;

    while (true) {
      if (page > _maxMachineryListPages) {
        throw const ApiException(
          'Не удалось загрузить данные раздела техники: превышен предел страниц.',
        );
      }

      final response = await _dio.get(
        path,
        queryParameters: {
          ...filters,
          'page': page,
          'per_page': _machineryListPageSize,
        },
      );
      final items = _list(response.data);
      if (items.isEmpty) break;

      if (!seenPages.add(jsonEncode(items))) {
        throw const ApiException(
          'Сервер повторил страницу данных раздела техники. Не удалось загрузить все записи.',
        );
      }

      result.addAll(items);
      if (items.length < _machineryListPageSize) break;
      page++;
    }

    return result;
  }

  Map<String, dynamic> _object(dynamic responseData) {
    return MobileApiResponse.dataMap(responseData);
  }
}
