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
    try {
      final response = await _dio.get(
        '/time-tracking/daily-summary',
        queryParameters: {'date': date, 'project_id': projectId},
      );

      return DailyTimeSummaryModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
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
    try {
      final response = await _dio.get('/time-tracking/entries/$id');

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
      );

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> createManualEntry({
    required int projectId,
    required String workDate,
    required double hoursWorked,
    required String title,
    required bool isBillable,
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
      );

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeEntryModel> stopTimer({
    required int id,
    required String endTime,
    required double breakTime,
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
      );

      return TimeEntryModel.fromJson(MobileApiResponse.dataMap(response.data));
    } on DioException catch (error) {
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
