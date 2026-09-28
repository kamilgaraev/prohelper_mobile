import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/warehouse/data/warehouse_repository.dart';

void main() {
  test('loads nonempty balance and project-delivery mobile resources', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.prohelper.test'))
      ..httpClientAdapter = _JsonAdapter((options) {
        requests.add(options);
        if (options.path.endsWith('/balances')) {
          return {
            'success': true,
            'message': null,
            'data': [
              {
                'warehouse_id': 8,
                'warehouse_name': 'Центральный склад',
                'material_id': 44,
                'material_name': 'Цемент М500',
                'material_code': 'CEM-500',
                'measurement_unit': 'меш.',
                'available_quantity': 18.0,
                'reserved_quantity': 2.0,
                'total_quantity': 20.0,
                'average_price': 510.0,
                'total_value': 10200.0,
                'is_low_stock': false,
                'photo_gallery': [],
                'asset_photo_gallery': [],
              },
            ],
          };
        }
        return {
          'success': true,
          'message': null,
          'data': {
            'items': [
              {
                'id': 73,
                'source_type': 'purchase_order',
                'status': 'in_transit',
                'status_label': 'В пути',
                'status_color': '#336699',
                'requested_quantity': 10.0,
                'reserved_quantity': 10.0,
                'shipped_quantity': 6.0,
                'accepted_quantity': 0.0,
                'used_quantity': 0.0,
                'available_quantity': 0.0,
                'remaining_to_ship': 4.0,
                'remaining_to_accept': 6.0,
                'can_receive': true,
                'metadata': {},
                'project': {'id': 52, 'name': 'Тестовый'},
                'material': {
                  'id': 44,
                  'name': 'Цемент М500',
                  'code': 'CEM-500',
                  'measurement_unit': {
                    'id': 2,
                    'name': 'мешок',
                    'short_name': 'меш.',
                  },
                },
                'warehouse': {'id': 8, 'name': 'Центральный склад'},
                'project_warehouse': {'id': 21, 'name': 'Склад объекта'},
                'linked_entities': {'allocation_id': 9},
                'events': [],
              },
            ],
          },
        };
      });
    final repository = WarehouseRepository(dio);

    final balances = await repository.fetchBalances(8);
    final deliveries = await repository.fetchProjectMaterialDeliveries(
      projectId: 52,
    );

    expect(balances.single.materialName, 'Цемент М500');
    expect(balances.single.availableQuantity, 18);
    expect(deliveries.single.id, 73);
    expect(deliveries.single.projectName, 'Тестовый');
    expect(deliveries.single.materialUnit, 'меш.');
    expect(requests.map((request) => request.path), [
      '/warehouse/warehouses/8/balances',
      '/warehouse/project-material-deliveries',
    ]);
    expect(requests.last.queryParameters['project_id'], 52);
    // These MobileResponse resources are arrays/items and do not expose page meta.
  });

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
