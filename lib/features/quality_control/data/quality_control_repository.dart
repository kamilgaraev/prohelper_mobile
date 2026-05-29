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

  Future<QualityDefectModel> createDefect(
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    final payload = Map<String, dynamic>.from(data);
    final normalizedPhotoPaths = _normalizePhotoPaths(photoPaths);
    for (var index = 0; index < normalizedPhotoPaths.length; index++) {
      payload['photos[$index][type]'] = 'before';
    }
    final attachments = _attachmentRefs(normalizedPhotoPaths);

    try {
      final Object requestData;

      if (normalizedPhotoPaths.isNotEmpty) {
        final formMap = <String, dynamic>{
          ...data.map((key, value) => MapEntry(key, _formValue(value))),
        };
        for (var index = 0; index < normalizedPhotoPaths.length; index++) {
          final path = normalizedPhotoPaths[index];
          formMap['photos[$index][type]'] = 'before';
          formMap['photos[$index][file]'] = await MultipartFile.fromFile(
            path,
            filename: _fileName(path),
          );
        }
        requestData = FormData.fromMap(formMap);
      } else {
        requestData = data;
      }

      final response = await _dio.post(
        '/quality-control/defects',
        data: requestData,
      );
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
            attachments: attachments,
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
    List<String> photoPaths = const [],
  }) async {
    final trimmedComment = comment?.trim();
    final normalizedPhotoPaths = _normalizePhotoPaths(photoPaths);
    final payload = <String, dynamic>{
      if (trimmedComment != null && trimmedComment.isNotEmpty)
        'comment': trimmedComment,
    };
    for (var index = 0; index < normalizedPhotoPaths.length; index++) {
      payload['photos[$index][type]'] = 'after';
    }
    final attachments = _attachmentRefs(normalizedPhotoPaths);

    try {
      final Object data;

      if (normalizedPhotoPaths.isNotEmpty) {
        final formMap = <String, dynamic>{
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
        };
        for (var index = 0; index < normalizedPhotoPaths.length; index++) {
          final path = normalizedPhotoPaths[index];
          formMap['photos[$index][type]'] = 'after';
          formMap['photos[$index][file]'] = await MultipartFile.fromFile(
            path,
            filename: _fileName(path),
          );
        }
        data = FormData.fromMap(formMap);
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

Object? _formValue(Object? value) {
  if (value is bool) {
    return value ? '1' : '0';
  }

  return value;
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? 'quality-result.jpg' : parts.last;
}

List<String> _normalizePhotoPaths(List<String> paths) {
  return paths
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

List<SyncAttachmentRef> _attachmentRefs(List<String> paths) {
  return [
    for (var index = 0; index < paths.length; index++)
      SyncAttachmentRef(
        field: 'photos[$index][file]',
        path: paths[index],
        filename: _fileName(paths[index]),
      ),
  ];
}
