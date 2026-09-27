import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';

void main() {
  test('fetchTaskPage parses paginated mobile response', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = _JsonAdapter((options) {
        request = options;

        return {
          'success': true,
          'message': null,
          'data': [_taskPayload()],
          'meta': {
            'current_page': 2,
            'last_page': 3,
            'per_page': 40,
            'total': 100,
            'has_more': true,
          },
        };
      });
    final repository = WarehouseRepository(dio);

    final page = await repository.fetchTaskPage(
      8,
      page: 2,
      perPage: 40,
      status: 'queued',
      query: ' cement ',
    );

    expect(request.path, '/warehouse/warehouses/8/tasks');
    expect(request.queryParameters['page'], 2);
    expect(request.queryParameters['per_page'], 40);
    expect(request.queryParameters['limit'], 40);
    expect(request.queryParameters['status'], 'queued');
    expect(request.queryParameters['q'], ' cement ');
    expect(page.items.single.id, 17);
    expect(page.currentPage, 2);
    expect(page.lastPage, 3);
    expect(page.total, 100);
    expect(page.hasMore, isTrue);
  });

  test('legacy array response shows first page and stops pagination', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = _JsonAdapter(
        (_) => {
          'success': true,
          'message': null,
          'data': [_taskPayload()],
        },
      );
    final repository = WarehouseRepository(dio);

    final page = await repository.fetchTaskPage(8, page: 1, perPage: 60);

    expect(page.items.single.id, 17);
    expect(page.currentPage, 1);
    expect(page.lastPage, 1);
    expect(page.hasMore, isFalse);
  });
}

Map<String, dynamic> _taskPayload() => {
  'id': 17,
  'warehouse_id': 8,
  'task_number': 'WH-17',
  'title': 'Move cement',
  'task_type': 'transfer',
  'task_type_label': 'Перемещение',
  'status': 'queued',
  'status_label': 'В очереди',
  'priority': 'normal',
  'priority_label': 'Обычный',
  'metadata': <String, dynamic>{},
  'available_transitions': <dynamic>[],
};

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
    await requestStream?.drain<void>();

    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
