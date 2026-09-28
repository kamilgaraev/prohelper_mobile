import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('loads mobile briefing resource with project and status filters', () async {
    final queue = TestDioResponseQueue()..respond(
      'GET',
      '/safety-management/briefings',
      {
        'success': true,
        'message': null,
        'data': [
          {
            'id': 14,
            'project_id': 52,
            'briefing_number': 'БР-14',
            'title': 'Инструктаж перед бетонированием',
            'briefing_type': 'targeted',
            'status': 'in_progress',
            'status_label': 'Проводится',
            'conducted_at': '2026-09-28T08:00:00+03:00',
            'signature_summary': {
              'total': 3,
              'pending': 2,
              'signed': 1,
              'refused': 0,
              'absent': 0,
              'resolved': 1,
              'completion_percent': 33,
              'all_resolved': false,
            },
            'available_actions': ['complete'],
            'topics': ['Работа с насосом'],
            'problem_flags': [],
          },
        ],
      },
    );
    final repository = SafetyRepository(queue.buildDio());

    final briefings = await repository.fetchBriefings(
      projectId: 52,
      status: 'in_progress',
    );

    expect(briefings.single.briefingNumber, 'БР-14');
    expect(briefings.single.title, 'Инструктаж перед бетонированием');
    expect(briefings.single.signatureSummary.total, 3);
    expect(queue.requests.single.path, '/safety-management/briefings');
    expect(queue.requests.single.queryParameters, {
      'project_id': 52,
      'status': 'in_progress',
    });
    // The current MobileResponse collection has no pagination meta.
  });

  test('loads nonempty inspection-finding resource and project filter', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(
      BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
    )..httpClientAdapter = _FindingResourceAdapter(requests);
    final findings = await SafetyRepository(dio).fetchInspectionFindings(
      projectId: 52,
      status: 'open',
    );

    expect(findings.single.findingNumber, 'ЗН-27');
    expect(findings.single.title, 'Ограждение проёма не закреплено');
    expect(findings.single.projectId, 52);
    expect(requests.map((request) => request.path).toSet(), {
      '/safety-management/inspection-findings',
    });
    expect(requests.first.queryParameters['project_id'], 52);
    expect(requests.first.queryParameters['status'], 'open');
    expect(requests.first.queryParameters['per_page'], 100);
    expect(requests.first.queryParameters['page'], 1);
    // This MobileResponse collection omits paginator meta; client stops on empty page.
  });

  test('loads all pages for the four safety registries', () async {
    final paths = [
      '/safety-management/incidents',
      '/safety-management/violations',
      '/safety-management/inspections',
      '/safety-management/inspection-findings',
    ];
    final requests = <RequestOptions>[];
    final dio = Dio(
      BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
    )..httpClientAdapter = _SafetyPaginationAdapter(requests);
    final repository = SafetyRepository(dio);
    final fetches = <Future<List<Map<String, dynamic>>> Function()>[
      repository.fetchIncidentPayloads,
      repository.fetchViolationPayloads,
      repository.fetchInspectionPayloads,
      repository.fetchInspectionFindingPayloads,
    ];

    for (var index = 0; index < fetches.length; index++) {
      final items = await fetches[index]();
      expect(items, hasLength(101));
      expect(items.first['id'], 1);
      expect(items.last['id'], 101);
      final endpointRequests =
          requests.where((request) => request.path == paths[index]).toList();
      expect(endpointRequests, hasLength(2));
      expect(
        endpointRequests.map((request) => request.queryParameters['page']),
        [1, 2],
      );
      expect(endpointRequests.first.queryParameters['per_page'], 100);
    }
  });

  test('stops after an empty last page without pagination metadata', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      )
      ..httpClientAdapter = _SafetyPaginationAdapter(
        requests,
        emptySecondPage: true,
      );

    final items = await SafetyRepository(dio).fetchIncidentPayloads();

    expect(items, hasLength(100));
    expect(requests, hasLength(2));
  });

  test('reports an error when the server repeats a page', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      )
      ..httpClientAdapter = _SafetyPaginationAdapter(
        requests,
        repeatSecondPage: true,
      );

    await expectLater(
      SafetyRepository(dio).fetchIncidentPayloads(),
      throwsA(isA<ApiException>()),
    );
    expect(requests, hasLength(2));
  });

  test('limits safety pagination to 1000 pages', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      )
      ..httpClientAdapter = _SafetyPaginationAdapter(
        requests,
        uniqueFullPages: true,
      );

    await expectLater(
      SafetyRepository(dio).fetchIncidentPayloads(),
      throwsA(isA<ApiException>()),
    );
    expect(requests, hasLength(1000));
  });

  test('sends violation evidence as photos[] multipart files', () async {
    final directory = await Directory.systemTemp.createTemp('safety-photo-');
    addTearDown(() => directory.delete(recursive: true));
    final photo = File('${directory.path}/evidence.jpg');
    await photo.writeAsBytes([1, 2, 3]);
    final queue =
        TestDioResponseQueue()
          ..respond('POST', '/safety-management/violations', {
            'success': true,
            'data': {
              'id': 4,
              'project_id': 9,
              'violation_number': 'HSE-V-4',
              'title': 'Нет ограждения',
              'severity': 'high',
              'status': 'open',
              'status_label': 'Открыто',
              'available_actions': ['resolve'],
            },
          });

    await SafetyRepository(queue.buildDio()).createViolation(
      {'project_id': 9, 'title': 'Нет ограждения', 'severity': 'high'},
      photoPaths: [photo.path],
    );

    final formData = queue.requests.single.data! as FormData;
    expect(queue.requests.single.path, '/safety-management/violations');
    expect(
      formData.fields.any(
        (entry) => entry.key == 'project_id' && entry.value == '9',
      ),
      isTrue,
    );
    expect(formData.files.map((entry) => entry.key), ['photos[]']);
    expect(formData.files.single.value.filename, 'evidence.jpg');
  });

  test(
    'keeps create idempotency keys when safety drafts are replayed',
    () async {
      final store = _MemorySyncQueueStore();
      var now = DateTime(2026, 9, 27, 10);
      final firstRequests = <RequestOptions>[];
      final firstDio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      )..httpClientAdapter = _NetworkErrorAdapter(firstRequests);
      final repository = SafetyRepository(
        firstDio,
        syncQueueServiceFuture: Future.value(
          SyncQueueService(store: store, dio: firstDio, now: () => now),
        ),
      );

      final actions = <Future<void> Function()>[
        () async => repository.createIncident({
          'project_id': 9,
          'title': 'Проверочный инцидент',
        }),
        () async => repository.createViolation({
          'project_id': 9,
          'title': 'Проверочное нарушение',
        }),
        () async => repository.createInspectionFinding({
          'project_id': 9,
          'title': 'Проверенное замечание',
        }),
      ];

      for (final action in actions) {
        await expectLater(action(), throwsA(isA<SyncQueuedException>()));
      }

      final queued = await store.all();
      final keys =
          queued
              .map(
                (operation) => operation.payload['idempotency_key'] as String,
              )
              .toList();
      expect(keys, hasLength(3));
      expect(keys.toSet(), hasLength(3));
      expect(keys, everyElement(matches(RegExp(r'^[A-Za-z0-9_-]{16,128}$'))));
      expect(firstRequests, hasLength(3));
      for (var index = 0; index < queued.length; index++) {
        expect(
          firstRequests[index].headers['Idempotency-Key'],
          queued[index].payload['idempotency_key'],
        );
      }

      final replayRequests = <RequestOptions>[];
      final replayDio = Dio(
        BaseOptions(baseUrl: 'https://mobile-api.test/api/v1/mobile'),
      )..httpClientAdapter = _SuccessAdapter(replayRequests);
      now = now.add(const Duration(minutes: 3));
      final result =
          await SyncQueueService(
            store: store,
            dio: replayDio,
            now: () => now,
          ).retryDueOperations();

      expect(result.successCount, 3);
      expect(replayRequests, hasLength(3));
      for (final operation in queued) {
        final request = replayRequests.singleWhere(
          (request) => request.path == operation.endpoint,
        );
        expect(
          request.headers['Idempotency-Key'],
          operation.payload['idempotency_key'],
        );
      }
      expect(await store.all(), isEmpty);
    },
  );
}

