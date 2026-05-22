import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/notifications/data/notification_model.dart';
import 'package:prohelpers_mobile/features/notifications/data/notifications_repository.dart';

void main() {
  test('loads notification list with pagination and unread count', () async {
    final adapter =
        _NotificationsHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 200,
              body:
                  '{"data":[${_notificationJson('n1')}],"meta":{"current_page":1,"last_page":2,"per_page":1,"total":2}}',
            ),
          )
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"data":{"count":3}}'),
          );
    final repository = NotificationsRepository(_dio(adapter));

    final page = await repository.fetchNotifications(
      perPage: 1,
      filter: NotificationFilter.unread,
    );
    final count = await repository.fetchUnreadCount();

    expect(page.items.single.id, 'n1');
    expect(page.currentPage, 1);
    expect(page.lastPage, 2);
    expect(page.total, 2);
    expect(count, 3);
    expect(adapter.requests.first.queryParameters['filter'], 'unread');
  });

  test('mark as read uses canonical endpoint only', () async {
    final adapter =
        _NotificationsHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 200,
              body: '{"data":${_notificationJson('n1', read: true)}}',
            ),
          );
    final repository = NotificationsRepository(_dio(adapter));

    final notification = await repository.markAsRead('n1');

    expect(notification.isUnread, isFalse);
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/notifications/n1/mark-read');
  });

  test('mark as read does not call older endpoint after not found', () async {
    final adapter =
        _NotificationsHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 404,
              body: '{"message":"Уведомление не найдено"}',
            ),
          );
    final repository = NotificationsRepository(_dio(adapter));

    await expectLater(
      repository.markAsRead('missing'),
      throwsA(isA<ApiException>()),
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/notifications/missing/mark-read');
  });
}

Dio _dio(_NotificationsHttpAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.prohelper.test',
      headers: const <String, dynamic>{'Content-Type': 'application/json'},
    ),
  )..httpClientAdapter = adapter;
}

String _notificationJson(String id, {bool read = false}) {
  return '''
{
  "id": "$id",
  "type": "site_request_created",
  "notification_type": "site_request_created",
  "category": "site-requests",
  "priority": "high",
  "read_at": ${read ? '"2026-05-22T10:00:00Z"' : 'null'},
  "created_at": "2026-05-22T09:00:00Z",
  "data": {
    "title": "Новая заявка",
    "message": "Заявка требует согласования",
    "module": "site-requests",
    "site_request_id": 45,
    "actions": [
      {"label": "Открыть", "params": {"site_request_id": 45}}
    ]
  }
}
''';
}

class _NotificationsHttpAdapter implements HttpClientAdapter {
  final responses = Queue<_AdapterResponse>();
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    final response = responses.removeFirst();

    return ResponseBody.fromString(
      response.body,
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterResponse {
  const _AdapterResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
