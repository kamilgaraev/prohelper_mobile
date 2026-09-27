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
  static const _workOrdersPerPage = 50;
  static const _maxWorkOrderPages = 1000;

  ProductionLaborRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<LaborWorkOrderModel>> fetchWorkOrders({int? projectId}) async {
    return (await fetchWorkOrderPayloads(
      projectId: projectId,
    )).map(LaborWorkOrderModel.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> fetchWorkOrderPayloads({
    int? projectId,
  }) async {
    try {
      final workOrders = <Map<String, dynamic>>[];
      final firstPage = await _fetchWorkOrderPage(1, projectId);
      workOrders.addAll(firstPage.data);

      final lastPage = _paginationPage(_lastPageValue(firstPage.meta));
      if (lastPage == null || lastPage <= 1) {
        return workOrders;
      }
      if (lastPage > _maxWorkOrderPages) {
        throw const FormatException('Слишком много страниц нарядов.');
      }

      for (var page = 2; page <= lastPage; page++) {
        final result = await _fetchWorkOrderPage(page, projectId);
        if (result.data.isEmpty) {
          throw const FormatException(
            'Страница нарядов пуста, хотя сервер сообщает о следующих страницах.',
          );
        }
        workOrders.addAll(result.data);
      }

      return workOrders;
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
    required String idempotencyKey,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'idempotency_key': idempotencyKey,
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
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
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
          cause: error,
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

  Future<MobileApiResponse<List<Map<String, dynamic>>>> _fetchWorkOrderPage(
    int page,
    int? projectId,
  ) async {
    final response = await _dio.get(
      '/production-labor/work-orders',
      queryParameters: {
        'page': page,
        'per_page': _workOrdersPerPage,
        if (projectId != null) 'project_id': projectId,
      },
    );
    final result = MobileApiResponse.list(response.data);
    return MobileApiResponse(
      success: result.success,
      data: laborMapList(result.data),
      message: result.message,
      meta: result.meta,
    );
  }

  int? _paginationPage(dynamic value) {
    final page = switch (value) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };
    return page != null && page > 0 ? page : null;
  }

  dynamic _lastPageValue(Map<String, dynamic> meta) {
    final nestedMeta = meta['meta'];
    if (nestedMeta is Map) {
      return nestedMeta['last_page'];
    }
    return meta['last_page'];
  }

  Map<String, dynamic> _object(dynamic responseData) {
    return MobileApiResponse.dataMap(responseData);
  }
}

String newProductionLaborOutputIdempotencyKey() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
