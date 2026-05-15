import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'production_labor_model.dart';

final productionLaborRepositoryProvider = Provider<ProductionLaborRepository>((
  ref,
) {
  return ProductionLaborRepository(ref.read(dioProvider));
});

class ProductionLaborRepository {
  ProductionLaborRepository(this._dio);

  final Dio _dio;

  Future<List<LaborWorkOrderModel>> fetchWorkOrders({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/production-labor/work-orders',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(response.data).map(LaborWorkOrderModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить наряды.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить наряды.');
    }
  }

  Future<LaborOutputModel> recordOutput({
    required int workOrderLineId,
    required double quantity,
    required double hours,
    required String workDate,
  }) async {
    try {
      final response = await _dio.post(
        '/production-labor/output-entries',
        data: {
          'work_order_line_id': workOrderLineId,
          'work_date': workDate,
          'quantity': quantity,
          'hours': hours,
        },
      );

      return LaborOutputModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось зафиксировать выработку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось зафиксировать выработку.');
    }
  }

  Future<LaborTimesheetModel> createTimesheet({
    required int workOrderId,
    required int workOrderLineId,
    required double hours,
    required String shiftDate,
    required String workerName,
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
              'worker_name': workerName,
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
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать табель.',
      );
    } catch (_) {
      throw const ApiException('Не удалось создать табель.');
    }
  }

  List<Map<String, dynamic>> _list(dynamic responseData) {
    final payload =
        responseData is Map<String, dynamic> ? responseData['data'] : null;
    final list =
        payload is List
            ? payload
            : payload is Map && payload['data'] is List
            ? payload['data'] as List
            : payload is Map && payload['items'] is List
            ? payload['items'] as List
            : const [];

    return laborMapList(list);
  }

  Map<String, dynamic> _object(dynamic responseData) {
    final payload =
        responseData is Map<String, dynamic>
            ? responseData['data']
            : responseData;

    if (payload is Map) {
      return payload.map((key, value) => MapEntry(key.toString(), value));
    }

    return const {};
  }
}
