import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'quality_defect_model.dart';

final qualityControlRepositoryProvider = Provider<QualityControlRepository>((
  ref,
) {
  return QualityControlRepository(ref.read(dioProvider));
});

class QualityControlRepository {
  QualityControlRepository(this._dio);

  final Dio _dio;

  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/quality-control/defects',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      return MobileApiResponse.dataList(
        response.data,
      ).map(QualityDefectModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить замечания по качеству.',
      );
    } catch (_) {
      throw const ApiException('Не удалось загрузить замечания по качеству.');
    }
  }

  Future<QualityDefectModel> createDefect(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/quality-control/defects', data: data);
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать замечание по качеству.',
      );
    } catch (_) {
      throw const ApiException('Не удалось создать замечание по качеству.');
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
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось взять замечание в работу.',
      );
    } catch (_) {
      throw const ApiException('Не удалось взять замечание в работу.');
    }
  }

  Future<QualityDefectModel> resolveDefect(
    int id, {
    String? comment,
    String? photoUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/quality-control/defects/$id/resolve',
        data: {
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
          if (photoUrl != null && photoUrl.trim().isNotEmpty)
            'photos': [
              {'type': 'after', 'url': photoUrl.trim()},
            ],
        },
      );
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить замечание на проверку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось отправить замечание на проверку.');
    }
  }
}
