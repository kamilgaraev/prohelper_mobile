import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'workflow_task_model.dart';

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  return WorkflowRepository(ref.read(dioProvider));
});

class WorkflowRepository {
  WorkflowRepository(this._dio);

  final Dio _dio;

  Future<WorkflowTaskListResult> fetchTasks({
    int page = 1,
    int perPage = 20,
    int? projectId,
    String? status,
    required bool assignedToMe,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/workflow-management/tasks',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (projectId != null) 'project_id': projectId,
          if (status != null && status.isNotEmpty) 'status': status,
          'assigned_to_me': assignedToMe ? 1 : 0,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );

      return WorkflowTaskListResult.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WorkflowTaskModel> fetchTask(int id) async {
    try {
      final response = await _dio.get('/workflow-management/tasks/$id');

      return WorkflowTaskModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WorkflowTaskModel> approveTask(int id, {String? comment}) async {
    try {
      final trimmedComment = comment?.trim();
      final response = await _dio.post(
        '/workflow-management/tasks/$id/approve',
        data: {
          if (trimmedComment != null && trimmedComment.isNotEmpty)
            'comment': trimmedComment,
        },
      );

      return WorkflowTaskModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WorkflowTaskModel> rejectTask({
    required int id,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason');
    }

    try {
      final response = await _dio.post(
        '/workflow-management/tasks/$id/reject',
        data: {'reason': trimmedReason},
      );

      return WorkflowTaskModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WorkflowTaskModel> requestChanges({
    required int id,
    required String comment,
  }) async {
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw ArgumentError.value(comment, 'comment');
    }

    try {
      final response = await _dio.post(
        '/workflow-management/tasks/$id/request-changes',
        data: {'comment': trimmedComment},
      );

      return WorkflowTaskModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WorkflowTaskModel> addComment({
    required int id,
    required String comment,
  }) async {
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw ArgumentError.value(comment, 'comment');
    }

    try {
      final response = await _dio.post(
        '/workflow-management/tasks/$id/comments',
        data: {'comment': trimmedComment},
      );

      return WorkflowTaskModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
