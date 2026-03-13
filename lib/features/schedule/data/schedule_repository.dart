import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'schedule_summary_model.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.read(dioProvider));
});

class ScheduleRepository {
  ScheduleRepository(this._dio);

  final Dio _dio;

  Future<ScheduleSummaryModel> fetchSchedule({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/schedule',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
        },
      );
      final data = response.data;
      final payload = data is Map<String, dynamic> ? data['data'] : null;

      if (payload is Map<String, dynamic>) {
        return ScheduleSummaryModel.fromJson(payload);
      }

      if (payload is Map) {
        return ScheduleSummaryModel.fromJson(
          payload.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const ApiException('Сервер вернул пустой ответ по графику работ.');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить график работ.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить график работ.');
    }
  }
}
