import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'schedule_model.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.read(dioProvider));
});

class ScheduleRepository {
  ScheduleRepository(this._dio);

  final Dio _dio;

  Future<ScheduleOverviewModel> fetchSchedules({required int projectId}) async {
    try {
      final response = await _dio.get(
        '/schedule',
        queryParameters: {
          'project_id': projectId,
        },
      );
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;

      if (payload is Map<String, dynamic>) {
        return ScheduleOverviewModel.fromJson(payload);
      }

      if (payload is Map) {
        return ScheduleOverviewModel.fromJson(
          payload.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const ApiException('Сервер вернул пустой ответ по графикам работ.');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить графики работ.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить графики работ.');
    }
  }

  Future<ScheduleDetailsModel> fetchScheduleDetails(int scheduleId) async {
    try {
      final response = await _dio.get('/schedule/$scheduleId');
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;

      if (payload is Map<String, dynamic>) {
        return ScheduleDetailsModel.fromJson(payload);
      }

      if (payload is Map) {
        return ScheduleDetailsModel.fromJson(
          payload.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const ApiException('Сервер вернул пустой ответ по графику работ.');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить детали графика работ.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить детали графика работ.');
    }
  }

  Future<List<DailyWorkPlanModel>> fetchDailyWorkPlans({
    required int projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/schedule/daily-plans',
        queryParameters: {'project_id': projectId},
      );
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;

      return (payload as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (plan) => DailyWorkPlanModel.fromJson(
              plan.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить дневные планы работ.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить дневные планы работ.');
    }
  }

  Future<DailyWorkPlanAssignmentModel> recordDailyWorkFact({
    required int assignmentId,
    required String status,
    required double completedQuantity,
    required double actualWorkHours,
    String? factComment,
    String? failureReason,
  }) async {
    try {
      final response = await _dio.patch(
        '/schedule/daily-plan-assignments/$assignmentId/fact',
        data: {
          'status': status,
          'completed_quantity': completedQuantity,
          'actual_work_hours': actualWorkHours,
          if (factComment != null) 'fact_comment': factComment,
          if (failureReason != null) 'failure_reason': failureReason,
        },
      );
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;

      if (payload is Map<String, dynamic>) {
        return DailyWorkPlanAssignmentModel.fromJson(payload);
      }

      if (payload is Map) {
        return DailyWorkPlanAssignmentModel.fromJson(
          payload.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const ApiException('Сервер вернул пустой ответ по факту дневного задания.');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось зафиксировать факт дневного задания.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось зафиксировать факт дневного задания.');
    }
  }

  Future<void> createLinkedConstraintAction({
    required int constraintId,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/schedule/work-constraints/$constraintId/linked-action',
        data: {
          if (comment != null) 'comment': comment,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать действие по препятствию.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось создать действие по препятствию.');
    }
  }

  Future<DailyWorkPlanModel> submitDailyWorkPlan({
    required int dailyPlanId,
    String? summaryComment,
  }) async {
    try {
      final response = await _dio.post(
        '/schedule/daily-plans/$dailyPlanId/submit',
        data: {
          if (summaryComment != null) 'summary_comment': summaryComment,
        },
      );
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;

      if (payload is Map<String, dynamic>) {
        return DailyWorkPlanModel.fromJson(payload);
      }

      if (payload is Map) {
        return DailyWorkPlanModel.fromJson(
          payload.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const ApiException('Сервер вернул пустой ответ по дневному плану.');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось передать дневной план на приемку.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось передать дневной план на приемку.');
    }
  }
}
