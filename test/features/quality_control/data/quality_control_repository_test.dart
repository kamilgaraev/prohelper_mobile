import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test(
    'unkeyed create timeout requires review instead of automatic retry',
    () async {
      final store = _PersistedSyncQueueStore();
      final firstDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _TypedErrorAdapter(
          DioExceptionType.receiveTimeout,
        );
      final repository = QualityControlRepository(
        firstDio,
        syncQueueServiceFuture: Future.value(
          SyncQueueService(store: store, dio: firstDio),
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
              .having((error) => error.requiresReview, 'requiresReview', isTrue)
              .having(
                (error) => error.message,
                'message',
                SyncQueueMessages.unknownOutcome,
              ),
        ),
      );

      final queued = (await store.all()).single;
      expect(queued.operationType, 'create_defect');
      expect(queued.payload, isNot(contains('idempotency_key')));
      expect(queued.status, SyncOperationStatuses.conflict);
      expect(queued.nextAttemptAt, isNull);
      expect(queued.lastBusinessError, SyncQueueMessages.unknownOutcome);

      final replayDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _RejectUnexpectedReplayAdapter();
      final replay =
          await SyncQueueService(
            store: store,
            dio: replayDio,
          ).retryDueOperations();

      expect(replay.blockedCount, 1);
      expect(replay.retryCount, 0);
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

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, type: type);
  }
}

class _RejectUnexpectedReplayAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw StateError('A conflict must not be replayed.');
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