class _FindingResourceAdapter implements HttpClientAdapter {
  _FindingResourceAdapter(this.requests);

  final List<RequestOptions> requests;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    requests.add(options);
    final page = int.tryParse(options.queryParameters['page'].toString()) ?? 1;
    final rows = page == 1
        ? [
            {
              'id': 27,
              'organization_id': 38,
              'project_id': 52,
              'inspection_id': 11,
              'inspection_item_id': 4,
              'assigned_to_user_id': 39,
              'created_by_user_id': 39,
              'finding_number': 'ЗН-27',
              'title': 'Ограждение проёма не закреплено',
              'description': 'Требуется закрепить секцию.',
              'severity': 'high',
              'status': 'open',
              'status_label': 'Открыто',
              'due_date': '2026-09-30',
              'evidence_files': [],
              'problem_flags': [],
              'metadata': {},
            },
          ]
        : <Map<String, dynamic>>[];
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': null, 'data': rows}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

class _SafetyPaginationAdapter implements HttpClientAdapter {
  _SafetyPaginationAdapter(
    this.requests, {
    this.emptySecondPage = false,
    this.repeatSecondPage = false,
    this.uniqueFullPages = false,
  });

  final List<RequestOptions> requests;
  final bool emptySecondPage;
  final bool repeatSecondPage;
  final bool uniqueFullPages;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final page = int.parse(options.queryParameters['page'].toString());
    final items =
        page == 1 || repeatSecondPage
            ? List.generate(100, (index) => {'id': index + 1})
            : uniqueFullPages
            ? List.generate(100, (index) => {'id': page * 100 + index + 1})
            : emptySecondPage
            ? <Map<String, int>>[]
            : [
              <String, int>{'id': 101},
            ];
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': items}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _NetworkErrorAdapter implements HttpClientAdapter {
  _NetworkErrorAdapter(this.requests);

  final List<RequestOptions> requests;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
}

class _SuccessAdapter implements HttpClientAdapter {
  _SuccessAdapter(this.requests);

  final List<RequestOptions> requests;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': <String, dynamic>{}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _MemorySyncQueueStore implements SyncQueueStore {
  final _operations = <int, QueuedSyncOperation>{};
  var _nextId = 1;

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == Isar.autoIncrement) operation.id = _nextId++;
    _operations[operation.id] = operation;
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async => _operations.values.toList();

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async => all();

  @override
  Future<QueuedSyncOperation?> get(int id) async => _operations[id];

  @override
  Future<void> delete(int id) async => _operations.remove(id);
}
