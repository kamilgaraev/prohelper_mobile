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
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('загружает все страницы дефектов с прежними фильтрами', () async {
    final adapter = _PaginatedDefectsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final repository = QualityControlRepository(dio);

    final defects = await repository.fetchDefects(
      perPage: 1,
      projectId: 9,
      status: 'open',
      severity: 'major',
      overdueOnly: true,
    );

    expect(defects.map((defect) => defect.id), [1, 2]);
    expect(adapter.requests, hasLength(2));
    for (var index = 0; index < adapter.requests.length; index++) {
      final query = adapter.requests[index].queryParameters;
      expect(query['page'], index + 1);
      expect(query['per_page'], 1);
      expect(query['project_id'], 9);
      expect(query['status'], 'open');
      expect(query['severity'], 'major');
      expect(query['overdue'], 1);
    }
  });

  test('не возвращает неполный список при ошибке следующей страницы', () async {
    final adapter = _PaginatedDefectsAdapter(failOnPage: 2);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    final repository = QualityControlRepository(dio);

    await expectLater(
      repository.fetchDefects(perPage: 1),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests, hasLength(2));
  });

  test(
    'offline defect creation keeps one key through automatic replay',
    () async {
      final store = _PersistedSyncQueueStore();
      var now = DateTime(2026, 9, 27, 18, 30);
      final firstAdapter = _TypedErrorAdapter(DioExceptionType.connectionError);
      final firstDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = firstAdapter;
      final repository = QualityControlRepository(
        firstDio,
        syncQueueServiceFuture: Future.value(
          SyncQueueService(store: store, dio: firstDio, now: () => now),
        ),
      );

      await expectLater(
        repository.createDefect({
          'project_id': 9,
          'title': 'Новый дефект',
          'severity': 'major',
        }),
        throwsA(
          isA<SyncQueuedException>()
              .having(
                (error) => error.requiresReview,
                'requiresReview',
                isFalse,
              )
              .having(
                (error) => error.message,
                'message',
                SyncQueueMessages.queuedForNetwork,
              ),
        ),
      );

      final queued = (await store.all()).single;
      final key = queued.payload['idempotency_key'] as String;
      expect(queued.operationType, 'create_defect');
      expect(key, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(firstAdapter.lastRequest?.headers['Idempotency-Key'], key);
      expect(queued.status, SyncOperationStatuses.queued);
      expect(queued.nextAttemptAt, isNotNull);
      expect(queued.lastBusinessError, SyncQueueMessages.queuedForNetwork);

      now = now.add(const Duration(minutes: 2));
      final replayAdapter = _CaptureSuccessAdapter();
      final replayDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = replayAdapter;
      final replay =
          await SyncQueueService(
            store: store,
            dio: replayDio,
            now: () => now,
            verifyOnline: () async => true,
          ).retryDueOperations();

      expect(replay.successCount, 1);
      expect(replay.blockedCount, 0);
      expect(await store.all(), isEmpty);
      expect(replayAdapter.lastRequest?.headers['Idempotency-Key'], key);
    },
  );

  test('loads assignment candidates and assigns a defect', () async {
    final queue =
        TestDioResponseQueue()
          ..respond('GET', '/quality-control/defects/7/assignees', {
            'success': true,
            'data': [
              {'id': 14, 'name': 'Иван Петров', 'email': 'ivan@example.test'},
            ],
          })
          ..respond('POST', '/quality-control/defects/7/assign', {
            'success': true,
            'data': {},
          });
    final repository = QualityControlRepository(queue.buildDio());

    final users = await repository.fetchAssignees(7);
    await repository.assignDefect(7, userId: users.single.id);

    expect(users.single.name, 'Иван Петров');
    expect(queue.requests.last.path, '/quality-control/defects/7/assign');
    expect((queue.requests.last.data as Map)['assigned_to'], 14);
  });

  test(
    'sends before photos as multipart attachments when creating defect',
    () async {
      final queue = TestDioResponseQueue();
      queue.respond('POST', '/quality-control/defects', {
        'success': true,
        'data': _defectPayload(),
      });
      final photos = await _createTempPhotos('quality-before', 2);

      final repository = QualityControlRepository(queue.buildDio());

      await repository.createDefect({
        'project_id': 9,
        'title': 'Скол плитки',
        'severity': 'major',
        'inspection_required': false,
      }, photoPaths: photos.map((photo) => photo.path).toList());

      final request = queue.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/quality-control/defects');
      expect(request.data, isA<FormData>());

      final formData = request.data as FormData;
      expect(_field(formData, 'project_id'), '9');
      expect(_field(formData, 'title'), 'Скол плитки');
      expect(_field(formData, 'inspection_required'), '0');
      expect(_field(formData, 'photos[0][type]'), 'before');
      expect(_field(formData, 'photos[1][type]'), 'before');
      expect(formData.files[0].key, 'photos[0][file]');
      expect(formData.files[0].value.filename, photos[0].uri.pathSegments.last);
      expect(formData.files[1].key, 'photos[1][file]');
      expect(formData.files[1].value.filename, photos[1].uri.pathSegments.last);
    },
  );

  test(
    'sends after photos as multipart attachments when resolving defect',
    () async {
      final queue = TestDioResponseQueue();
      queue.respond('POST', '/quality-control/defects/7/resolve', {
        'success': true,
        'data': _defectPayload(status: 'ready_for_review'),
      });
      final photos = await _createTempPhotos('quality-after', 2);

      final repository = QualityControlRepository(queue.buildDio());

      await repository.resolveDefect(
        7,
        comment: 'Исправлено',
        photoPaths: photos.map((photo) => photo.path).toList(),
      );

      final request = queue.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/quality-control/defects/7/resolve');
      expect(request.data, isA<FormData>());

      final formData = request.data as FormData;
      expect(_field(formData, 'comment'), 'Исправлено');
      expect(_field(formData, 'photos[0][type]'), 'after');
      expect(_field(formData, 'photos[1][type]'), 'after');
      expect(formData.files[0].key, 'photos[0][file]');
      expect(formData.files[0].value.filename, photos[0].uri.pathSegments.last);
      expect(formData.files[1].key, 'photos[1][file]');
      expect(formData.files[1].value.filename, photos[1].uri.pathSegments.last);
    },
  );

  test(
    'queued defect photo survives worker restart and uploads as multipart',
    () async {
      final directory = await Directory.systemTemp.createTemp('quality-queue-');
      addTearDown(() => directory.delete(recursive: true));
      final photo = File('${directory.path}/before.jpg');
      await photo.writeAsBytes(utf8.encode('persisted-photo-bytes'));

      final store = _PersistedSyncQueueStore();
      var now = DateTime(2026, 9, 27, 10);
      final firstDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _TypedErrorAdapter(
          DioExceptionType.connectionTimeout,
        );
      final firstWorker = SyncQueueService(
        store: store,
        dio: firstDio,
        now: () => now,
      );
      final repository = QualityControlRepository(
        firstDio,
        syncQueueServiceFuture: Future.value(firstWorker),
      );

      await expectLater(
        repository.createDefect(
          {'project_id': 9, 'title': 'Скол плитки', 'severity': 'major'},
          photoPaths: [photo.path],
        ),
        throwsA(isA<SyncQueuedException>()),
      );

      final persisted = (await store.all()).single;
      expect(persisted.localAttachments, [photo.path]);
      expect(persisted.attachments.single.path, photo.path);

      final uploadAdapter = _MultipartCaptureAdapter();
      now = now.add(const Duration(minutes: 2));
      final restartedWorker = SyncQueueService(
        store: store,
        dio: Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..httpClientAdapter = uploadAdapter,
        now: () => now,
      );
      final result = await restartedWorker.retryDueOperations();

      expect(result.successCount, 1);
      expect(uploadAdapter.body, contains('photos[0][file]'));
      expect(uploadAdapter.body, contains('before.jpg'));
      expect(uploadAdapter.body, contains('persisted-photo-bytes'));
      expect(await store.all(), isEmpty);
    },
  );
}

