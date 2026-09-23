import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/payments/data/payments_repository.dart';

void main() {
  test(
    'reuses caller idempotency key for payment registration request',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {'id': 14, 'status': 'partially_paid'},
        };
      });

      final repository = PaymentsRepository(dio);
      final document = await repository.registerPayment(14, {
        'amount': 1250,
        'payment_method': 'cash',
      }, idempotencyKey: 'stable-payment-attempt-key');

      expect(request.method, 'POST');
      expect(request.path, '/payments/documents/14/payments');
      expect(request.headers['Idempotency-Key'], 'stable-payment-attempt-key');
      expect(request.data['amount'], 1250);
      expect(document.id, 14);
    },
  );

  test('list parses server capabilities and pagination metadata', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter(
      (_) => {
        'success': true,
        'data': {
          'items': [
            {'id': 1, 'document_number': 'PD-1'},
          ],
          'meta': {
            'current_page': 1,
            'last_page': 3,
            'capabilities': {'can_create': true},
          },
        },
      },
    );

    final page = await PaymentsRepository(dio).list(projectId: 8);

    expect(page.items.single.title, 'PD-1');
    expect(page.currentPage, 1);
    expect(page.lastPage, 3);
    expect(page.canCreate, isTrue);
  });

  test('sends a rejection reason to the document decision endpoint', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      request = options;
      return {
        'success': true,
        'data': {'id': 14, 'status': 'rejected'},
      };
    });

    final document = await PaymentsRepository(
      dio,
    ).decide(14, approve: false, comment: 'Неверная сумма');

    expect(request.path, '/payments/documents/14/reject');
    expect(request.data['reason'], 'Неверная сумма');
    expect(document.id, 14);
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
