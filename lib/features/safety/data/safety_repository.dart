import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_repository.dart';
import '../../../core/sync/sync_queue_service.dart';
import 'safety_model.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(
    ref.read(dioProvider),
    syncQueueServiceFuture: ref.read(syncQueueServiceProvider.future),
  );
});

class SafetyRepository extends SyncQueueAwareRepository {
  SafetyRepository(
    this._dio, {
    Future<SyncQueueService>? syncQueueServiceFuture,
  }) : super(syncQueueServiceFuture);

  final Dio _dio;

  Future<List<SafetyWorkPermitModel>> fetchPermits({
    int? projectId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/work-permits',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null) 'status': status,
        },
      );

      return _list(response.data).map(SafetyWorkPermitModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyWorkPermitModel> fetchPermit(int id) async {
    try {
      final response = await _dio.get('/safety-management/work-permits/$id');

      return SafetyWorkPermitModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<SafetyIncidentModel>> fetchIncidents({
    int? projectId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/incidents',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      return _list(response.data).map(SafetyIncidentModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<SafetyViolationModel>> fetchViolations({
    int? projectId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/violations',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      return _list(response.data).map(SafetyViolationModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyIncidentModel> createIncident(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);

    try {
      final response = await _dio.post(
        '/safety-management/incidents',
        data: data,
      );

      return SafetyIncidentModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'safety',
            operationType: 'create_incident',
            method: 'POST',
            endpoint: '/safety-management/incidents',
            payload: payload,
          ),
        );
      }

      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyViolationModel> createViolation(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/safety-management/violations',
        data: data,
      );

      return SafetyViolationModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyViolationModel> resolveViolation(int id, String comment) async {
    try {
      final response = await _dio.post(
        '/safety-management/violations/$id/resolve',
        data: {'resolution_comment': comment.trim()},
      );

      return SafetyViolationModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyWorkPermitModel> submitPermit(int id) {
    return _permitAction(id, 'submit');
  }

  Future<SafetyWorkPermitModel> approvePermit(
    int id, {
    String? approvalComment,
  }) {
    final comment = approvalComment?.trim();

    return _permitAction(
      id,
      'approve',
      data: {
        if (comment != null && comment.isNotEmpty) 'approval_comment': comment,
      },
    );
  }

  Future<SafetyWorkPermitModel> activatePermit(int id) {
    return _permitAction(id, 'activate');
  }

  Future<SafetyWorkPermitModel> suspendPermit(
    int id, {
    required String reason,
  }) {
    return _permitAction(id, 'suspend', data: {'reason': reason.trim()});
  }

  Future<SafetyWorkPermitModel> resumePermit(int id) {
    return _permitAction(id, 'resume');
  }

  Future<SafetyWorkPermitModel> rejectPermit(int id, {required String reason}) {
    return _permitAction(id, 'reject', data: {'reason': reason.trim()});
  }

  Future<SafetyWorkPermitModel> closePermit(
    int id, {
    required String closeComment,
  }) {
    return _permitAction(
      id,
      'close',
      data: {'close_comment': closeComment.trim()},
    );
  }

  Future<SafetyWorkPermitModel> _permitAction(
    int id,
    String action, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(
        '/safety-management/work-permits/$id/$action',
        data: data,
      );

      return SafetyWorkPermitModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  List<Map<String, dynamic>> _list(dynamic responseData) {
    return MobileApiResponse.dataList(responseData);
  }

  Map<String, dynamic> _object(dynamic responseData) {
    return MobileApiResponse.dataMap(responseData);
  }
}
