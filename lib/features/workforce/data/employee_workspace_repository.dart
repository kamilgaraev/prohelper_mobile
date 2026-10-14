import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'employee_workspace_model.dart';

final employeeWorkspaceRepositoryProvider =
    Provider<EmployeeWorkspaceRepository>(
      (ref) => EmployeeWorkspaceRepository(ref.read(dioProvider)),
    );

class EmployeeWorkspaceRepository {
  EmployeeWorkspaceRepository(this._dio);
  final Dio _dio;

  Future<EmployeeWorkspaceModel> fetch(String month, {String? workDate}) async {
    try {
      final response = await _dio.get(
        '/workforce/self-service',
        queryParameters: {
          'month': month,
          if (workDate != null) 'work_date': workDate,
        },
      );
      return EmployeeWorkspaceModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<EmployeeRequestPageModel> fetchRequests({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/workforce/self-service/requests',
        queryParameters: {'page': page, 'per_page': 50},
      );
      final result = MobileApiResponse.list(response.data);
      return EmployeeRequestPageModel(
        requests:
            result.data
                .map(
                  (value) => EmployeeRequestModel.fromJson(
                    Map<String, dynamic>.from(value as Map),
                  ),
                )
                .toList(),
        currentPage: (result.meta['current_page'] as num).toInt(),
        lastPage: (result.meta['last_page'] as num).toInt(),
        total: (result.meta['total'] as num).toInt(),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> submit({
    required String idempotencyKey,
    required String kind,
    required String dateFrom,
    required String dateTo,
    required String basis,
    required Map<String, dynamic> requestedData,
  }) async {
    try {
      await _dio.post(
        '/workforce/self-service/requests',
        data: {
          'idempotency_key': idempotencyKey,
          'kind': kind,
          'date_from': dateFrom,
          'date_to': dateTo,
          'basis': basis,
          'requested_data': requestedData,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Uri> download(int documentId) async {
    try {
      final response = await _dio.get(
        '/workforce/self-service/documents/$documentId/download',
      );
      final payload = MobileApiResponse.dataMap(response.data);
      final uri = Uri.parse(payload['url'] as String);
      if (uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Неверный адрес документа.');
      }
      return uri;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
