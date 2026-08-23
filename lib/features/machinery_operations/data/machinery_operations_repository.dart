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

class MachineryOperationsRepository extends SyncQueueAwareRepository {
  MachineryOperationsRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<MachineryAssetModel>> fetchAssets({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/machinery-operations/assets',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(response.data).map(MachineryAssetModel.fromJson).toList();
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
      final response = await _dio.get(
        '/machinery-operations/shift-reports',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(
        response.data,
      ).map(MachineryShiftReportModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось загрузить сменные рапорты.');
    }
  }

  Future<List<MachineryMaintenanceOrderModel>> fetchMaintenanceOrders({
    int? projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/machinery-operations/maintenance-orders',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );
      return _list(
        response.data,
      ).map(MachineryMaintenanceOrderModel.fromJson).toList();
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

  Map<String, dynamic> _object(dynamic responseData) {
    return MobileApiResponse.dataMap(responseData);
  }
}
