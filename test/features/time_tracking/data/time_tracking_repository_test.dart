import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/time_tracking/data/time_tracking_repository.dart';

void main() {
  test('fetches daily summary through mobile time-tracking route', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return _responseData({
        'date': '2026-05-22',
        'project_id': 9,
        'entries': [_entryJson()],
        'active_timer': null,
        'totals': _totalsJson(),
        'approval_status': _statusCounts(),
      });
    });

    final repository = TimeTrackingRepository(dio);
    final summary = await repository.fetchDailySummary(
      date: '2026-05-22',
      projectId: 9,
    );

    expect(request.path, '/time-tracking/daily-summary');
    expect(request.queryParameters['date'], '2026-05-22');
    expect(request.queryParameters['project_id'], 9);
    expect(summary.entries.single.title, 'Монтаж опалубки');
  });

  test('starts and stops timer with explicit visible values', () async {
    final requests = <RequestOptions>[];
    final sent = <dynamic>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      sent.add(options.data);
      final isStart = options.path.endsWith('/timer/start');

      return _responseData(
        _entryJson(isActive: isStart, hours: isStart ? null : 3.5),
      );
    });

    final repository = TimeTrackingRepository(dio);
    final started = await repository.startTimer(
      projectId: 9,
      workDate: '2026-05-22',
      startTime: '08:00',
      title: ' Монтаж опалубки ',
      isBillable: true,
    );
    final stopped = await repository.stopTimer(
      id: 17,
      endTime: '12:00',
      breakTime: 0.5,
    );

    expect(requests.first.path, '/time-tracking/timer/start');
    expect(sent.first['title'], 'Монтаж опалубки');
    expect(sent.first['start_time'], '08:00');
    expect(sent.first['is_billable'], isTrue);
    expect(started.isActiveTimer, isTrue);
    expect(requests.last.path, '/time-tracking/entries/17/stop');
    expect(sent.last['end_time'], '12:00');
    expect(sent.last['break_time'], 0.5);
    expect(stopped.hoursWorked, 3.5);
  });

  test('submits correction with trimmed reason', () async {
    late RequestOptions request;
    dynamic sentData;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      sentData = options.data;
      return _responseData(
        _entryJson(status: 'submitted', actions: const [], hours: 5.5),
      );
    });

    final repository = TimeTrackingRepository(dio);
    final entry = await repository.submitCorrection(
      id: 17,
      hoursWorked: 5.5,
      correctionReason: ' Добавлен демонтаж ',
    );

    expect(request.method, 'POST');
    expect(request.path, '/time-tracking/entries/17/correction');
    expect(sentData['hours_worked'], 5.5);
    expect(sentData['correction_reason'], 'Добавлен демонтаж');
    expect(entry.status, 'submitted');
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _responseData(Map<String, dynamic> data) {
  return {'success': true, 'message': null, 'data': data};
}

Map<String, int> _statusCounts() {
  return {'draft': 1, 'submitted': 0, 'approved': 0, 'rejected': 0};
}

Map<String, dynamic> _totalsJson() {
  return {
    'total_hours': 3.5,
    'billable_hours': 3.5,
    'entries_count': 1,
    'by_status': _statusCounts(),
  };
}

Map<String, dynamic> _entryJson({
  String status = 'draft',
  bool isActive = false,
  double? hours = 3.5,
  List<String> actions = const ['submit'],
}) {
  return {
    'id': 17,
    'organization_id': 4,
    'user_id': 8,
    'project_id': 9,
    'project_label': 'Башня',
    'work_type_id': null,
    'work_type_label': null,
    'task_id': null,
    'task_label': null,
    'work_date': '2026-05-22',
    'start_time': '08:00',
    'end_time': isActive ? null : '12:00',
    'hours_worked': hours,
    'break_time': isActive ? null : 0.5,
    'title': 'Монтаж опалубки',
    'description': null,
    'status': status,
    'status_label': status == 'submitted' ? 'На согласовании' : 'Черновик',
    'is_active_timer': isActive,
    'is_billable': true,
    'location': null,
    'notes': null,
    'approved_by_user_id': null,
    'approved_by_label': null,
    'approved_at': null,
    'rejection_reason': null,
    'corrections': const [],
    'available_actions': actions,
    'approval_summary': {
      'status': status,
      'status_label': status == 'submitted' ? 'На согласовании' : 'Черновик',
      'approved_by_label': null,
      'approved_at': null,
      'rejection_reason': null,
    },
    'created_at': '2026-05-22T08:00:00Z',
    'updated_at': '2026-05-22T10:00:00Z',
  };
}
