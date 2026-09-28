import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/modules/data/modules_repository.dart';

void main() {
  test('parses nonempty mobile module catalog in selected project scope', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': {
          'modules': [
            {
              'slug': 'site-requests',
              'title': 'Заявки с объекта',
              'description': 'Создание и согласование заявок',
              'icon': 'clipboard',
              'supported_on_mobile': true,
              'order': 2,
              'route': 'site-requests',
              'permissions': ['site_requests.view'],
            },
            {
              'slug': 'quality-control',
              'title': 'Контроль качества',
              'description': 'Замечания по объекту',
              'icon': 'quality',
              'supported_on_mobile': true,
              'order': 1,
              'route': 'quality-control',
              'permissions': ['quality_control.view'],
            },
          ],
        },
      };
    });

    final modules = await ModulesRepository(dio).fetchModules(projectId: 52);

    expect(request.path, '/modules');
    expect(request.queryParameters, {'project_id': 52});
    expect(modules.map((module) => module.slug), [
      'quality-control',
      'site-requests',
    ]);
    expect(modules.last.permissions, ['site_requests.view']);
    expect(modules.last.supportedOnMobile, isTrue);
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
