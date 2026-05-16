import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import 'workforce_attendance_model.dart';

final workforceRepositoryProvider = Provider<WorkforceRepository>((ref) {
  return WorkforceRepository(ref.read(dioProvider));
});

class WorkforceRepository {
  WorkforceRepository(this._dio);

  final Dio _dio;

  Future<AttendanceQrModel> issueAttendanceQr({
    int? projectId,
    DateTime? workDate,
  }) async {
    try {
      final response = await _dio.post(
        '/workforce/attendance/qr',
        data: {
          if (projectId != null) 'project_id': projectId,
          if (workDate != null)
            'work_date': workDate.toIso8601String().split('T').first,
        },
      );

      return AttendanceQrModel.fromJson(workforceObject(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось получить QR-код для явки.',
      );
    } catch (_) {
      throw const ApiException('Не удалось получить QR-код для явки.');
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

      return AttendanceScanResultModel.fromJson(workforceObject(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось подтвердить явку.',
      );
    } catch (_) {
      throw const ApiException('Не удалось подтвердить явку.');
    }
  }
}
