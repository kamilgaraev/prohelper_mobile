import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'quality_defect_model.dart';

final qualityControlRepositoryProvider = Provider<QualityControlRepository>((
  ref,
) {
  return QualityControlRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class QualityControlRepository extends SyncQueueAwareRepository {
  QualityControlRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<QualityDefectModel>> fetchDefects({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '/quality-control/defects',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (severity != null && severity.isNotEmpty) 'severity': severity,
          if (overdueOnly) 'overdue': 1,
        },
      );

      return MobileApiResponse.dataList(
        response.data,
      ).map(QualityDefectModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<QualityDefectModel> createDefect(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);

    try {
      final response = await _dio.post('/quality-control/defects', data: data);
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'quality_control',
            operationType: 'create_defect',
            method: 'POST',
            endpoint: '/quality-control/defects',
            payload: payload,
          ),
        );
      }

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

  Future<QualityDefectModel> resolveDefect(
    int id, {
    String? comment,
    String? photoPath,
  }) async {
    final trimmedComment = comment?.trim();
    final trimmedPhotoPath = photoPath?.trim();
    final payload = <String, dynamic>{
      if (trimmedComment != null && trimmedComment.isNotEmpty)
        'comment': trimmedComment,
      if (trimmedPhotoPath != null && trimmedPhotoPath.isNotEmpty)
        'photos[0][type]': 'after',
    };
    final attachments =
        trimmedPhotoPath != null && trimmedPhotoPath.isNotEmpty
            ? <SyncAttachmentRef>[
              SyncAttachmentRef(
                field: 'photos[0][file]',
                path: trimmedPhotoPath,
                filename: _fileName(trimmedPhotoPath),
              ),
            ]
            : const <SyncAttachmentRef>[];

    try {
      final Object data;

      if (trimmedPhotoPath != null && trimmedPhotoPath.isNotEmpty) {
        data = FormData.fromMap({
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
          'photos[0][type]': 'after',
          'photos[0][file]': await MultipartFile.fromFile(
            trimmedPhotoPath,
            filename: _fileName(trimmedPhotoPath),
          ),
        });
      } else {
        data = {
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
        };
      }

      final response = await _dio.post(
        '/quality-control/defects/$id/resolve',
        data: data,
      );
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'quality_control',
            operationType: 'resolve_defect',
            method: 'POST',
            endpoint: '/quality-control/defects/$id/resolve',
            payload: payload,
            attachments: attachments,
          ),
        );
      }

      throw ApiException.fromDio(error);
    }
  }

  Future<QualityDefectModel> verifyDefect(int id, {String? comment}) async {
    try {
      final response = await _dio.post(
        '/quality-control/defects/$id/verify',
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

  Future<QualityDefectModel> rejectDefect(
    int id, {
    required String comment,
  }) async {
    try {
      final response = await _dio.post(
        '/quality-control/defects/$id/reject',
        data: {'comment': comment.trim()},
      );
      return QualityDefectModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? 'quality-result.jpg' : parts.last;
}
