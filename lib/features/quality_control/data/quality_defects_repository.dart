import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'quality_defect_model.dart';

final qualityDefectsRepositoryProvider = Provider<QualityDefectsRepository>((
  ref,
) {
  return QualityDefectsRepository(ref.read(dioProvider));
});

class QualityDefectsRepository {
  QualityDefectsRepository(this._dio);

  final Dio _dio;

  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? severity,
  }) async {
    try {
      final response = await _dio.get(
        '/quality-control/defects',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (status != null) 'status': status,
          if (projectId != null) 'project_id': projectId,
          if (severity != null) 'severity': severity,
        },
      );

      final data = response.data['data'];
      final List<dynamic> items;

      if (data is Map && data['items'] is List) {
        items = data['items'] as List<dynamic>;
      } else if (data is List) {
        items = data;
      } else {
        items = const [];
      }

      return items
          .whereType<Map>()
          .map(
            (item) => QualityDefectModel.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить дефекты качества.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить дефекты качества.');
    }
  }

  Future<QualityDefectModel> fetchDefect(int id) async {
    try {
      final response = await _dio.get('/quality-control/defects/$id');
      return QualityDefectModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить дефект качества.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить дефект качества.');
    }
  }

  Future<QualityDefectModel> createDefect(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/quality-control/defects', data: data);
      return QualityDefectModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать дефект качества.',
      );
    } catch (_) {
      throw const ApiException('Не удалось создать дефект качества.');
    }
  }

  Future<QualityDefectModel> startDefect(int id, {String? comment}) async {
    try {
      final response = await _dio.post(
        '/quality-control/defects/$id/start',
        data: {
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
      return QualityDefectModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось взять дефект в работу.',
      );
    } catch (_) {
      throw const ApiException('Не удалось взять дефект в работу.');
    }
  }

  Future<QualityDefectModel> resolveDefect(int id, {String? comment}) async {
    try {
      final response = await _dio.post(
        '/quality-control/defects/$id/resolve',
        data: {
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
      return QualityDefectModel.fromJson(response.data['data']);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить дефект на проверку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось отправить дефект на проверку.');
    }
  }
}
