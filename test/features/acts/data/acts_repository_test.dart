import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/acts/data/acts_repository.dart';

void main() {
  test('lists project acts with filters and parses paginated items', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'message': null,
        'data': {
          'items': [
            {
              'id': 52,
              'act_document_number': 'КС-2-052',
              'number': 'КС-2-052',
              'act_date': '2026-09-15',
              'date': '2026-09-15',
              'status': 'approved',
              'status_label': 'approved',
              'amount': 125000.5,
              'currency': 'RUB',
              'description': 'Фасадные работы',
              'project': {'id': 31, 'name': 'Объект A'},
              'project_name': 'Объект A',
              'contractor_name': 'Подрядчик А',
              'contract': {
                'id': 7,
                'number': 'ДОГ-7',
                'contractor_name': 'Подрядчик А',
              },
              'capabilities': {'can_field_confirm': false},
            },
          ],
          'meta': {
            'current_page': 2,
            'per_page': 20,
            'total': 21,
            'last_page': 2,
          },
        },
      };
    });

    final page = await ActsRepository(
      dio,
    ).list(projectId: 31, page: 2, status: 'approved');

    expect(request.method, 'GET');
    expect(request.path, '/acts');
    expect(request.queryParameters, {
      'project_id': 31,
      'page': 2,
      'per_page': 20,
      'status': 'approved',
    });
    expect(page.items, hasLength(1));
    expect(page.items.single.id, 52);
    expect(page.items.single.title, 'КС-2-052');
    expect(page.items.single.status, 'Утвержден');
    expect(page.items.single.values['project_name'], 'Объект A');
    expect(page.currentPage, 2);
    expect(page.lastPage, 2);
  });

  test(
    'field confirmation sends the signature and stable idempotency key',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {'id': 9, 'act_id': 4, 'evidence_type': 'field_acceptance'},
        };
      }, statusCode: 201);

      final confirmation = await ActsRepository(dio).confirmField(
        id: 4,
        signatureData: 'cG5nLWJ5dGVz',
        idempotencyKey: 'stable-act-confirmation-key',
      );

      expect(request.method, 'POST');
      expect(request.path, '/acts/4/field-confirmations');
      expect(request.data['signature_data'], 'cG5nLWJ5dGVz');
      expect(request.data['idempotency_key'], 'stable-act-confirmation-key');
      expect(confirmation['evidence_type'], 'field_acceptance');
    },
  );
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
  ) async => ResponseBody.fromString(
    jsonEncode(handler(options)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
