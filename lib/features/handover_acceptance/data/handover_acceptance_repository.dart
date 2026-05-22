import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'handover_acceptance_model.dart';

final handoverAcceptanceRepositoryProvider =
    Provider<HandoverAcceptanceRepository>((ref) {
      return HandoverAcceptanceRepository(ref.read(dioProvider));
    });

class HandoverAcceptanceRepository {
  HandoverAcceptanceRepository(this._dio);

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
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/checklist-items/$itemId/review',
        data: {
          'status': status,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
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
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceFindingModel> createFinding(
    int sessionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/sessions/$sessionId/findings',
        data: data,
      );
      return AcceptanceFindingModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AcceptanceFindingModel> resolveFinding(
    int findingId, {
    required String resolutionComment,
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/findings/$findingId/resolve',
        data: {'resolution_comment': resolutionComment},
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
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/accept',
        data: {
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
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
  }) async {
    return _scopeDecision(scopeId, path: 'reject', reason: reason);
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
  }) async {
    try {
      final response = await _dio.post(
        '/handover-acceptance/scopes/$scopeId/$path',
        data: {'reason': reason.trim()},
      );
      return AcceptanceScopeModel.fromJson(
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
  return parts.isEmpty ? 'handover-document.jpg' : parts.last;
}
