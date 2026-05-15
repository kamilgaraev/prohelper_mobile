import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'safety_model.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(ref.read(dioProvider));
});

class SafetyRepository {
  SafetyRepository(this._dio);

  final Dio _dio;

  Future<List<SafetyWorkPermitModel>> fetchActivePermits({
    int? projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/work-permits/active',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(response.data).map(SafetyWorkPermitModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить активные наряды-допуски.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить активные наряды-допуски.');
    }
  }

  Future<List<SafetyIncidentModel>> fetchIncidents({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/safety-management/incidents',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(response.data).map(SafetyIncidentModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить происшествия.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить происшествия.');
    }
  }

  Future<List<SafetyViolationModel>> fetchViolations({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/safety-management/violations',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return _list(response.data).map(SafetyViolationModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить нарушения.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить нарушения.');
    }
  }

  Future<SafetyIncidentModel> createIncident(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '/safety-management/incidents',
        data: data,
      );

      return SafetyIncidentModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось зарегистрировать происшествие.',
      );
    } catch (_) {
      throw const ApiException('Не удалось зарегистрировать происшествие.');
    }
  }

  Future<SafetyViolationModel> createViolation(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/safety-management/violations',
        data: data,
      );

      return SafetyViolationModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось зарегистрировать нарушение.',
      );
    } catch (_) {
      throw const ApiException('Не удалось зарегистрировать нарушение.');
    }
  }

  Future<SafetyViolationModel> resolveViolation(int id, String comment) async {
    try {
      final response = await _dio.post(
        '/safety-management/violations/$id/resolve',
        data: {'resolution_comment': comment.trim()},
      );

      return SafetyViolationModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось устранить нарушение.',
      );
    } catch (_) {
      throw const ApiException('Не удалось устранить нарушение.');
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

    return list
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
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
