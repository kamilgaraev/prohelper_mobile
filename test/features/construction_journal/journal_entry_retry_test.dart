import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_draft.dart';
import 'package:prohelpers_mobile/features/construction_journal/data/construction_journal_repository.dart';

void main() {
  test('persisted in-flight submit is reviewed after worker restart', () async {
    final store = _MemorySyncQueueStore();
    final firstDio = Dio();
    final queue = SyncQueueService(
      store: store,
      dio: firstDio,
      currentScope: () => '9:3',
    );
    await queue.enqueue(
      const SyncQueueDraft(
        moduleSlug: 'construction_journal',
        operationType: 'create_and_submit_entry',
        method: 'POST',
        endpoint: '/construction-journals/7/entries',
        payload: {
          'journal_id': 7,
          'idempotency_key': 'create-key',
          'created_entry_id': 42,
          'submit_intent': true,
        },
      ),
    );

    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();
    firstDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestStarted.complete();
          releaseRequest.future.then((_) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
          });
        },
      ),
    );
    final repository = ConstructionJournalRepository(
      firstDio,
      syncQueueServiceFuture: Future.value(queue),
    );
    final submitFuture = repository.submitEntry(
      42,
      idempotencyKey: 'submit-key',
      journalId: 7,
    );
    await requestStarted.future;

    expect((await store.all()).single.status, SyncOperationStatuses.sending);

    var replayRequests = 0;
    final restartedDio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                replayRequests++;
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {'data': _entry(42, status: 'submitted')},
                  ),
                );
              },
            ),
          );
    final restartedWorker = SyncQueueService(
      store: store,
      dio: restartedDio,
      currentScope: () => '9:3',
    );
    final restartResult = await restartedWorker.retryDueOperations();

    expect(restartResult.blockedCount, 1);
    expect(replayRequests, 0);
    final afterRestart = (await store.all()).single;
    expect(afterRestart.status, SyncOperationStatuses.conflict);
    expect(afterRestart.lastBusinessError, SyncQueueMessages.unknownOutcome);

    releaseRequest.complete();
    await expectLater(
      submitFuture,
      throwsA(
        isA<SyncQueuedException>().having(
          (error) => error.requiresReview,
          'requiresReview',
          isTrue,
        ),
      ),
    );
    expect((await store.all()).single.status, SyncOperationStatuses.conflict);
  });

  test(
    'a restored operation cannot be replayed after switching session',
    () async {
      final store = _MemorySyncQueueStore();
      var scope = '9:3';
      var requests = 0;
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  requests++;
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {'data': _entry(42)},
                    ),
                  );
                },
              ),
            );
      final queue = SyncQueueService(
        store: store,
        dio: dio,
        currentScope: () => scope,
      );
      await queue.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'create_entry',
          method: 'POST',
          endpoint: '/construction-journals/7/entries',
          payload: {
            'queue_scope': '9:3',
            'idempotency_key': 'scoped',
            'journal_id': 7,
          },
        ),
      );
      final repo = ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );
      final pending = (await repo.findPendingEntryOperation(7))!;
      scope = '10:3';
      await expectLater(
        repo.retryPendingCreate(pending),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 0);
    },
  );
  test(
    'offline repeated create retains one operation and the original payload across restart',
    () async {
      final store = _MemorySyncQueueStore();
      final bodies = <Object?>[];
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  bodies.add(options.data);
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.connectionError,
                    ),
                  );
                },
              ),
            );
      Future<void> attempt(String text) async {
        final queue = SyncQueueService(
          store: store,
          dio: dio,
          currentScope: () => '9:3',
        );
        final repo = ConstructionJournalRepository(
          dio,
          syncQueueServiceFuture: Future.value(queue),
        );
        await expectLater(
          repo.createEntry(
            journalId: 7,
            entryDate: '2026-09-20',
            workDescription: text,
            submitIntent: true,
            idempotencyKey: 'offline-key',
          ),
          throwsA(isA<SyncQueuedException>()),
        );
      }

      await attempt('Исходные данные');
      await attempt('Изменённые данные');
      expect(await store.all(), hasLength(1));
      expect(bodies[1], bodies[0]);
    },
  );
  test(
    'ambiguous submit outcome is reviewed without replaying the POST',
    () async {
      final store = _MemorySyncQueueStore();
      final requests = <RequestOptions>[];
      var submitAttempts = 0;
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  requests.add(options);
                  if (options.path.endsWith('/submit') &&
                      submitAttempts++ == 0) {
                    handler.reject(
                      DioException(
                        requestOptions: options,
                        type: DioExceptionType.connectionError,
                      ),
                    );
                  } else {
                    handler.resolve(
                      Response(
                        requestOptions: options,
                        data: {
                          'data': _entry(
                            42,
                            status:
                                options.path.endsWith('/submit')
                                    ? 'submitted'
                                    : 'draft',
                          ),
                        },
                      ),
                    );
                  }
                },
              ),
            );
      final queue = SyncQueueService(
        store: store,
        dio: dio,
        currentScope: () => '9:3',
      );
      final repo = ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );
      await repo.createEntry(
        journalId: 7,
        entryDate: '2026-09-20',
        workDescription: 'Монтаж',
        submitIntent: true,
        idempotencyKey: 'fixed-create',
      );
      await expectLater(
        repo.submitEntry(
          42,
          journalId: 7,
          idempotencyKey: 'fixed-create:submit',
        ),
        throwsA(isA<SyncQueuedException>()),
      );
      final restarted = SyncQueueService(
        store: store,
        dio: dio,
        currentScope: () => '9:3',
      );
      final replay = await restarted.retryDueOperations();
      expect(replay.successCount, 0);
      expect(requests.map((r) => r.path), [
        '/construction-journals/7/entries',
        '/journal-entries/42/submit',
      ]);
      expect((await store.all()).single.status, SyncOperationStatuses.conflict);
    },
  );
  test('keeps created id and requires review after ambiguous submit', () async {
    final store = _MemorySyncQueueStore();
    var createCalls = 0;
    var submitCalls = 0;
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.path.contains('/entries') &&
                    !options.path.contains('/submit')) {
                  createCalls++;
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {'data': _entry(42)},
                    ),
                  );
                  return;
                }
                if (options.path.endsWith('/submit')) {
                  submitCalls++;
                  if (submitCalls == 1) {
                    handler.reject(
                      DioException(
                        requestOptions: options,
                        type: DioExceptionType.connectionError,
                      ),
                    );
                    return;
                  }
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {'data': _entry(42, status: 'submitted')},
                    ),
                  );
                  return;
                }
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.unknown,
                  ),
                );
              },
            ),
          );
    final queue = SyncQueueService(store: store, dio: dio);
    final repository = ConstructionJournalRepository(
      dio,
      syncQueueServiceFuture: Future.value(queue),
    );

    final created = await repository.createEntry(
      journalId: 7,
      entryDate: '2026-09-20',
      workDescription: 'Бетонирование стен',
      idempotencyKey: 'journal-operation-1',
    );
    expect(created.id, 42);

    await expectLater(
      repository.submitEntry(42, idempotencyKey: 'journal-operation-1:submit'),
      throwsA(isA<SyncQueuedException>()),
    );
    expect(createCalls, 1);
    expect(submitCalls, 1);
    expect(
      (await store.all()).single.payload['idempotency_key'],
      'journal-operation-1:submit',
    );

    final result = await queue.retryDueOperations();
    expect(result.successCount, 0);
    expect(createCalls, 1);
    expect(submitCalls, 1);
    expect((await store.all()).single.status, SyncOperationStatuses.conflict);
  });

  test(
    'treats an already submitted entry as recovered after a 422 response',
    () async {
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  if (options.path.endsWith('/submit')) {
                    handler.reject(
                      DioException(
                        requestOptions: options,
                        response: Response(
                          requestOptions: options,
                          statusCode: 422,
                        ),
                      ),
                    );
                    return;
                  }
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {'data': _entry(42, status: 'submitted')},
                    ),
                  );
                },
              ),
            );
      final repository = ConstructionJournalRepository(dio);

      final result = await repository.submitEntry(
        42,
        idempotencyKey: 'same-submit',
      );
      expect(result.id, 42);
      expect(result.status, 'submitted');
    },
  );

  test(
    'worker removes submit after lost response when server already submitted',
    () async {
      final store = _MemorySyncQueueStore();
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  if (options.path.endsWith('/submit')) {
                    handler.reject(
                      DioException(
                        requestOptions: options,
                        response: Response(
                          requestOptions: options,
                          statusCode: 422,
                        ),
                      ),
                    );
                    return;
                  }
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {'data': _entry(42, status: 'submitted')},
                    ),
                  );
                },
              ),
            );
      final queue = SyncQueueService(store: store, dio: dio);
      await queue.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'submit_entry',
          method: 'POST',
          endpoint: '/journal-entries/42/submit',
          payload: {'idempotency_key': 'same-submit', 'journal_id': 7},
        ),
      );

      final result = await queue.retryDueOperations();
      expect(result.successCount, 1);
      expect(await store.all(), isEmpty);
    },
  );

  test('keeps created stage across restart before submit', () async {
    final store = _MemorySyncQueueStore();
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.resolve(
                  Response(requestOptions: options, data: {'data': _entry(42)}),
                );
              },
            ),
          );
    final queue = SyncQueueService(store: store, dio: dio);
    final repository = ConstructionJournalRepository(
      dio,
      syncQueueServiceFuture: Future.value(queue),
    );
    await repository.createEntry(
      journalId: 7,
      entryDate: '2026-09-20',
      workDescription: 'Смена',
      submitIntent: true,
      idempotencyKey: 'restart-key',
    );
    final recovered = await repository.findPendingEntryOperation(7);
    expect(recovered?.entryId, 42);
    expect(recovered?.payload['idempotency_key'], 'restart-key');
    expect(recovered?.payload['submit_intent'], true);
  });

  test(
    'does not restore a queued operation from another session scope',
    () async {
      final store = _MemorySyncQueueStore();
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  fail('foreign scoped operation must not trigger a GET');
                },
              ),
            );
      final queue = SyncQueueService(
        store: store,
        dio: dio,
        currentScope: () => 'user-a:org-a',
      );
      await store.put(
        QueuedSyncOperation.fromDraft(
          const SyncQueueDraft(
            moduleSlug: 'construction_journal',
            operationType: 'create_entry',
            method: 'POST',
            endpoint: '/construction-journals/7/entries',
            payload: {
              'idempotency_key': 'foreign-key',
              'journal_id': 7,
              'queue_scope': 'user-b:org-b',
            },
          ),
          createdAt: DateTime.utc(2026, 9, 20),
        ),
      );
      final repository = ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );
      expect(await repository.findPendingEntryOperation(7), isNull);
    },
  );
  test(
    'does not send confirmation or acting bypass fields on the wire',
    () async {
      final store = _MemorySyncQueueStore();
      Map<String, dynamic>? body;
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  body = Map<String, dynamic>.from(options.data as Map);
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {'data': _entry(42)},
                    ),
                  );
                },
              ),
            );
      final queue = SyncQueueService(
        store: store,
        dio: dio,
        currentScope: () => '9:3',
      );
      await queue.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'create_entry',
          method: 'POST',
          endpoint: '/construction-journals/7/entries',
          payload: {
            'queue_scope': '9:3',
            'idempotency_key': 'legacy',
            'journal_id': 7,
            'entry_date': '2026-09-20',
            'work_description': 'Монтаж',
            'confirm': true,
            'act': true,
            'skip_readiness': true,
          },
        ),
      );
      final repo = ConstructionJournalRepository(
        dio,
        syncQueueServiceFuture: Future.value(queue),
      );
      final pending = (await repo.findPendingEntryOperation(7))!;
      await repo.retryPendingCreate(pending);
      expect(body, isNotNull);
      expect(body!.containsKey('confirm'), isFalse);
      expect(body!.containsKey('act'), isFalse);
      expect(body!.containsKey('skip_readiness'), isFalse);
      expect(body!.containsKey('queue_scope'), isFalse);
    },
  );
}

