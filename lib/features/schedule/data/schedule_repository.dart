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
}
