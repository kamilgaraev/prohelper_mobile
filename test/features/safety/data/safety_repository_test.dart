import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
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