Map<String, dynamic> _entry(int id, {String status = 'draft'}) => {
  'id': id,
  'journal_id': 7,
  'entry_date': '2026-09-20',
  'entry_number': 1,
  'work_description': 'Бетонирование стен',
  'status': status,
  'status_label': status,
  'workflow_state': 'ready',
  'workVolumes': <Map<String, dynamic>>[],
  'workers': <Map<String, dynamic>>[],
  'equipment': <Map<String, dynamic>>[],
  'materials': <Map<String, dynamic>>[],
  'blockers': <Map<String, dynamic>>[],
  'available_actions': <Map<String, dynamic>>[],
};

class _MemorySyncQueueStore implements SyncQueueStore {
  final List<QueuedSyncOperation> operations = [];
  int _nextId = 1;

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
      operations.add(_copy(operation));
    } else {
      final index = operations.indexWhere((item) => item.id == operation.id);
      if (index >= 0) {
        operations[index] = _copy(operation);
      } else {
        operations.add(_copy(operation));
      }
    }
    return operation;
  }

  @override
  Future<List<QueuedSyncOperation>> all() async =>
      operations.map(_copy).toList();

  @override
  Future<List<QueuedSyncOperation>> due(DateTime now) async => all();

  @override
  Future<QueuedSyncOperation?> get(int id) async {
    for (final operation in operations) {
      if (operation.id == id) {
        return _copy(operation);
      }
    }
    return null;
  }

  @override
  Future<void> delete(int id) async =>
      operations.removeWhere((item) => item.id == id);
}
