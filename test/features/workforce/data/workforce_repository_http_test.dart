import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/workforce/data/workforce_repository.dart';

void main() {
  final workDate = DateTime(2026, 9, 28);

  test('issues attendance QR with backend date and project contract', () async {
    late RequestOptions request;
    final dio = _dio((options) {
      request = options;
      return _success({
        'qr_token': 'raw-token',
        'expires_at': '2026-09-28T12:00:00+03:00',
        'employee_id': 5,
        'employee_label': 'Иванов Иван',
        'project_id': 12,
        'project_label': 'Объект 12',
        'work_date': '2026-09-28',
        'status': 'active',
        'status_label': 'Готов',
      });
    });

    final qr = await WorkforceRepository(
      dio,
    ).issueAttendanceQr(projectId: 12, workDate: workDate);

    expect(request.method, 'POST');
    expect(request.path, '/workforce/attendance/qr');
    expect(request.data, {'project_id': 12, 'work_date': '2026-09-28'});
    expect(qr.qrToken, 'raw-token');
    expect(qr.projectId, 12);
  });

  test(
    'scans QR with trimmed device id and parses attendance response',
    () async {
      late RequestOptions request;
      final dio = _dio((options) {
        request = options;
        return _success(_scan(source: 'qr_scan'));
      });

      final scan = await WorkforceRepository(
        dio,
      ).scanAttendanceQr(qrToken: 'token-from-qr', deviceId: '  handset-7  ');

      expect(request.method, 'POST');
      expect(request.path, '/workforce/attendance/qr/scan');
      expect(request.data, {
        'qr_token': 'token-from-qr',
        'device_id': 'handset-7',
      });
      expect(scan.scanEventId, 91);
      expect(scan.source, 'qr_scan');
    },
  );

  test(
    'self attendance sends work date, project, and trimmed device id',
    () async {
      late RequestOptions request;
      final dio = _dio((options) {
        request = options;
        return _success(_scan(source: 'self_attendance'));
      });

      final result = await WorkforceRepository(dio).recordSelfAttendance(
        projectId: 12,
        workDate: workDate,
        deviceId: '  handset-7 ',
      );

      expect(request.method, 'POST');
      expect(request.path, '/workforce/attendance/self');
      expect(request.data, {
        'project_id': 12,
        'work_date': '2026-09-28',
        'device_id': 'handset-7',
      });
      expect(result.source, 'self_attendance');
    },
  );

  test('preserves validation and forbidden statuses from the API', () async {
    for (final status in [422, 403]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _FailureAdapter(status);

      await expectLater(
        WorkforceRepository(dio).recordSelfAttendance(workDate: workDate),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            status,
          ),
        ),
      );
    }
  });

  test('maps duplicate scan code and reports connection errors', () async {
    final duplicateDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = _JsonAdapter(
        (_) => {
          'success': false,
          'message': 'QR уже использован',
          'errors': {'code': 'duplicate_scan'},
        },
        statusCode: 409,
      );

    await expectLater(
      WorkforceRepository(duplicateDio).scanAttendanceQr(qrToken: 'used'),
      throwsA(isA<WorkforceDuplicateScanException>()),
    );

    final networkDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = _NetworkErrorAdapter();
    await expectLater(
      WorkforceRepository(networkDio).recordSelfAttendance(workDate: workDate),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('соединения'),
        ),
      ),
    );
  });

  test('rejects a success envelope missing required response data', () async {
    final dio = _dio(
      (_) => {
        'success': true,
        'data': {'status': 'active'},
      },
    );
    await expectLater(
      WorkforceRepository(dio).issueAttendanceQr(workDate: workDate),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _scan({required String source}) => {
  'scan_event_id': 91,
  'employee_id': 5,
  'employee_label': 'Иванов Иван',
  'project_id': 12,
  'project_label': 'Объект 12',
  'work_date': '2026-09-28',
  'status': 'at_work',
  'status_label': 'На объекте',
  'source': source,
  'source_label': source == 'qr_scan' ? 'По QR-коду' : 'Самостоятельно',
  'confirmed_at': '2026-09-28T09:00:00+03:00',
};

Map<String, dynamic> _success(Map<String, dynamic> data) => {
  'success': true,
  'message': null,
  'data': data,
};

Dio _dio(Map<String, dynamic> Function(RequestOptions) handler) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = _JsonAdapter(handler);

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler, {this.statusCode = 200});

  final Map<String, dynamic> Function(RequestOptions) handler;
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(handler(options)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FailureAdapter implements HttpClientAdapter {
  _FailureAdapter(this.statusCode);
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'success': false,
      'message': statusCode == 403 ? 'Недостаточно прав' : 'Дата некорректна',
      'errors':
          statusCode == 422
              ? {
                'work_date': ['Некорректная дата'],
              }
              : null,
    }),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _NetworkErrorAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
}
