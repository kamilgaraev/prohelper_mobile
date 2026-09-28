import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';

void main() {
  test('loads filtered scopes from the backend items/meta envelope', () async {
    late RequestOptions request;
    final scope =
        Map<String, dynamic>.from(_scopeResponse('/scopes')['data'] as Map)
          ..['status'] = 'in_progress'
          ..['workflow_summary'] = {
            'status': 'in_progress',
            'available_actions': ['create_finding', 'accept', 'reject'],
            'problem_flags': [],
            'readiness': {'ready': true, 'blockers': []},
          }
          ..['checklists'] = [
            {
              'id': 17,
              'acceptance_scope_id': 71,
              'title': 'Приемка',
              'status': 'active',
              'items': [
                {
                  'id': 31,
                  'title': 'Поверхности',
                  'is_required': true,
                  'status': 'pending',
                  'available_actions': ['accept', 'reject'],
                  'comment': null,
                },
              ],
            },
          ]
          ..['sessions'] = [
            {
              'id': 44,
              'acceptance_scope_id': 71,
              'status': 'in_progress',
              'participant_user_ids': [5],
              'findings': [
                {
                  'id': 81,
                  'acceptance_session_id': 44,
                  'title': 'Трещина',
                  'severity': 'major',
                  'status': 'open',
                },
              ],
            },
          ]
          ..['findings'] = [
            {
              'id': 81,
              'acceptance_session_id': 44,
              'title': 'Трещина',
              'severity': 'major',
              'status': 'open',
            },
          ];
    final dio = _dio((options) {
      request = options;
      return {
        'success': true,
        'message': null,
        'data': {
          'items': [scope],
          'meta': {
            'total': 1,
            'project_id': 8,
            'status': 'in_progress',
            'planned_from': '2026-09-01',
            'planned_to': '2026-09-30',
          },
        },
      };
    });

    final scopes = await HandoverAcceptanceRepository(dio).fetchScopes(
      projectId: 8,
      status: 'in_progress',
      plannedFrom: '2026-09-01',
      plannedTo: '2026-09-30',
    );

    expect(request.method, 'GET');
    expect(request.path, '/handover-acceptance/scopes');
    expect(request.queryParameters, {
      'project_id': 8,
      'status': 'in_progress',
      'planned_from': '2026-09-01',
      'planned_to': '2026-09-30',
    });
    expect(scopes, hasLength(1));
    expect(scopes.single.id, 71);
    expect(scopes.single.workflowSummary.availableActions, [
      'create_finding',
      'accept',
      'reject',
    ]);
    expect(scopes.single.checklists.single.items.single.availableActions, [
      'accept',
      'reject',
    ]);
    expect(scopes.single.sessions.single.findings.single.title, 'Трещина');
    expect(scopes.single.findings.single.status, 'open');
  });

  test(
    'sends each handover action to its backend route with its payload',
    () async {
      final calls = <RequestOptions>[];
      final dio = _dio((options) {
        calls.add(options);
        if (options.path.endsWith('/review')) return _checklistResponse();
        if (options.path.endsWith('/findings') ||
            options.path.endsWith('/resolve')) {
          return _findingResponse();
        }
        return _scopeResponse(options.path);
      });
      final repository = HandoverAcceptanceRepository(dio);

      final reviewed = await repository.reviewChecklistItem(
        31,
        status: 'rejected',
        comment: ' Требует доработки ',
      );
      final created = await repository.createFinding(44, {
        'title': 'Трещина',
        'description': 'Стена у окна',
        'severity': 'major',
        'create_quality_defect': true,
        'quality_defect_inspection_required': true,
      });
      final resolved = await repository.resolveFinding(
        51,
        resolutionComment: ' Устранено ',
      );
      final ready = await repository.readyForReinspection(61);
      final started = await repository.startScope(62);
      final accepted = await repository.acceptScope(63, comment: ' Готово ');
      final handedOver = await repository.handoverScope(64);
      final rejected = await repository.rejectScope(
        65,
        reason: ' Есть замечания ',
      );
      final reopened = await repository.reopenScope(
        66,
        reason: ' Повторная проверка ',
      );

      expect(calls.map((call) => call.method), everyElement('POST'));
      expect(calls.map((call) => call.path), [
        '/handover-acceptance/checklist-items/31/review',
        '/handover-acceptance/sessions/44/findings',
        '/handover-acceptance/findings/51/resolve',
        '/handover-acceptance/scopes/61/ready-for-reinspection',
        '/handover-acceptance/scopes/62/start',
        '/handover-acceptance/scopes/63/accept',
        '/handover-acceptance/scopes/64/handover',
        '/handover-acceptance/scopes/65/reject',
        '/handover-acceptance/scopes/66/reopen',
      ]);
      expect(calls.map((call) => call.data), [
        {'status': 'rejected', 'comment': 'Требует доработки'},
        {
          'title': 'Трещина',
          'description': 'Стена у окна',
          'severity': 'major',
          'create_quality_defect': true,
          'quality_defect_inspection_required': true,
        },
        {'resolution_comment': ' Устранено '},
        null,
        null,
        {'comment': 'Готово'},
        null,
        {'reason': 'Есть замечания'},
        {'reason': 'Повторная проверка'},
      ]);
      expect(reviewed.items.single.status, 'accepted');
      expect(created.title, 'Повреждение');
      expect(resolved.status, 'resolved');
      expect(ready.status, 'ready_for_reinspection');
      expect(started.status, 'in_progress');
      expect(accepted.status, 'accepted');
      expect(handedOver.status, 'handed_over');
      expect(rejected.status, 'rejected');
      expect(reopened.status, 'reopened');
    },
  );

  test(
    'uploads a package document as multipart file and parses package',
    () async {
      final directory = await Directory.systemTemp.createTemp('handover-http-');
      final file = File('${directory.path}/evidence.pdf');
      await file.writeAsBytes([37, 80, 68, 70]);
      late RequestOptions request;
      final dio = _dio((options) {
        request = options;
        return {
          'success': true,
          'data': {
            'id': 71,
            'title': 'Передаточный пакет',
            'status': 'draft',
            'documents': [],
          },
        };
      });

      try {
        final package = await HandoverAcceptanceRepository(
          dio,
        ).uploadPackageDocument(19, filePath: file.path);

        expect(request.method, 'POST');
        expect(
          request.path,
          '/handover-acceptance/package-documents/19/upload',
        );
        expect(request.data, isA<FormData>());
        final form = request.data as FormData;
        expect(form.fields, isEmpty);
        expect(form.files.map((entry) => entry.key), ['file']);
        expect(form.files.single.value.filename, 'evidence.pdf');
        expect(package.id, 71);
        expect(package.status, 'draft');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'sends mobile photo evidence with the backend multipart field names',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'handover-photo-',
      );
      final file = File('${directory.path}/evidence.jpg');
      await file.writeAsBytes([255, 216, 255]);
      late RequestOptions request;
      final dio = _dio((options) {
        request = options;
        return _checklistResponse();
      });

      try {
        await HandoverAcceptanceRepository(dio).reviewChecklistItem(
          31,
          status: 'rejected',
          comment: 'Нужна доработка',
          photoPaths: [file.path],
        );

        expect(request.path, '/handover-acceptance/checklist-items/31/review');
        expect(request.data, isA<FormData>());
        final form = request.data as FormData;
        expect(form.fields.map((field) => '${field.key}=${field.value}'), [
          'status=rejected',
          'comment=Нужна доработка',
        ]);
        expect(form.files.map((entry) => entry.key), ['photos[]']);
        expect(form.files.single.value.filename, 'evidence.jpg');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'maps validation and permission errors without queueing actions',
    () async {
      for (final status in [422, 403]) {
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..httpClientAdapter = _FailureAdapter(status);
        final store = _MemoryStore();
        final queue = SyncQueueService(store: store, dio: dio);
        final repository = HandoverAcceptanceRepository(
          dio,
          syncQueueServiceFuture: Future.value(queue),
        );

        await expectLater(
          repository.rejectScope(65, reason: 'Нет доступа'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              status,
            ),
          ),
        );
        await expectLater(
          repository.createFinding(44, const {
            'title': 'Трещина',
            'severity': 'minor',
            'create_quality_defect': false,
          }),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              status,
            ),
          ),
        );
        expect(await store.all(), isEmpty);
      }
    },
  );

  test(
    'queues finding with its endpoint and payload after network failure',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _NetworkErrorAdapter();
      final store = _MemoryStore();
      final queue = SyncQueueService(store: store, dio: Dio());
      final repository = HandoverAcceptanceRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );
      const payload = {
        'title': 'Трещина',
        'description': 'Стена',
        'severity': 'minor',
        'create_quality_defect': false,
      };

      await expectLater(
        repository.createFinding(44, payload),
        throwsA(
          isA<SyncQueuedException>().having(
            (error) => error.requiresReview,
            'requiresReview',
            isTrue,
          ),
        ),
      );

      final queued = (await store.all()).single;
      expect(queued.moduleSlug, 'handover_acceptance');
      expect(queued.operationType, 'create_finding');
      expect(queued.method, 'POST');
      expect(queued.endpoint, '/handover-acceptance/sessions/44/findings');
      expect(queued.payload, payload);
      expect(queued.status, 'conflict');
    },
  );

  test(
    'marks an uncertain server failure for review without replay key',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _FailureAdapter(500);
      final store = _MemoryStore();
      final queue = SyncQueueService(store: store, dio: Dio());
      final repository = HandoverAcceptanceRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );

      await expectLater(
        repository.createFinding(44, const {
          'title': 'Трещина',
          'severity': 'minor',
          'create_quality_defect': false,
        }),
        throwsA(
          isA<SyncQueuedException>().having(
            (error) => error.requiresReview,
            'requiresReview',
            isTrue,
          ),
        ),
      );

      final queued = (await store.all()).single;
      expect(queued.endpoint, '/handover-acceptance/sessions/44/findings');
      expect(queued.status, 'conflict');
      expect(queued.payload.containsKey('idempotency_key'), isFalse);
    },
  );

  test(
    'queues package upload with the local file reference after network failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'handover-queue-',
      );
      final file = File('${directory.path}/handover.pdf');
      await file.writeAsBytes([37, 80, 68, 70]);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _NetworkErrorAdapter();
      final store = _MemoryStore();
      final queue = SyncQueueService(store: store, dio: Dio());
      final repository = HandoverAcceptanceRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );

      try {
        await expectLater(
          repository.uploadPackageDocument(19, filePath: file.path),
          throwsA(
            isA<SyncQueuedException>().having(
              (error) => error.requiresReview,
              'requiresReview',
              isTrue,
            ),
          ),
        );
        final queued = (await store.all()).single;
        expect(queued.moduleSlug, 'handover_acceptance');
        expect(queued.operationType, 'upload_package_document');
        expect(queued.method, 'POST');
        expect(
          queued.endpoint,
          '/handover-acceptance/package-documents/19/upload',
        );
        expect(queued.payload, isEmpty);
        expect(queued.attachments.single.field, 'file');
        expect(queued.attachments.single.path, file.path);
        expect(queued.attachments.single.filename, 'handover.pdf');
        expect(queued.status, 'conflict');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

Map<String, dynamic> _scopeResponse(String path) {
  final status = switch (path.split('/').last) {
    'start' => 'in_progress',
    'ready-for-reinspection' => 'ready_for_reinspection',
    'accept' => 'accepted',
    'handover' => 'handed_over',
    'reject' => 'rejected',
    'reopen' => 'reopened',
    _ => 'planned',
  };
  return {
    'success': true,
    'message': null,
    'data': {
      'id': 71,
      'project_id': 8,
      'project_location_id': null,
      'title': 'Приемка квартиры',
      'description': null,
      'status': status,
      'planned_acceptance_date': '2026-09-28',
      'accepted_at': null,
      'handed_over_at': null,
      'reopened_at': null,
      'photos': [],
      'quantity_revision': 0,
      'work_quantities': [],
      'workflow_summary': {
        'status': status,
        'available_actions': <String>[],
        'problem_flags': [],
        'readiness': {'ready': true, 'blockers': []},
      },
      'project': null,
      'location': null,
      'checklists': [],
      'sessions': [],
      'findings': [],
      'handover_package': null,
    },
  };
}

Map<String, dynamic> _checklistResponse() => {
  'success': true,
  'data': {
    'id': 9,
    'acceptance_scope_id': 71,
    'title': 'Проверка',
    'status': 'active',
    'items': [
      {
        'id': 31,
        'title': 'Поверхности',
        'is_required': true,
        'status': 'accepted',
        'available_actions': [],
        'comment': null,
      },
    ],
  },
};

Map<String, dynamic> _findingResponse() => {
  'success': true,
  'data': {
    'id': 81,
    'acceptance_session_id': 44,
    'title': 'Повреждение',
    'description': null,
    'severity': 'major',
    'status': 'resolved',
  },
};

Dio _dio(Map<String, dynamic> Function(RequestOptions) handler) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = _JsonAdapter(handler);

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);
  final Map<String, dynamic> Function(RequestOptions) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    return ResponseBody.fromString(
      jsonEncode(handler(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FailureAdapter implements HttpClientAdapter {
  _FailureAdapter(this.statusCode);
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'success': false,
      'message': statusCode == 403 ? 'Недостаточно прав' : 'Ошибка проверки',
    }),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _NetworkErrorAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
}

class _MemoryStore implements SyncQueueStore {
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
