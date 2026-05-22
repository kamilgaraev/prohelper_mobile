import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_draft.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_repository.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';

void main() {
  test('queues draft when network unavailable', () async {
    final store = _MemorySyncQueueStore();
    final service = SyncQueueService(
      store: store,
      dio: Dio(),
      now: () => DateTime(2026, 5, 22, 10),
    );
    final repository = _QueueAwareHarness(Future.value(service));

    await expectLater(
      repository.submitWithNetworkError(_siteRequestDraft()),
      throwsA(isA<SyncQueuedException>()),
    );

    final operations = await store.all();
    expect(operations, hasLength(1));
    expect(operations.single.moduleSlug, 'site_requests');
    expect(operations.single.operationType, 'create_site_request');
    expect(operations.single.status, SyncOperationStatuses.queued);
    expect(operations.single.lastBusinessError, isNull);
  });

  test('retries queued draft after network returns', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    final dio = _dio(adapter);
    final service = SyncQueueService(
      store: store,
      dio: dio,
      now: () => DateTime(2026, 5, 22, 10),
    );

    await service.enqueue(_siteRequestDraft());
    final result = await service.retryDueOperations();

    expect(result.successCount, 1);
    expect(result.retryCount, 0);
    expect(await store.all(), isEmpty);
    expect(adapter.requests.single.path, '/site-requests');
    expect(adapter.requests.single.method, 'POST');
  });

  test('does not retry validation error until user edits draft', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            _AdapterResponse(
              statusCode: 422,
              body: '{"message":"Проверьте количество"}',
            ),
          )
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      now: () => DateTime(2026, 5, 22, 10),
    );

    final queued = await service.enqueue(_siteRequestDraft());
    final blockedResult = await service.retryDueOperations();

    expect(blockedResult.blockedCount, 1);
    final blocked = await store.get(queued.id);
    expect(blocked?.status, SyncOperationStatuses.needsEdit);
    expect(blocked?.lastBusinessError, 'Проверьте количество');

    final skippedResult = await service.retryDueOperations();
    expect(skippedResult.successCount, 0);
    expect(adapter.requests, hasLength(1));

    await service.replaceDraftPayload(
      queued.id,
      payload: <String, dynamic>{
        'project_id': 15,
        'title': 'Материалы',
        'quantity': 12,
      },
      attachments: const <SyncAttachmentRef>[],
    );
    final successResult = await service.retryDueOperations();

    expect(successResult.successCount, 1);
    expect(await store.all(), isEmpty);
    expect(adapter.requests, hasLength(2));
  });

  test('removes queued item after successful submit', () async {
    final store = _MemorySyncQueueStore();
    final service = SyncQueueService(
      store: store,
      dio: _dio(
        _QueueHttpAdapter()
          ..responses.add(
            _AdapterResponse(statusCode: 201, body: '{"ok":true}'),
          ),
      ),
      now: () => DateTime(2026, 5, 22, 10),
    );

    final queued = await service.enqueue(_siteRequestDraft());
    await service.retryDueOperations();

    expect(await store.get(queued.id), isNull);
  });

  test('keeps local attachment reference until upload succeeds', () async {
    final tempDir = await Directory.systemTemp.createTemp('sync-queue-test-');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final photo = File('${tempDir.path}${Platform.pathSeparator}receipt.jpg');
    await photo.writeAsBytes(<int>[1, 2, 3, 4]);

    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(_AdapterResponse.networkError())
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      now: () => DateTime(2026, 5, 22, 10),
    );

    final queued = await service.enqueue(
      SyncQueueDraft(
        moduleSlug: 'warehouse',
        operationType: 'create_receipt',
        method: 'POST',
        endpoint: '/warehouse/operations/receipt',
        payload: const <String, dynamic>{
          'warehouse_id': '1',
          'material_id': '5',
          'quantity': '2',
          'price': '100',
        },
        attachments: <SyncAttachmentRef>[
          SyncAttachmentRef(
            field: 'photos[]',
            path: photo.path,
            filename: 'receipt.jpg',
          ),
        ],
      ),
    );

    final retryResult = await service.retryDueOperations();
    final retained = await store.get(queued.id);

    expect(retryResult.retryCount, 1);
    expect(retained?.localAttachments, <String>[photo.path]);
    expect(retained?.status, SyncOperationStatuses.queued);

    await service.replaceDraftPayload(
      queued.id,
      payload: retained!.payload,
      attachments: retained.attachments,
    );
    final successResult = await service.retryDueOperations();

    expect(successResult.successCount, 1);
    expect(await store.get(queued.id), isNull);
  });
}

SyncQueueDraft _siteRequestDraft() {
  return const SyncQueueDraft(
    moduleSlug: 'site_requests',
    operationType: 'create_site_request',
    method: 'POST',
    endpoint: '/site-requests',
    payload: <String, dynamic>{'project_id': 15, 'title': 'Материалы'},
  );
}

Dio _dio(_QueueHttpAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.prohelper.test',
      headers: const <String, dynamic>{'Content-Type': 'application/json'},
    ),
  )..httpClientAdapter = adapter;
}

class _QueueAwareHarness extends SyncQueueAwareRepository {
  const _QueueAwareHarness(super.syncQueueServiceFuture);

  Future<void> submitWithNetworkError(SyncQueueDraft draft) {
    return executeOrQueue(
      request: () async {
        throw DioException(
          requestOptions: RequestOptions(path: draft.endpoint),
          type: DioExceptionType.connectionError,
        );
      },
      draft: draft,
      businessMessage: 'Не удалось отправить.',
    );
  }
}

class _MemorySyncQueueStore implements SyncQueueStore {
  final _operations = <int, QueuedSyncOperation>{};
  var _nextId = 1;

  @override
  Future<QueuedSyncOperation> put(QueuedSyncOperation operation) async {
    if (operation.id == Isar.autoIncrement) {
      operation.id = _nextId++;
    }
    _operations[operation.id] = operation;

    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async {
    final operations = _operations.values.toList();
    operations.sort((left, right) => left.createdAt.compareTo(right.createdAt));

    return operations;
  }

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async {
    final operations = await all();

    return operations.where((operation) {
      if (operation.status != SyncOperationStatuses.queued) {
        return false;
      }

      final nextAttemptAt = operation.nextAttemptAt;
      return nextAttemptAt == null || !nextAttemptAt.isAfter(now);
    }).toList();
  }

  @override
  Future<QueuedSyncOperation?> get(int id) async => _operations[id];

  @override
  Future<void> delete(int id) async {
    _operations.remove(id);
  }
}

class _QueueHttpAdapter implements HttpClientAdapter {
  final responses = Queue<_AdapterResponse>();
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    final response = responses.removeFirst();
    if (response.errorType != null) {
      throw DioException(requestOptions: options, type: response.errorType!);
    }

    return ResponseBody.fromString(
      response.body,
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterResponse {
  const _AdapterResponse({
    required this.statusCode,
    required this.body,
    this.errorType,
  });

  factory _AdapterResponse.networkError() {
    return const _AdapterResponse(
      statusCode: 0,
      body: '',
      errorType: DioExceptionType.connectionError,
    );
  }

  final int statusCode;
  final String body;
  final DioExceptionType? errorType;
}
