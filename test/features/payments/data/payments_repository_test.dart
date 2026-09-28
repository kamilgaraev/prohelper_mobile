import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/payments/data/payments_repository.dart';

void main() {
  test(
    'loads scoped payment parties with search and contractor pagination',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {
            'current_organization': {
              'id': 7,
              'name': 'МОСТ',
              'inn': '7701000000',
            },
            'contractors': {
              'items': [
                {
                  'id': 31,
                  'name': 'ООО Поставка',
                  'inn': '7702000000',
                  'contractor_type': 'organization',
                },
              ],
              'meta': {
                'current_page': 2,
                'per_page': 20,
                'total': 24,
                'last_page': 2,
              },
            },
          },
        };
      });

      final options = await PaymentsRepository(
        dio,
      ).formOptions(projectId: 52, search: 'Поставка', page: 2);

      expect(request.method, 'GET');
      expect(request.path, '/payments/documents/options');
      expect(request.queryParameters, {
        'project_id': 52,
        'search': 'Поставка',
        'page': 2,
        'per_page': 20,
      });
      expect(options.currentOrganization.key, 'organization:7');
      expect(options.currentOrganization.name, 'МОСТ');
      expect(options.contractors.items.single.key, 'contractor:31');
      expect(
        options.contractors.items.single.label,
        'ООО Поставка · ИНН 7702000000',
      );
      expect(options.contractors.currentPage, 2);
      expect(options.contractors.lastPage, 2);
      expect(options.contractors.total, 24);
    },
  );

  test(
    'update sends only the supplied patch and preserves saved parties',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {'id': 19, 'status': 'draft'},
        };
      });

      await PaymentsRepository(dio).update(19, {
        'payment_purpose': 'Обновлённое назначение',
        'bank_account': '12345678901234567890',
        'bank_bik': '123456789',
      });

      expect(request.method, 'PUT');
      expect(request.path, '/payments/documents/19');
      expect(request.data, {
        'payment_purpose': 'Обновлённое назначение',
        'bank_account': '12345678901234567890',
        'bank_bik': '123456789',
      });
      expect(request.data, isNot(contains('payer_organization_id')));
      expect(request.data, isNot(contains('payee_organization_id')));
    },
  );

  test(
    'update sends the selected party and explicit null to clear old party type',
    () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _JsonAdapter((options) {
        request = options;
        return {
          'success': true,
          'data': {'id': 19, 'status': 'draft'},
        };
      });

      await PaymentsRepository(
        dio,
      ).update(19, {'payee_contractor_id': 31, 'payee_organization_id': null});

      expect(request.data, {
        'payee_contractor_id': 31,
        'payee_organization_id': null,
      });
    },
  );

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
