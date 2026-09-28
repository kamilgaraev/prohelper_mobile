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
                {
                  'id': 9,
                  'direction': 'import',
                  'scope': 'materials',
                  'status': 'failed',
                  'total_count': 12,
                  'created_count': 4,
                  'updated_count': 6,
                  'skipped_count': 1,
                  'error_count': 1,
                  'errors': [],
                  'summary': {},
                  'created_at': '2026-09-25T10:00:00Z',
                },
              ],
              'meta': {'current_page': 2, 'last_page': 4},
            },
            '/system/access-recertification/campaigns' => {
              'data': [
                {
                  'id': 31,
                  'name': 'Осенняя проверка',
                  'status': 'active',
                  'type': 'quarterly',
                  'scope': {'role': 'field_engineer'},
                  'counts': {
                    'items': 18,
                    'pending_items': 8,
                    'overdue_items': 1,
                    'pending_revocations': 0,
                    'requested_exceptions': 0,
                  },
                },
              ],
              'meta': {'current_page': 2, 'last_page': 3},
            },
            '/system/access-recertification/reviews/my' => {
              'data': [
                {
                  'id': 'b6997089-a4a9-4aa3-b123-3118f3a66be4',
                  'campaign_id': 31,
                  'subject': {'id': 7, 'name': 'Иван Иванов'},
                  'role_slug': 'field_engineer',
                  'role_context': {'id': 52, 'type': 'project', 'label': 'A'},
                  'permission_summary': {'total': 5, 'high_risk': []},
                  'status': 'pending',
                  'risk_level': 'high',
                  'risk': {'high_risk_permissions': []},
                },
              ],
              'meta': {'current_page': 2, 'last_page': 5},
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
                {
                  'id': 2,
                  'code': 'MAT',
                  'name': 'Коэффициент материалов',
                  'value': '1.15',
                  'applies_to': 'material_norms',
                },
              ],
              'meta': {'current_page': 1, 'last_page': 1},
            },
            '/system/events' => {
              'data': [
                {
                  'id': 77,
                  'event_type': 'project.updated',
                  'action': 'updated',
                  'domain': 'project',
                  'result': 'success',
                  'severity': 'info',
                  'occurred_at': '2026-09-25T10:00:00Z',
                  'actor': {'type': 'user', 'user_id': 7},
                  'source': {'name': 'api', 'model': null, 'table': null, 'event_id': null},
                  'subject': {'type': 'project', 'id': 52, 'label': 'Объект A'},
                  'project_id': 52,
                  'chain': {'scope': 'organization', 'version': 1},
                  'integrity_status': 'verified',
                },
              ],
              'meta': {'current_page': 2, 'last_page': 6},
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

  test('reads nonempty access recertification campaign and review pages', () async {
    final campaigns = await repository.campaigns(page: 2, search: 'Осенняя');
    expect(campaigns.items.single['name'], 'Осенняя проверка');
    expect(campaigns.currentPage, 2);
    expect(campaigns.lastPage, 3);
    expect(requests.last.path, '/system/access-recertification/campaigns');
    expect(requests.last.queryParameters, {
      'page': 2,
      'per_page': 20,
      'search': 'Осенняя',
    });

    final reviews = await repository.myReviews(page: 2, search: 'pending');
    expect(reviews.items.single['id'], 'b6997089-a4a9-4aa3-b123-3118f3a66be4');
    expect(reviews.currentPage, 2);
    expect(reviews.lastPage, 5);
    expect(requests.last.path, '/system/access-recertification/reviews/my');
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

  test('reads nonempty system event page and paging metadata', () async {
    final page = await repository.events(page: 2, search: 'project.updated');

    expect((page.items.single['subject'] as Map)['id'], 52);
    expect(page.currentPage, 2);
    expect(page.lastPage, 6);
    expect(requests.single.path, '/system/events');
    expect(requests.single.queryParameters['search'], 'project.updated');
  });
}
