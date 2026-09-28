import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';

void main() {
  test(
    'permit transitions use mobile POST routes and backend field names',
    () async {
      final adapter = _ContractAdapter(
        (request) => _jsonResponse(_permitResponse()),
      );
      final repository = SafetyRepository(_dio(adapter));

      await repository.submitPermit(31);
      await repository.approvePermit(31, approvalComment: '  Проверено  ');
      await repository.activatePermit(31);
      await repository.suspendPermit(31, reason: '  Риск обнаружен  ');
      await repository.resumePermit(31);
      await repository.rejectPermit(31, reason: '  Не согласовано  ');
      await repository.closePermit(31, closeComment: '  Работы завершены  ');

      expect(
        adapter.requests.map((request) => [request.method, request.path]),
        [
          ['POST', '/safety-management/work-permits/31/submit'],
          ['POST', '/safety-management/work-permits/31/approve'],
          ['POST', '/safety-management/work-permits/31/activate'],
          ['POST', '/safety-management/work-permits/31/suspend'],
          ['POST', '/safety-management/work-permits/31/resume'],
          ['POST', '/safety-management/work-permits/31/reject'],
          ['POST', '/safety-management/work-permits/31/close'],
        ],
      );
      expect(adapter.requests.map((request) => request.data), [
        null,
        {'approval_comment': 'Проверено'},
        null,
        {'reason': 'Риск обнаружен'},
        null,
        {'reason': 'Не согласовано'},
        {'close_comment': 'Работы завершены'},
      ]);
      expect(
        adapter.requests.every(
          (request) => !request.headers.containsKey('Idempotency-Key'),
        ),
        isTrue,
      );
    },
  );

  test(
    'permit action decodes the success envelope and server validation errors',
    () async {
      final success = _ContractAdapter(
        (request) => _jsonResponse(_permitResponse()),
      );
      final result = await SafetyRepository(
        _dio(success),
      ).approvePermit(31, approvalComment: 'Проверено');
      expect(result.id, 31);
      expect(result.status, 'approved');

      final validation = _ContractAdapter(
        (request) => _errorResponse(422, {
          'reason': ['Поле обязательно.'],
        }),
      );
      await expectLater(
        SafetyRepository(_dio(validation)).suspendPermit(31, reason: 'Причина'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            422,
          ),
        ),
      );

      final forbidden = _ContractAdapter(
        (request) => _errorResponse(403, null),
      );
      await expectLater(
        SafetyRepository(
          _dio(forbidden),
        ).closePermit(31, closeComment: 'Готово'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            403,
          ),
        ),
      );
    },
  );
}

Dio _dio(_ContractAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'))
      ..httpClientAdapter = adapter;

Map<String, dynamic> _permitResponse() => {
  'success': true,
  'data': {
    'id': 31,
    'project_id': 9,
    'permit_number': 'WP-31',
    'title': 'Огневые работы',
    'permit_type': 'hot_work',
    'risk_level': 'high',
    'status': 'approved',
    'status_label': 'Согласован',
    'available_actions': <String>[],
    'valid_from': '2026-09-28T08:00:00Z',
    'valid_until': '2026-09-28T18:00:00Z',
    'required_controls': <String>[],
  },
};

ResponseBody _jsonResponse(dynamic data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _errorResponse(int status, dynamic errors) => _jsonResponse({
  'success': false,
  'message': 'Ошибка запроса',
  'errors': errors,
}, status);

class _ContractAdapter implements HttpClientAdapter {
  _ContractAdapter(this.respond);

  final ResponseBody Function(RequestOptions request) respond;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = respond(options);
    return response;
  }
}
