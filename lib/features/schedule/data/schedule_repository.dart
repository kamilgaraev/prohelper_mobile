import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'schedule_model.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class ScheduleRepository extends SyncQueueAwareRepository {
  ScheduleRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<ScheduleOverviewModel> fetchSchedules({required int projectId}) async {
    try {
      final response = await _dio.get(
        '/schedule',
        queryParameters: {'project_id': projectId},
      );
      final payload = MobileApiResponse.dataMap(response.data);

      if (payload.isNotEmpty) {
        return ScheduleOverviewModel.fromJson(payload);
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
      final payload = MobileApiResponse.dataMap(response.data);

      if (payload.isNotEmpty) {
        return ScheduleDetailsModel.fromJson(payload);
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
      return MobileApiResponse.dataList(
        response.data,
      ).map(DailyWorkPlanModel.fromJson).toList();
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
    required DailyWorkFactInput input,
  }) async {
    final requestPayload = input.toJson();

    try {
      final response = await _dio.patch(
        '/schedule/daily-plan-assignments/$assignmentId/fact',
        data: requestPayload,
      );
      final responsePayload = MobileApiResponse.dataMap(response.data);

      if (responsePayload.isNotEmpty) {
        return DailyWorkPlanAssignmentModel.fromJson(responsePayload);
      }

      throw const ApiException(
        'Сервер вернул пустой ответ по факту дневного задания.',
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'schedule',
            operationType: 'record_daily_work_fact',
            method: 'PATCH',
            endpoint: '/schedule/daily-plan-assignments/$assignmentId/fact',
            payload: requestPayload,
          ),
        );
      }

      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось зафиксировать факт дневного задания.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException(
        'Не удалось зафиксировать факт дневного задания.',
      );
    }
  }

  Future<void> createLinkedConstraintAction({
    required int constraintId,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/schedule/work-constraints/$constraintId/linked-action',
        data: {if (comment != null) 'comment': comment},
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
        data: {if (summaryComment != null) 'summary_comment': summaryComment},
      );
      final payload = MobileApiResponse.dataMap(response.data);

      if (payload.isNotEmpty) {
        return DailyWorkPlanModel.fromJson(payload);
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
