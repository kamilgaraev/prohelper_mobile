import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/projects/data/projects_repository.dart';

void main() {
  test('parses nonempty accessible project resource collection', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'message': null,
        'data': [
          {
            'id': 52,
            'name': 'Тестовый',
            'address': 'Москва',
            'status': 'active',
            'start_date': '2026-09-01',
            'end_date': '2027-06-30',
            'customer_name': 'Заказчик',
            'my_role': 'engineer',
          },
        ],
      };
    });

    final projects = await ProjectsRepository(dio).fetchProjects();

    expect(request.path, '/projects');
    expect(projects, hasLength(1));
    expect(projects.single.serverId, 52);
    expect(projects.single.name, 'Тестовый');
    expect(projects.single.address, 'Москва');
    expect(projects.single.myRole, 'engineer');
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
  ) async => ResponseBody.fromString(
    jsonEncode(handler(options)),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