Future<List<File>> _createTempPhotos(String prefix, int count) async {
  final files = <File>[];
  for (var index = 0; index < count; index++) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      '${Directory.systemTemp.path}/$prefix-$timestamp-$index.jpg',
    );
    files.add(await file.writeAsBytes(<int>[0, 1, 2, 3]));
  }
  addTearDown(() {
    for (final file in files) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });

  return files;
}

String? _field(FormData formData, String key) {
  for (final field in formData.fields) {
    if (field.key == key) {
      return field.value;
    }
  }

  return null;
}

class _TypedErrorAdapter implements HttpClientAdapter {
  _TypedErrorAdapter(this.type);

  final DioExceptionType type;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    throw DioException(requestOptions: options, type: type);
  }
}

class _CaptureSuccessAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      '{"success":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _MultipartCaptureAdapter implements HttpClientAdapter {
  String? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
    }
    body = latin1.decode(bytes.takeBytes());

    return ResponseBody.fromString(
      '{"success":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _PersistedSyncQueueStore implements SyncQueueStore {
  final _operations = <int, QueuedSyncOperation>{};
  var _nextId = 1;

  QueuedSyncOperation _copy(QueuedSyncOperation source) =>
      QueuedSyncOperation()
        ..id = source.id
        ..moduleSlug = source.moduleSlug
        ..operationType = source.operationType
        ..status = source.status
        ..method = source.method
        ..endpoint = source.endpoint
        ..payloadJson = source.payloadJson
        ..attachmentsJson = source.attachmentsJson
        ..localAttachments = List.of(source.localAttachments)
        ..createdAt = source.createdAt
        ..lastAttemptAt = source.lastAttemptAt
        ..nextAttemptAt = source.nextAttemptAt
        ..attemptCount = source.attemptCount
        ..lastBusinessError = source.lastBusinessError;

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == Isar.autoIncrement) {
      operation.id = _nextId++;
    }
    _operations[operation.id] = _copy(operation);
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async =>
      _operations.values.map(_copy).toList();

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async => all();

  @override
  Future<QueuedSyncOperation?> get(int id) async {
    final operation = _operations[id];
    return operation == null ? null : _copy(operation);
  }

  @override
  Future<void> delete(int id) async {
    _operations.remove(id);
  }
}

class _PaginatedDefectsAdapter implements HttpClientAdapter {
  _PaginatedDefectsAdapter({this.failOnPage});

  final int? failOnPage;
  final requests = <RequestOptions>[];

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
    if (page == failOnPage) {
      return ResponseBody.fromString(
        '{"success":false,"message":"Ошибка страницы","data":null}',
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final payload = _defectPayload();
    payload['id'] = page;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': [payload],
        'meta': {
          'current_page': page,
          'last_page': 2,
          'per_page': 1,
          'total': 2,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _defectPayload({String status = 'open'}) {
  return {
    'id': 1,
    'defect_number': 'QD-1',
    'title': 'Скол плитки',
    'severity': 'major',
    'status': status,
    'inspection_required': false,
    'workflow_summary': {
      'status': status,
      'available_actions': ['start'],
      'problem_flags': [],
    },
    'available_actions': ['start'],
    'photos': [],
    'status_history': [],
    'problem_flags': [],
    'created_at': '2026-05-29T10:00:00Z',
    'updated_at': '2026-05-29T10:00:00Z',
  };
}
