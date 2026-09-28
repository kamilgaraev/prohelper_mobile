import 'dart:math';

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
    return (await fetchDefectPayloads(
      page: page,
      perPage: perPage,
      projectId: projectId,
      status: status,
      severity: severity,
      overdueOnly: overdueOnly,
    )).map(QualityDefectModel.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> fetchDefectPayloads({
    int page = 1,
    int perPage = 50,
    int? projectId,
    String? status,
    String? severity,
    bool overdueOnly = false,
  }) async {
    try {
      final defects = <Map<String, dynamic>>[];
      var currentPage = page;
      int? lastPage;

      while (lastPage == null || currentPage <= lastPage) {
        final response = await _dio.get(
          '/quality-control/defects',
          queryParameters: {
            'page': currentPage,
            'per_page': perPage,
            if (projectId != null) 'project_id': projectId,
            if (status != null && status.isNotEmpty) 'status': status,
            if (severity != null && severity.isNotEmpty) 'severity': severity,
            if (overdueOnly) 'overdue': 1,
          },
        );
        final result = MobileApiResponse.list(response.data);
        defects.addAll(result.data);

        final responseLastPage = _paginationValue(result.meta['last_page']);
        if (responseLastPage != null) {
          lastPage = responseLastPage;
          if (currentPage < lastPage && result.data.isEmpty) {
            throw const FormatException(
              'Страница дефектов пуста, хотя сервер сообщает о следующих страницах.',
            );
          }
        } else if (result.data.length < perPage) {
          break;
        }

        currentPage++;
      }

      return defects;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<QualityDefectModel> createDefect(
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    final payload = Map<String, dynamic>.from(data);
    final idempotencyKey =
        payload.putIfAbsent('idempotency_key', _newIdempotencyKey).toString();
    final normalizedPhotoPaths = _normalizePhotoPaths(photoPaths);
    for (var index = 0; index < normalizedPhotoPaths.length; index++) {
      payload['photos[$index][type]'] = 'before';
    }
    final attachments = _attachmentRefs(normalizedPhotoPaths);

    try {
      final Object requestData;

      if (normalizedPhotoPaths.isNotEmpty) {
        final formMap = <String, dynamic>{
          ...payload.map((key, value) => MapEntry(key, _formValue(value))),
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
        requestData = payload;
      }

      final response = await _dio.post(
        '/quality-control/defects',
        data: requestData,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
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
          cause: error,
        );
      }

      throw ApiException.fromDio(error);
    }
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  Future<QualityDefectModel> fetchDefect(int id) async {
    return QualityDefectModel.fromJson(await fetchDefectPayload(id));
  }

  Future<Map<String, dynamic>> fetchDefectPayload(int id) async {
    try {
      final response = await _dio.get('/quality-control/defects/$id');

      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<QualityAssigneeModel>> fetchAssignees(int defectId) async {
    try {
      final response = await _dio.get(
        '/quality-control/defects/$defectId/assignees',
      );
      return MobileApiResponse.dataList(
        response.data,
      ).map(QualityAssigneeModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить список сотрудников.',
      );
    }
  }

  Future<void> assignDefect(
    int id, {
    required int userId,
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/quality-control/defects/$id/assign',
        data: {
          'assigned_to': userId,
          if ((comment ?? '').trim().isNotEmpty) 'comment': comment!.trim(),
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось назначить ответственного.',
      );
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
    final idempotencyKey = _newIdempotencyKey();
    payload['idempotency_key'] = idempotencyKey;
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
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
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
          cause: error,
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

int? _paginationValue(Object? value) {
  if (value is int) {
    return value > 0 ? value : null;
  }
  if (value is num) {
    final integer = value.toInt();
    return integer > 0 ? integer : null;
  }
  if (value is String) {
    final integer = int.tryParse(value);
    return integer != null && integer > 0 ? integer : null;
  }
  return null;
}

class QualityAssigneeModel {
  const QualityAssigneeModel({
    required this.id,
    required this.name,
    this.email,
  });
  final int id;
  final String name;
  final String? email;

  factory QualityAssigneeModel.fromJson(Map<String, dynamic> json) =>
      QualityAssigneeModel(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        email: json['email']?.toString(),
      );
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
