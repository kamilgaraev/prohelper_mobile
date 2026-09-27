import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';

void main() {
  test('accepts a journal with no entries', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      if (options.path == '/construction-journals/77') {
        return _envelope({'id': 77, 'project_id': 15, 'name': 'Журнал'});
      }
      return _entriesEnvelope(page: 1, lastPage: 1, total: 0, items: const []);
    });

    final payload = await ConstructionJournalRepository(
      dio,
    ).fetchJournalDetailPayload(77);

    expect(payload['entries'], isEmpty);
    expect(payload['meta'], {
      'current_page': 1,
      'per_page': 100,
      'last_page': 1,
      'total': 0,
    });
  });

  test('loads every journal entry page from MobileResponse envelope', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      requests.add(options);
      if (options.path == '/construction-journals/77') {
        return _envelope({'id': 77, 'project_id': 15, 'name': 'Журнал'});
      }

      final page = options.queryParameters['page'] as int;
      return _envelope({
        'items': [
          {'id': page == 1 ? 101 : 102},
        ],
        'meta': {
          'current_page': page,
          'per_page': 100,
          'last_page': 2,
          'total': 2,
        },
        'summary': {
          'total_entries': 2,
          'approved_entries': 1,
          'submitted_entries': 1,
          'rejected_entries': 0,
        },
        'available_actions': [
          {'action': 'create_entry', 'label': 'Создать запись'},
        ],
      });
    });

    final payload = await ConstructionJournalRepository(
      dio,
    ).fetchJournalDetailPayload(77);

    expect((payload['journal'] as Map)['id'], 77);
    expect((payload['entries'] as List).map((entry) => entry['id']), [
      101,
      102,
    ]);
    expect(payload['meta'], {
      'current_page': 1,
      'per_page': 100,
      'last_page': 2,
      'total': 2,
    });
    expect(payload['summary'], {
      'total_entries': 2,
      'approved_entries': 1,
      'submitted_entries': 1,
      'rejected_entries': 0,
    });
    expect(payload['available_actions'], [
      {'action': 'create_entry', 'label': 'Создать запись'},
    ]);
    final entryRequests = requests.where(
      (request) => request.path == '/construction-journals/77/entries',
    );
    expect(entryRequests, hasLength(2));
    expect(entryRequests.map((request) => request.queryParameters), [
      {'page': 1, 'per_page': 100},
      {'page': 2, 'per_page': 100},
    ]);
    expect(entryRequests.map((request) => request.path).toSet(), {
      '/construction-journals/77/entries',
    });
  });

  test('fails when an intermediate journal entries page is empty', () async {
    var entryPageRequests = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      if (options.path == '/construction-journals/77') {
        return _envelope({'id': 77, 'project_id': 15, 'name': 'Журнал'});
      }
      entryPageRequests++;
      final page = options.queryParameters['page'] as int;
      return _entriesEnvelope(
        page: page,
        lastPage: 3,
        total: 3,
        items:
            page == 1
                ? const [
                  {'id': 101},
                ]
                : const [],
      );
    });

    await expectLater(
      ConstructionJournalRepository(dio).fetchJournalDetailPayload(77),
      throwsA(isA<ApiException>()),
    );

    expect(entryPageRequests, 2);
  });

  test('stops before requesting a page beyond the pagination guard', () async {
    var entryPageRequests = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _JsonAdapter((options) {
      if (options.path == '/construction-journals/77') {
        return _envelope({'id': 77, 'project_id': 15, 'name': 'Журнал'});
      }
      entryPageRequests++;
      return _entriesEnvelope(
        page: 1,
        lastPage: 101,
        total: 101,
        items: const [
          {'id': 101},
        ],
      );
    });

    await expectLater(
      ConstructionJournalRepository(dio).fetchJournalDetailPayload(77),
      throwsA(isA<ApiException>()),
    );

    expect(entryPageRequests, 1);
  });
}

Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
  'success': true,
  'message': null,
  'data': data,
};

Map<String, dynamic> _entriesEnvelope({
  required int page,
  required int lastPage,
  required int total,
  required List<Map<String, dynamic>> items,
}) => _envelope({
  'items': items,
  'meta': {
    'current_page': page,
    'per_page': 100,
    'last_page': lastPage,
    'total': total,
  },
  'summary': {
    'total_entries': total,
    'approved_entries': 0,
    'submitted_entries': 0,
    'rejected_entries': 0,
  },
  'available_actions': const [],
});

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
