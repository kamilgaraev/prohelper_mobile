import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'handover_acceptance_model.dart';

final handoverAcceptanceRepositoryProvider =
    Provider<HandoverAcceptanceRepository>((ref) {
      return HandoverAcceptanceRepository(
        ref.read(dioProvider),
        syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
      );
    });

class HandoverAcceptanceRepository extends SyncQueueAwareRepository {
  HandoverAcceptanceRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<AcceptanceScopeModel>> fetchScopes({
    int? projectId,
    String? status,
    String? plannedFrom,
    String? plannedTo,
  }) async {
    try {
      final response = await _dio.get(
        '/handover-acceptance/scopes',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (plannedFrom != null && plannedFrom.isNotEmpty)
            'planned_from': plannedFrom,
          if (plannedTo != null && plannedTo.isNotEmpty)
            'planned_to': plannedTo,
        },
      );

      return MobileApiResponse.dataList(
        response.data,
      ).map(AcceptanceScopeModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceScopeModel> fetchScope(int scopeId) async {
    try {
      final response = await _dio.get('/handover-acceptance/scopes/$scopeId');
      return AcceptanceScopeModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceChecklistModel> reviewChecklistItem(
    int itemId, {
    required String status,
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/checklist-items/$itemId/review',
        data: await _withPhotos({
          'status': status,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        }, photoPaths),
      );
      return AcceptanceChecklistModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<HandoverPackageModel> uploadPackageDocument(
    int documentId, {
    required String filePath,
  }) async {
    final attachment = SyncAttachmentRef(
      field: 'file',
      path: filePath,
      filename: _fileName(filePath),
    );

    try {
      final response = await _dio.post(
        '/handover-acceptance/package-documents/$documentId/upload',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            filePath,
            filename: _fileName(filePath),
          ),
        }),
      );

      return HandoverPackageModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'handover_acceptance',
            operationType: 'upload_package_document',
            method: 'POST',
            endpoint:
                '/handover-acceptance/package-documents/$documentId/upload',
            payload: const <String, dynamic>{},
            attachments: <SyncAttachmentRef>[attachment],
          ),
        );
      }

      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceFindingModel> createFinding(
    int sessionId,
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    final payload = Map<String, dynamic>.from(data);
    final attachments = _photoAttachments(photoPaths);

    try {
      final response = await _dio.post(
        '/handover-acceptance/sessions/$sessionId/findings',
        data: await _withPhotos(data, photoPaths),
      );
      return AcceptanceFindingModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'handover_acceptance',
            operationType: 'create_finding',
            method: 'POST',
            endpoint: '/handover-acceptance/sessions/$sessionId/findings',
            payload: payload,
            attachments: attachments,
          ),
        );
      }

      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceFindingModel> resolveFinding(
    int findingId, {
    required String resolutionComment,
    List<String> photoPaths = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/findings/$findingId/resolve',
        data: await _withPhotos({
          'resolution_comment': resolutionComment,
        }, photoPaths),
      );
      return AcceptanceFindingModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceScopeModel> readyForReinspection(int scopeId) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/ready-for-reinspection',
      );
      return AcceptanceScopeModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceScopeModel> startScope(int scopeId) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/start',
      );
      return AcceptanceScopeModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceScopeModel> acceptScope(
    int scopeId, {
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/accept',
        data: await _withPhotos({
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        }, photoPaths),
      );
      return AcceptanceScopeModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceScopeModel> handoverScope(int scopeId) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/handover',
      );
      return AcceptanceScopeModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceScopeModel> rejectScope(
    int scopeId, {
    required String reason,
    List<String> photoPaths = const [],
  }) async {
    return _scopeDecision(
      scopeId,
      path: 'reject',
      reason: reason,
      photoPaths: photoPaths,
    );
  }

  Future<AcceptanceScopeModel> reopenScope(
    int scopeId, {
    required String reason,
  }) async {
    return _scopeDecision(scopeId, path: 'reopen', reason: reason);
  }

  Future<AcceptanceScopeModel> _scopeDecision(
    int scopeId, {
    required String path,
    required String reason,
    List<String> photoPaths = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/$path',
        data: await _withPhotos({'reason': reason.trim()}, photoPaths),
      );
      return AcceptanceScopeModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Object> _withPhotos(
    Map<String, dynamic> data,
    List<String> photoPaths,
  ) async {
    if (photoPaths.isEmpty) return data;

    final formData = FormData();
    for (final entry in data.entries) {
      if (entry.value != null) {
        final value = entry.value;
        formData.fields.add(
          MapEntry(
            entry.key,
            value is bool ? (value ? '1' : '0') : value.toString(),
          ),
        );
      }
    }
    for (final path in photoPaths.take(5)) {
      formData.files.add(
        MapEntry(
          'photos[]',
          await MultipartFile.fromFile(path, filename: _fileName(path)),
        ),
      );
    }
    return formData;
  }

  List<SyncAttachmentRef> _photoAttachments(List<String> paths) => paths
      .take(5)
      .map(
        (path) => SyncAttachmentRef(
          field: 'photos[]',
          path: path,
          filename: _fileName(path),
        ),
      )
      .toList(growable: false);
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? 'handover-document.jpg' : parts.last;
}
