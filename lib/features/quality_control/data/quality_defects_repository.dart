import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
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

      return MobileApiResponse.dataList(
        response.data,
      ).map(QualityDefectModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<QualityDefectModel> fetchDefect(int id) async {
    try {
      final response = await _dio.get('/quality-control/defects/$id');
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<QualityDefectModel> createDefect(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/quality-control/defects', data: data);
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
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
      throw ApiException.fromDio(error);
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
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
