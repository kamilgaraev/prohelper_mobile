import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'design_package_model.dart';

final designPackageRepositoryProvider = Provider<DesignPackageRepository>(
  (ref) => DesignPackageRepository(ref.read(dioProvider)),
);

class DesignPackageRepository {
  DesignPackageRepository(this._dio);

  final Dio _dio;

  Future<DesignPackagePage> fetchList({
    required int projectId,
    int page = 1,
    int perPage = 20,
    String? status,
    String? query,
  }) async {
    try {
      final response = await _dio.get(
        '/pto/design-packages',
        queryParameters: {
          'project_id': projectId,
          'page': page,
          'per_page': perPage,
          if (status != null && status.trim().isNotEmpty)
            'status': status.trim(),
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      final envelope = MobileApiResponse.list(response.data);
      return DesignPackagePage.fromJson(envelope.data, envelope.meta);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<DesignPackageModel> fetchDetail(int id) async {
    try {
      final response = await _dio.get('/pto/design-packages/$id');
      return DesignPackageModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<DesignPackageModel> executeAction({
    required int id,
    required String action,
    String? comment,
  }) async {
    final trimmedComment = comment?.trim();
    try {
      final response = await _dio.post(
        '/pto/design-packages/$id/actions/$action',
        data: {
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
        },
      );
      return DesignPackageModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
