import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
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
      page: 3,
    );

    expect(request.method, 'GET');
    expect(request.path, '/companions/change-management');
    expect(request.queryParameters['project_id'], 9);
    expect(request.queryParameters['status'], 'draft');
    expect(request.queryParameters['q'], 'Tower');
    expect(request.queryParameters['page'], 3);
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

  test(
    'posts executive document action to its confirmed workflow endpoint',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return _responseData(executiveDocumentActionResponse());
      });

      await CompanionModuleRepository(dio).executeExecutiveDocumentAction(
        documentId: 7,
        action: 'add_remark',
        comment: 'Нужно исправить',
      );

      expect(request.method, 'POST');
      expect(request.path, '/pto/executive-documents/7/actions/add_remark');
      expect((request.data as Map)['comment'], 'Нужно исправить');
    },
  );

  test('executive document action forwards API error envelopes', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter(
      (_) => {
        'success': false,
        'message': 'Комментарий обязателен',
        'errors': {
          'comment': ['Комментарий обязателен'],
        },
      },
      statusCode: 422,
    );

    await expectLater(
      CompanionModuleRepository(dio).executeExecutiveDocumentAction(
        documentId: 7,
        action: 'add_remark',
        comment: '',
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having(
              (error) => error.message,
              'message',
              'Комментарий обязателен',
            ),
      ),
    );
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler, {this.statusCode = 200});

  final Map<String, dynamic> Function(RequestOptions options) handler;
  final int statusCode;

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
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> executiveDocumentActionResponse() => {
  'id': 7,
  'document_set_id': 42,
  'title': 'Исполнительная схема',
  'status': 'remarks',
  'result': {'document_date': null, 'approved_at': null, 'submitted_at': null},
  'files': [],
  'comments': [],
  'available_actions': [],
};

Map<String, dynamic> _responseData(Map<String, dynamic> data) {
  return {'success': true, 'message': null, 'data': data};
}
