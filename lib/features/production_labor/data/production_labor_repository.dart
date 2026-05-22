import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'production_labor_model.dart';

final productionLaborRepositoryProvider = Provider<ProductionLaborRepository>((
  ref,
) {
  return ProductionLaborRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class ProductionLaborRepository extends SyncQueueAwareRepository {
  ProductionLaborRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<LaborWorkOrderModel>> fetchWorkOrders({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/production-labor/work-orders',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(response.data).map(LaborWorkOrderModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось загрузить наряды.');
    }
  }

  Future<LaborOutputModel> recordOutput({
    required int workOrderLineId,
    required double quantity,
    required double hours,
    required String workDate,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'work_order_line_id': workOrderLineId,
      'work_date': workDate,
      'quantity': quantity,
      'hours': hours,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    };

    try {
      final response = await _dio.post(
        '/production-labor/output-entries',
        data: payload,
      );

      return LaborOutputModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'production_labor',
            operationType: 'record_output',
            method: 'POST',
            endpoint: '/production-labor/output-entries',
            payload: payload,
          ),
        );
      }

      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось зафиксировать выработку.');
    }
  }

  Future<LaborTimesheetModel> createTimesheet({
    required int workOrderId,
    required int workOrderLineId,
    required double hours,
    required String shiftDate,
    required bool includeInPayroll,
    int? employeeId,
    String? workerName,
    String? safetyPermitReference,
  }) async {
    try {
      final response = await _dio.post(
        '/production-labor/timesheets',
        data: {
          'work_order_id': workOrderId,
          'shift_date': shiftDate,
          'entries': [
            {
              'work_order_line_id': workOrderLineId,
              'include_in_payroll': includeInPayroll,
              if (employeeId != null) 'employee_id': employeeId,
              if (workerName != null && workerName.trim().isNotEmpty)
                'worker_name': workerName.trim(),
              'hours': hours,
              if (safetyPermitReference != null &&
                  safetyPermitReference.trim().isNotEmpty)
                'safety_permit_reference': safetyPermitReference.trim(),
            },
          ],
        },
      );

      return LaborTimesheetModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (_) {
      throw const ApiException('Не удалось создать табель.');
    }
  }

  List<Map<String, dynamic>> _list(dynamic responseData) {
    return laborMapList(MobileApiResponse.dataList(responseData));
  }

  Map<String, dynamic> _object(dynamic responseData) {
    return MobileApiResponse.dataMap(responseData);
  }
}
