import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/machinery_operations/data/machinery_operations_repository.dart';

void main() {
  group('machinery operations list pagination', () {
    test('loads all asset pages', () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options) {
        requests.add(options);
        final page = options.queryParameters['page'] as int;
        return _pageResponse(_assets(page == 1 ? 1 : 101, page == 1 ? 100 : 1));
      });

      final assets = await repository.fetchAssets(projectId: 9);

      expect(assets, hasLength(101));
      expect([assets.first.id, assets.last.id], [1, 101]);
      _expectPages(requests, '/machinery-operations/assets');
    });

    test('loads all shift report pages', () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options) {
        requests.add(options);
        final page = options.queryParameters['page'] as int;
        return _pageResponse(
          _shiftReports(page == 1 ? 1 : 101, page == 1 ? 100 : 1),
        );
      });

      final reports = await repository.fetchShiftReports(projectId: 9);

      expect(reports, hasLength(101));
      expect([reports.first.id, reports.last.id], [1, 101]);
      _expectPages(requests, '/machinery-operations/shift-reports');
    });

    test('loads all maintenance order pages', () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options) {
        requests.add(options);
        final page = options.queryParameters['page'] as int;
        return _pageResponse(
          _maintenanceOrders(page == 1 ? 1 : 101, page == 1 ? 100 : 1),
        );
      });

      final orders = await repository.fetchMaintenanceOrders(projectId: 9);

      expect(orders, hasLength(101));
      expect([orders.first.id, orders.last.id], [1, 101]);
      _expectPages(requests, '/machinery-operations/maintenance-orders');
    });

    test('fails explicitly when any endpoint repeats a page', () async {
      final endpoints = <
        (
          String,
          Future<Object?> Function(MachineryOperationsRepository),
          List<Map<String, dynamic>>,
        )
      >[
        (
          '/machinery-operations/assets',
          (repository) => repository.fetchAssets(),
          _assets(1, 100),
        ),
        (
          '/machinery-operations/shift-reports',
          (repository) => repository.fetchShiftReports(),
          _shiftReports(1, 100),
        ),
        (
          '/machinery-operations/maintenance-orders',
          (repository) => repository.fetchMaintenanceOrders(),
          _maintenanceOrders(1, 100),
        ),
      ];

      for (final (path, fetch, repeatedItems) in endpoints) {
        final requests = <RequestOptions>[];
        final repository = _repository((options) {
          requests.add(options);
          return _pageResponse(repeatedItems);
        });

        await expectLater(
          fetch(repository),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('повторил страницу'),
            ),
          ),
        );
        expect(requests, hasLength(2), reason: path);
      }
    });

    test('fails explicitly after the page limit', () async {
      var requestCount = 0;
      final repository = _repository((options) {
        requestCount++;
        final page = options.queryParameters['page'] as int;
        return _pageResponse(_assets((page - 1) * 100 + 1, 100));
      });

      await expectLater(
        repository.fetchAssets(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('превышен предел страниц'),
          ),
        ),
      );
      expect(requestCount, 100);
    });
  });
}

MachineryOperationsRepository _repository(
  Map<String, dynamic> Function(RequestOptions) respond,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..httpClientAdapter = _JsonAdapter(respond);
  return MachineryOperationsRepository(dio);
}

void _expectPages(List<RequestOptions> requests, String path) {
  expect(requests.map((request) => request.path), [path, path]);
  expect(requests.map((request) => request.queryParameters['page']), [1, 2]);
  expect(
    requests.every((request) => request.queryParameters['per_page'] == 100),
    isTrue,
  );
  expect(
    requests.every((request) => request.queryParameters['project_id'] == 9),
    isTrue,
  );
}

Map<String, dynamic> _pageResponse(List<Map<String, dynamic>> items) => {
  'success': true,
  'message': null,
  'data': items,
};

List<Map<String, dynamic>> _assets(int start, int count) => [
  for (var id = start; id < start + count; id++)
    {
      'id': id,
      'asset_code': 'M-$id',
      'name': 'Техника $id',
      'status': 'available',
      'status_label': 'Доступна',
      'available_actions': <String>[],
    },
];

List<Map<String, dynamic>> _shiftReports(int start, int count) => [
  for (var id = start; id < start + count; id++)
    {
      'id': id,
      'asset_id': 1,
      'project_id': 9,
      'report_date': '2026-09-27',
      'status': 'draft',
      'status_label': 'Черновик',
      'actual_hours': 1,
      'fuel_consumed': 0,
      'available_actions': <String>[],
    },
];

List<Map<String, dynamic>> _maintenanceOrders(int start, int count) => [
  for (var id = start; id < start + count; id++)
    {
      'id': id,
      'asset_id': 1,
      'title': 'ТО $id',
      'status': 'planned',
      'status_label': 'Запланировано',
      'priority': 'normal',
      'available_actions': <String>[],
    },
];

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.respond);

  final Map<String, dynamic> Function(RequestOptions) respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
