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

  Future<SafetyDashboardModel> fetchDashboard({int? projectId}) async {
    try {
      final response = await _dio.get(
        '/safety-management/dashboard',
        queryParameters: {if (projectId != null) 'project_id': projectId},
      );

      return SafetyDashboardModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyAdmissionModel?> fetchMyAdmission({
    int? projectId,
    String workCategory = 'general',
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/my-admission',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          'work_category': workCategory,
        },
      );

      return SafetyAdmissionModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }

      throw ApiException.fromDio(error);
    }
  }

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

  Future<List<SafetyBriefingModel>> fetchBriefings({
    int? projectId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/briefings',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      return _list(response.data).map(SafetyBriefingModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyBriefingModel> fetchBriefing(int id) async {
    try {
      final response = await _dio.get('/safety-management/briefings/$id');

      return SafetyBriefingModel.fromJson(_object(response.data));
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

  Future<List<SafetyInspectionModel>> fetchInspections({
    int? projectId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/inspections',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      return _list(response.data).map(SafetyInspectionModel.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<SafetyInspectionFindingModel>> fetchInspectionFindings({
    int? projectId,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/safety-management/inspection-findings',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      return _list(
        response.data,
      ).map(SafetyInspectionFindingModel.fromJson).toList();
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
    Map<String, dynamic> data, {
    List<String> photoPaths = const [],
  }) async {
    final payload = Map<String, dynamic>.from(data);
    final attachments = _photoAttachments(photoPaths);
    try {
      final response = await _dio.post(
        '/safety-management/violations',
        data: await _withPhotos(data, photoPaths),
      );

      return SafetyViolationModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'safety',
            operationType: 'create_violation',
            method: 'POST',
            endpoint: '/safety-management/violations',
            payload: payload,
            attachments: attachments,
          ),
        );
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyInspectionFindingModel> createInspectionFinding(
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);

    try {
      final response = await _dio.post(
        '/safety-management/inspection-findings',
        data: data,
      );

      return SafetyInspectionFindingModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        await queueAndThrow(
          SyncQueueDraft(
            moduleSlug: 'safety',
            operationType: 'create_inspection_finding',
            method: 'POST',
            endpoint: '/safety-management/inspection-findings',
            payload: payload,
          ),
        );
      }

      throw ApiException.fromDio(error);
    }
  }

  Future<SafetyViolationModel> resolveViolation(
    int id,
    String comment, {
    List<String> photoPaths = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/safety-management/violations/$id/resolve',
        data: await _withPhotos({
          'resolution_comment': comment.trim(),
        }, photoPaths),
      );

      return SafetyViolationModel.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Object> _withPhotos(
    Map<String, dynamic> data,
    List<String> photoPaths,
  ) async {
    if (photoPaths.isEmpty) {
      return data;
    }

    final formData = FormData();
    for (final entry in data.entries) {
      if (entry.value != null) {
        formData.fields.add(MapEntry(entry.key, _formValue(entry.value)));
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
      .map((path) {
        final separator = path.lastIndexOf(RegExp(r'[/\\]'));
        return SyncAttachmentRef(
          field: 'photos[]',
          path: path,
          filename: path.substring(separator + 1),
        );
      })
      .toList(growable: false);

  String _formValue(Object value) =>
      value is bool ? (value ? '1' : '0') : value.toString();

  String _fileName(String path) {
    final separator = path.lastIndexOf(RegExp(r'[/\\]'));
    return path.substring(separator + 1);
  }

  Future<SafetyBriefingModel> signBriefingParticipant({
    required int briefingId,
    required int participantId,
  }) async {
    try {
      final response = await _dio.post(
        '/safety-management/briefings/$briefingId/participants/$participantId/sign',
      );

      return SafetyBriefingModel.fromJson(_object(response.data));
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
