import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'companion_module_model.dart';

final companionModuleRepositoryProvider = Provider<CompanionModuleRepository>((
  ref,
) {
  return CompanionModuleRepository(ref.read(dioProvider));
});

class CompanionModuleRepository {
  CompanionModuleRepository(this._dio);

  final Dio _dio;

  Future<CompanionModuleListModel> fetchList({
    required String moduleSlug,
    int? projectId,
    String? status,
    String? query,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/companions/$moduleSlug',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.trim().isNotEmpty)
            'status': status.trim(),
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          'per_page': perPage,
        },
      );

      return CompanionModuleListModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<CompanionModuleDetailModel> fetchDetail({
    required String moduleSlug,
    required int id,
  }) async {
    try {
      final response = await _dio.get('/companions/$moduleSlug/$id');

      return CompanionModuleDetailModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<CompanionModuleDetailModel> executeAction({
    required String moduleSlug,
    required int id,
    required String action,
    String? comment,
  }) async {
    final trimmedComment = comment?.trim();

    try {
      final response = await _dio.post(
        '/companions/$moduleSlug/$id/actions/$action',
        data: {
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
        },
      );

      return CompanionModuleDetailModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
