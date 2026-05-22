import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'workforce_attendance_model.dart';

final workforceRepositoryProvider = Provider<WorkforceRepository>((ref) {
  return WorkforceRepository(ref.read(dioProvider));
});

class WorkforceDuplicateScanException extends ApiException {
  const WorkforceDuplicateScanException(
    super.message, {
    super.statusCode = 409,
  });
}

class WorkforceDuplicateAttendanceException extends ApiException {
  const WorkforceDuplicateAttendanceException(
    super.message, {
    super.statusCode = 409,
  });
}

class WorkforceRepository {
  WorkforceRepository(this._dio);

  final Dio _dio;

  Future<AttendanceQrModel> issueAttendanceQr({
    int? projectId,
    required DateTime workDate,
  }) async {
    try {
      final response = await _dio.post(
        '/workforce/attendance/qr',
        data: {
          if (projectId != null) 'project_id': projectId,
          'work_date': _formatDate(workDate),
        },
      );

      return AttendanceQrModel.fromJson(
        workforceDataMap(response.data, 'workforce attendance QR'),
      );
    } on DioException catch (error) {
      throw _attendanceException(
        error,
        fallbackMessage: 'Не удалось получить QR-код для явки.',
      );
    }
  }

  Future<AttendanceScanResultModel> scanAttendanceQr({
    required String qrToken,
    String? deviceId,
  }) async {
    try {
      final response = await _dio.post(
        '/workforce/attendance/qr/scan',
        data: {
          'qr_token': qrToken,
          if (deviceId != null && deviceId.trim().isNotEmpty)
            'device_id': deviceId.trim(),
        },
      );

      return AttendanceScanResultModel.fromJson(
        workforceDataMap(response.data, 'workforce attendance scan'),
      );
    } on DioException catch (error) {
      throw _attendanceException(
        error,
        fallbackMessage: 'Не удалось подтвердить явку.',
      );
    }
  }

  Future<AttendanceScanResultModel> recordSelfAttendance({
    int? projectId,
    required DateTime workDate,
    String? deviceId,
  }) async {
    try {
      final response = await _dio.post(
        '/workforce/attendance/self',
        data: {
          if (projectId != null) 'project_id': projectId,
          'work_date': _formatDate(workDate),
          if (deviceId != null && deviceId.trim().isNotEmpty)
            'device_id': deviceId.trim(),
        },
      );

      return AttendanceScanResultModel.fromJson(
        workforceDataMap(response.data, 'workforce self attendance'),
      );
    } on DioException catch (error) {
      throw _attendanceException(
        error,
        fallbackMessage: 'Не удалось отметить явку.',
      );
    }
  }

  Future<AttendanceHistoryModel> fetchAttendanceHistory({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/workforce/attendance/history',
        queryParameters: {
          'date_from': _formatDate(dateFrom),
          'date_to': _formatDate(dateTo),
          if (projectId != null) 'project_id': projectId,
        },
      );

      return AttendanceHistoryModel.fromJson(
        workforceDataMap(response.data, 'workforce attendance history'),
      );
    } on DioException catch (error) {
      throw _attendanceException(
        error,
        fallbackMessage: 'Не удалось загрузить историю явки.',
      );
    }
  }

  ApiException _attendanceException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final apiException = ApiException.fromDio(
      error,
      fallbackMessage: fallbackMessage,
    );
    final code = _errorCode(error.response?.data);

    if (code == 'duplicate_scan') {
      return WorkforceDuplicateScanException(
        apiException.message,
        statusCode: apiException.statusCode ?? 409,
      );
    }

    if (code == 'duplicate_attendance') {
      return WorkforceDuplicateAttendanceException(
        apiException.message,
        statusCode: apiException.statusCode ?? 409,
      );
    }

    return apiException;
  }

  String? _errorCode(dynamic responseData) {
    final root = responseData is Map<String, dynamic> ? responseData : null;
    final errors = root?['errors'];

    if (errors is Map<String, dynamic>) {
      final code = errors['code'];

      if (code is String && code.trim().isNotEmpty) {
        return code.trim();
      }

      if (code is List && code.isNotEmpty) {
        final first = code.first;

        if (first is String && first.trim().isNotEmpty) {
          return first.trim();
        }
      }
    }

    return null;
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}
