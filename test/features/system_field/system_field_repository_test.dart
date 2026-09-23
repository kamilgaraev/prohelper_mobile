import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/system_field/data/system_field_repository.dart';

void main() {
  late Dio dio;
  late SystemFieldRepository repository;
  final requests = <RequestOptions>[];

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/mobile'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = switch (options.path) {
            '/system/one-c-exchange/history' => {
              'data': [
                {'id': 9, 'status': 'failed'},
              ],
              'meta': {'current_page': 2, 'last_page': 4},
            },
            '/system/access-recertification/items/item-uuid/decisions' => {
              'data': {'id': 18},
            },
            '/system/one-c-exchange/journal/9/retry' => {
              'success': true,
              'data': {'id': 10, 'status': 'queued'},
            },
            '/system/rate-coefficients/current' => {
              'data': [
                {'id': 2, 'code': 'MAT'},
              ],
              'meta': {'current_page': 1, 'last_page': 1},
            },
            _ => {'data': <dynamic>[]},
          };
          handler.resolve(Response(requestOptions: options, data: data));
        },
      ),
    );
    repository = SystemFieldRepository(dio);
    requests.clear();
  });

  test('reads paginated history data and meta', () async {
    final page = await repository.oneCHistory(page: 2, search: 'failed');

    expect(page.items.single['id'], 9);
    expect(page.currentPage, 2);
    expect(page.lastPage, 4);
    expect(requests.single.queryParameters, containsPair('page', 2));
    expect(requests.single.queryParameters, containsPair('search', 'failed'));
  });

  test('sends required decision fields and optional controls', () async {
    await repository.decide(
      uuid: 'item-uuid',
      decision: 'exception',
      reason: 'Нужен временный доступ',
      confirmation: true,
      validUntil: '2026-10-01',
      compensatingControls: const ['Еженедельная проверка'],
    );

    expect(requests.single.data, {
      'decision': 'exception',
      'reason': 'Нужен временный доступ',
      'confirmation': true,
      'valid_until': '2026-10-01',
      'compensating_controls': ['Еженедельная проверка'],
    });
  });

  test('retries a one c operation without a request body', () async {
    await repository.retryOneC('9');

    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/system/one-c-exchange/journal/9/retry');
    expect(requests.single.data, isNull);
  });

  test('requires applies_to for current coefficients', () async {
    final page = await repository.currentCoefficients(
      appliesTo: 'material_norms',
    );

    expect(page.items.single['code'], 'MAT');
    expect(requests.single.queryParameters, containsPair('applies_to', 'material_norms'));
  });
}
