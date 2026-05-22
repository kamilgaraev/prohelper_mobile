import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/module_companions/data/companion_module_repository.dart';

import '../companion_module_test_data.dart';

void main() {
  test('fetches companion list with filters', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return _responseData(companionListJson(slug: 'change-management'));
    });

    final repository = CompanionModuleRepository(dio);
    final list = await repository.fetchList(
      moduleSlug: 'change-management',
      projectId: 9,
      status: 'draft',
      query: ' Tower ',
    );

    expect(request.method, 'GET');
    expect(request.path, '/companions/change-management');
    expect(request.queryParameters['project_id'], 9);
    expect(request.queryParameters['status'], 'draft');
    expect(request.queryParameters['q'], 'Tower');
    expect(list.module.slug, 'change-management');
  });

  test('fetches detail and executes action', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      return _responseData(companionDetailJson(slug: 'change-management'));
    });

    final repository = CompanionModuleRepository(dio);
    final detail = await repository.fetchDetail(
      moduleSlug: 'change-management',
      id: 42,
    );
    final actionDetail = await repository.executeAction(
      moduleSlug: 'change-management',
      id: 42,
      action: 'submit',
      comment: ' Done ',
    );

    expect(requests.first.path, '/companions/change-management/42');
    expect(
      requests.last.path,
      '/companions/change-management/42/actions/submit',
    );
    expect((requests.last.data as Map)['comment'], 'Done');
    expect(detail.item.id, 42);
    expect(actionDetail.item.status, 'active');
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
