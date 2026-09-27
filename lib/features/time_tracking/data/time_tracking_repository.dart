import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'time_entry_model.dart';

final timeTrackingRepositoryProvider = Provider<TimeTrackingRepository>((ref) {
  return TimeTrackingRepository(ref.read(dioProvider));
});

class TimeTrackingRepository {
  TimeTrackingRepository(this._dio);

  final Dio _dio;

  Future<DailyTimeSummaryModel> fetchDailySummary({
    required String date,
    required int projectId,
  }) async {
    return DailyTimeSummaryModel.fromJson(
      await fetchDailySummaryPayload(date: date, projectId: projectId),
    );
  }

  Future<Map<String, dynamic>> fetchDailySummaryPayload({
    required String date,
    required int projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/time-tracking/daily-summary',
        queryParameters: {'date': date, 'project_id': projectId},
      );

      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryListResult> fetchEntries({
    int page = 1,
    int perPage = 20,
    int? projectId,
    String? date,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '/time-tracking/entries',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (projectId != null) 'project_id': projectId,
          if (date != null) 'date': date,
          if (status != null) 'status': status,
        },
      );

      return TimeEntryListResult.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> fetchEntry(int id) async {
    return TimeEntryModel.fromJson(await fetchEntryPayload(id));
  }

  Future<Map<String, dynamic>> fetchEntryPayload(int id) async {
    try {
      final response = await _dio.get('/time-tracking/entries/$id');

      return MobileApiResponse.dataMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<TimeEntryModel>> fetchPendingApprovals({
    required int projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/time-tracking/pending-approvals',
        queryParameters: {'project_id': projectId, 'per_page': 100},
      );
      return MobileApiResponse.dataList(response.data)
          .map(TimeEntryModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> decideApproval({
    required int id,
    required String action,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '/time-tracking/entries/$id/$action',
        data: reason == null ? null : {'reason': reason},
      );
      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> startTimer({
    required int projectId,
    required String workDate,
    required String startTime,
    required String title,
    required bool isBillable,
    required String idempotencyKey,
    String? description,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title');
    }

    try {
      final response = await _dio.post(
        '/time-tracking/timer/start',
        data: {
          'project_id': projectId,
          'work_date': workDate,
          'start_time': _normalizeTime(startTime),
          'title': trimmedTitle,
          'is_billable': isBillable,
          if (_hasText(description)) 'description': description!.trim(),
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      if (_isAmbiguousWriteFailure(error)) {
        throw const TimeTrackingWriteUncertainException();
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> createManualEntry({
    required int projectId,
    required String workDate,
    required double hoursWorked,
    required String title,
    required bool isBillable,
    required String idempotencyKey,
    String? startTime,
    String? endTime,
    double? breakTime,
    String? description,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title');
    }

    try {
      final response = await _dio.post(
        '/time-tracking/entries',
        data: {
          'project_id': projectId,
          'work_date': workDate,
          'hours_worked': hoursWorked,
          'title': trimmedTitle,
          'is_billable': isBillable,
          if (_hasText(startTime)) 'start_time': _normalizeTime(startTime!),
          if (_hasText(endTime)) 'end_time': _normalizeTime(endTime!),
          if (breakTime != null) 'break_time': breakTime,
          if (_hasText(description)) 'description': description!.trim(),
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      if (_isAmbiguousWriteFailure(error)) {
        throw const TimeTrackingWriteUncertainException();
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> stopTimer({
    required int id,
    required String endTime,
    required double breakTime,
    required String idempotencyKey,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/time-tracking/entries/$id/stop',
        data: {
          'end_time': _normalizeTime(endTime),
          'break_time': breakTime,
          if (_hasText(notes)) 'notes': notes!.trim(),
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      if (_isAmbiguousWriteFailure(error)) {
        throw const TimeTrackingWriteUncertainException();
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> submitEntry(int id) async {
    try {
      final response = await _dio.post('/time-tracking/entries/$id/submit');

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> submitCorrection({
    required int id,
    required double hoursWorked,
    required String correctionReason,
  }) async {
    final trimmedReason = correctionReason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError.value(correctionReason, 'correctionReason');
    }

    try {
      final response = await _dio.post(
        '/time-tracking/entries/$id/correction',
        data: {'hours_worked': hoursWorked, 'correction_reason': trimmedReason},
      );

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

class TimeTrackingWriteUncertainException extends ApiException {
  const TimeTrackingWriteUncertainException()
    : super(
        'Не удалось подтвердить результат. Обновите список записей и проверьте таймер перед повторной отправкой.',
      );
}

bool _isAmbiguousWriteFailure(DioException error) =>
    error.response == null &&
    (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown);

String newTimeTrackingIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _normalizeTime(String value) {
  final trimmed = value.trim();
  if (RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmed)) {
    return trimmed;
  }

  throw ArgumentError.value(value, 'time');
}
