import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/acts/data/acts_repository.dart';

void main() {
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
      });

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
    201,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
