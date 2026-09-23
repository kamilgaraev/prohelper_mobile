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
import '../domain/site_requests_scope.dart';
import 'site_request_model.dart';

final siteRequestsRepositoryProvider = Provider<SiteRequestsRepository>((ref) {
  return SiteRequestsRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class SiteRequestsRepository extends SyncQueueAwareRepository {
  SiteRequestsRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<SiteRequestModel>> fetchSiteRequests({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'per_page': perPage,
        'scope': scope.value,
        if (status != null) 'status': status,
        if (projectId != null) 'project_id': projectId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (urgentOnly) 'urgent': 1,
        if (assignedUserId != null) 'assigned_user_id': assignedUserId,
        if (requestType != null && requestType.isNotEmpty)
          'request_type': requestType,
        if (requiredFrom != null)
          'required_from': requiredFrom.toIso8601String().split('T').first,
        if (requiredTo != null)
          'required_to': requiredTo.toIso8601String().split('T').first,
      };

      final response = await _dio.get(
        '/site-requests',
        queryParameters: queryParams,
      );

      final list = MobileApiResponse.dataList(response.data);

      return list
          .whereType<Map>()
          .map(
            (item) => SiteRequestModel.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить заявки.',
      );
    }
  }

  Future<SiteRequestModel> fetchSiteRequestDetails(int id) async {
    try {
      final response = await _dio.get('/site-requests/$id');
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить детали заявки.',
      );
    }
  }

  Future<SiteRequestModel> createSiteRequest(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final idempotencyKey =
        payload.putIfAbsent('idempotency_key', _newIdempotencyKey).toString();

    try {
      final response = await _dio.post(
        '/site-requests',
        data: payload,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _parseSiteRequestResponse(
        MobileApiResponse.payload(response.data),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'site_requests',
            operationType: 'create_site_request',
            method: 'POST',
            endpoint: '/site-requests',
            payload: payload,
          ),
        );
      }

      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать заявку.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchAssignees(int requestId) async {
    try {
      final response = await _dio.get('/site-requests/$requestId/assignees');
      return MobileApiResponse.dataList(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить список исполнителей.',
      );
    }
  }

  Future<SiteRequestModel> assignSiteRequest(int requestId, int? userId) async {
    try {
      final response = await _dio.put(
        '/site-requests/$requestId/assignee',
        data: {'assigned_user_id': userId},
      );
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось назначить исполнителя.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchFiles(int requestId) async {
    try {
      final response = await _dio.get('/site-requests/$requestId/files');
      return MobileApiResponse.dataList(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить файлы заявки.',
      );
    }
  }

  Future<void> uploadFile(int requestId, String path) async {
    try {
      await _dio.post(
        '/site-requests/$requestId/files',
        data: FormData.fromMap({'file': await MultipartFile.fromFile(path)}),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить файл.',
      );
    }
  }

  Future<void> deleteFile(int requestId, int fileId) async {
    try {
      await _dio.delete('/site-requests/$requestId/files/$fileId');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось удалить файл.',
      );
    }
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  Future<SiteRequestModel> updateSiteRequest(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/site-requests/$id', data: data);
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось обновить заявку.',
      );
    }
  }

  Future<SiteRequestModel> updateSiteRequestGroup(
    int groupId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put(
        '/site-requests/groups/$groupId',
        data: data,
      );
      return _parseSiteRequestResponse(
        MobileApiResponse.payload(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось обновить группу заявок.',
      );
    }
  }

  Future<SiteRequestModel> submitSiteRequest(int id) async {
    try {
      final response = await _dio.post('/site-requests/$id/submit');
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить заявку.',
      );
    }
  }

  Future<SiteRequestModel> cancelSiteRequest(int id, {String? notes}) async {
    try {
      final response = await _dio.post(
        '/site-requests/$id/cancel',
        data: {if (notes != null) 'notes': notes},
      );
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отменить заявку.',
      );
    }
  }

  Future<SiteRequestModel> completeSiteRequest(int id, {String? notes}) async {
    try {
      final response = await _dio.post(
        '/site-requests/$id/complete',
        data: {if (notes != null) 'notes': notes},
      );
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось завершить заявку.',
      );
    }
  }

  Future<SiteRequestModel> changeSiteRequestStatus(
    int id,
    String status, {
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/site-requests/$id/status',
        data: {
          'status': status,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось изменить статус заявки.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchTemplates() async {
    try {
      final response = await _dio.get('/site-requests/templates');
      return MobileApiResponse.dataList(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить шаблоны.',
      );
    }
  }

  Future<SiteRequestModel> createFromTemplate(
    int templateId,
    int projectId,
  ) async {
    try {
      final response = await _dio.post(
        '/site-requests/from-template/$templateId',
        data: {'project_id': projectId},
      );
      return SiteRequestModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось создать заявку из шаблона.',
      );
    }
  }

  Future<Map<String, dynamic>> fetchMeta() async {
    try {
      final response = await _dio.get('/site-requests/meta');
      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить справочники.',
      );
    }
  }

  SiteRequestModel _parseSiteRequestResponse(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData['primary_request'] is Map<String, dynamic>) {
        return SiteRequestModel.fromJson(responseData['primary_request']);
      }

      if (responseData['requests'] is List &&
          (responseData['requests'] as List).isNotEmpty) {
        final first = (responseData['requests'] as List).first;
        if (first is Map<String, dynamic>) {
          return SiteRequestModel.fromJson(first);
        }
      }

      return SiteRequestModel.fromJson(responseData);
    }

    throw const ApiException('Не удалось обработать данные заявки.');
  }
}
