import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/encrypted_local_file_cache.dart';
import 'package:prohelpers_mobile/core/sync/queued_sync_operation.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_draft.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_repository.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_service.dart';
import 'package:prohelpers_mobile/core/sync/sync_queue_store.dart';

void main() {
  test('new queued actions require the authenticated session', () async {
    final store = _MemorySyncQueueStore();
    String? scope;
    final service = SyncQueueService(
      store: store,
      dio: _dio(_QueueHttpAdapter()),
      currentScope: () => scope,
    );

    await expectLater(
      service.enqueue(_siteRequestDraft()),
      throwsA(isA<ApiException>()),
    );

    scope = '27:4:session-a';
    await expectLater(
      service.enqueue(
        SyncQueueDraft(
          moduleSlug: 'site_requests',
          operationType: 'create_request',
          method: 'POST',
          endpoint: '/site-requests',
          payload: {'queue_scope': '28:4:session-b'},
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(await store.all(), isEmpty);
  });

  test('ordinary queued action stays in its original session', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    var scope = '27:4:session-a';
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      currentScope: () => scope,
      onlineVerified: () => true,
      verifyOnline: () async => true,
    );

    final operation = await service.enqueue(_siteRequestDraft());
    expect(operation.payload['queue_scope'], scope);

    scope = '28:4:session-b';
    final result = await service.retryQueuedOperations();
    expect(result.successCount, 0);
    expect(result.blockedCount, 1);
    expect(adapter.requests, isEmpty);
  });

  test('manual retry bypasses backoff for a queued operation', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    final now = DateTime(2026, 9, 28, 10);
    var verificationCount = 0;
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      now: () => now,
      currentScope: () => '27:4:session-a',
      onlineVerified: () => true,
      verifyOnline: () async {
        verificationCount++;
        return true;
      },
    );
    final operation = await service.enqueue(
      _siteRequestDraft(idempotencyKey: 'manual-retry-42'),
    );
    operation.nextAttemptAt = now.add(const Duration(hours: 1));
    await service.update(operation);

    final automatic = await service.retryDueOperations();

    expect(automatic.retryCount, 1);
    expect(adapter.requests, isEmpty);
    expect(
      (await store.get(operation.id))?.status,
      SyncOperationStatuses.queued,
    );

    final manual = await service.retryQueuedOperations();

    expect(manual.successCount, 1);
    expect(adapter.requests, hasLength(1));
    expect(
      adapter.requests.single.headers['Idempotency-Key'],
      'manual-retry-42',
    );
    expect(verificationCount, 2);
    expect(await store.all(), isEmpty);
  });

  test('ordinary queued action does not send session scope to API', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      currentScope: () => '27:4:session-a',
      onlineVerified: () => true,
      verifyOnline: () async => true,
    );

    await service.enqueue(_siteRequestDraft());
    expect((await service.retryDueOperations()).successCount, 1);
    expect(
      adapter.requests.single.data.toString(),
      isNot(contains('queue_scope')),
    );
  });

  test('resumes interrupted idempotent action after app restart', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    const scope = '27:4:session-a';
    final firstService = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      currentScope: () => scope,
    );
    final operation = await firstService.enqueue(
      const SyncQueueDraft(
        moduleSlug: 'machinery_operations',
        operationType: 'finish_shift',
        method: 'POST',
        endpoint: '/machinery-operations/shift-reports/42/finish',
        payload: {'idempotency_key': 'finish-shift-42'},
      ),
    );
    operation.status = SyncOperationStatuses.sending;
    await store.put(operation);

    final restartedService = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      currentScope: () => scope,
      onlineVerified: () => true,
      verifyOnline: () async => true,
    );
    final result = await restartedService.retryDueOperations();

    expect(result.successCount, 1);
    expect(
      adapter.requests.single.headers['Idempotency-Key'],
      'finish-shift-42',
    );
    expect(await store.all(), isEmpty);
  });

  test(
    'does not replay interrupted action with unknown server outcome',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter = _QueueHttpAdapter();
      const scope = '27:4:session-a';
      final firstService = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => scope,
      );
      final operation = await firstService.enqueue(_siteRequestDraft());
      operation.status = SyncOperationStatuses.sending;
      await store.put(operation);

      final restartedService = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => scope,
        onlineVerified: () => true,
        verifyOnline: () async => true,
      );
      final result = await restartedService.retryQueuedOperations();
      final recovered = await store.get(operation.id);

      expect(result.blockedCount, 1);
      expect(recovered?.status, SyncOperationStatuses.conflict);
      expect(
        recovered?.lastBusinessError,
        'Неизвестно, выполнено ли действие на сервере. Проверьте его перед повторной отправкой.',
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('current owner sees only its own queued operations', () async {
    final store = _MemorySyncQueueStore();
    var scope = '27:4:session-a';
    final service = SyncQueueService(
      store: store,
      dio: _dio(_QueueHttpAdapter()),
      currentScope: () => scope,
    );
    final own = await service.enqueue(_siteRequestDraft());
    await store.put(
      QueuedSyncOperation.fromDraft(
        const SyncQueueDraft(
          moduleSlug: 'warehouse',
          operationType: 'create_receipt',
          method: 'POST',
          endpoint: '/warehouse/operations/receipt',
          payload: {'queue_scope': '28:4:session-b'},
        ),
        createdAt: DateTime(2026, 8, 23, 11),
      ),
    );
    await store.put(
      QueuedSyncOperation.fromDraft(
        _siteRequestDraft(),
        createdAt: DateTime(2026, 8, 23, 12),
      ),
    );

    expect((await service.forCurrentOwner()).map((item) => item.id), [own.id]);

    scope = '28:4:session-b';
    expect((await service.forCurrentOwner()).single.moduleSlug, 'warehouse');
    scope = '';
    expect(await service.forCurrentOwner(), isEmpty);
  });

  test('reviewed action can only be discarded by its owner', () async {
    final store = _MemorySyncQueueStore();
    var scope = '27:4:session-a';
    final service = SyncQueueService(
      store: store,
      dio: _dio(_QueueHttpAdapter()),
      currentScope: () => scope,
    );
    final operation = await service.enqueue(_siteRequestDraft());

    expect(await service.discardReviewedForCurrentOwner(operation.id), isFalse);
    expect(await store.get(operation.id), isNotNull);

    operation.status = SyncOperationStatuses.conflict;
    await store.put(operation);
    scope = '28:4:session-b';
    await expectLater(
      service.discardReviewedForCurrentOwner(operation.id),
      throwsA(isA<ApiException>()),
    );
    expect(await store.get(operation.id), isNotNull);

    scope = '27:4:session-a';
    expect(await service.discardReviewedForCurrentOwner(operation.id), isTrue);
    expect(await store.get(operation.id), isNull);
    expect(await service.discardReviewedForCurrentOwner(operation.id), isFalse);
  });

  test(
    'publishes enqueue, delete, and flush changes to queue observers',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => '27:4:session-a',
        onlineVerified: () => true,
        verifyOnline: () async => true,
      );
      final changes = StreamIterator<int>(service.changes);
      Future<void> expectChange(String action) async {
        final changed = await changes.moveNext().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
        expect(changed, isTrue, reason: 'Missing queue change after $action.');
      }

      final enqueueChange = expectChange('enqueue');
      final deleted = await service.enqueue(_siteRequestDraft());
      await enqueueChange;
      final deleteChange = expectChange('delete');
      await service.delete(deleted.id);
      await deleteChange;

      final secondEnqueueChange = expectChange('second enqueue');
      await service.enqueue(_siteRequestDraft());
      await secondEnqueueChange;
      final result = await service.retryDueOperations();
      await expectChange('mark sending');
      await expectChange('successful removal');
      expect(result.successCount, 1);
      expect(await store.all(), isEmpty);
      await changes.cancel();
    },
  );

  test('coalesces simultaneous flush requests into one network send', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    final verification = Completer<bool>();
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      verifyOnline: () => verification.future,
    );
    await service.enqueue(_siteRequestDraft());

    final first = service.retryDueOperations();
    final second = service.retryDueOperations();
    verification.complete(true);
    final results = await Future.wait([first, second]);

    expect(identical(first, second), isTrue);
    expect(results.map((result) => result.successCount), everyElement(1));
    expect(adapter.requests, hasLength(1));
  });

  test(
    'clearing an owner waits for an in-flight request before deleting it',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      final requestStarted = Completer<void>();
      final responseGate = Completer<void>();
      adapter.requestStarted = requestStarted;
      adapter.responseGate = responseGate;
      var scope = '27:4:session-a';
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => scope,
        onlineVerified: () => true,
        verifyOnline: () async => true,
      );
      await service.enqueue(_siteRequestDraft());

      final flush = service.retryDueOperations();
      await requestStarted.future;
      scope = '28:4:session-b';
      final clear = service.clearScope('27:4:session-a');
      await Future<void>.delayed(Duration.zero);
      expect(await store.all(), hasLength(1));

      responseGate.complete();
      await Future.wait([flush, clear]);

      expect(await store.all(), isEmpty);
    },
  );

  test('editing a queued action preserves its original session', () async {
    final store = _MemorySyncQueueStore();
    var scope = '27:4:session-a';
    final service = SyncQueueService(
      store: store,
      dio: _dio(_QueueHttpAdapter()),
      currentScope: () => scope,
    );
    final operation = await service.enqueue(_siteRequestDraft());

    await service.replaceDraftPayload(
      operation.id,
      payload: {'project_id': 15, 'title': 'Исправлено'},
      attachments: const [],
    );
    expect((await store.get(operation.id))?.payload['queue_scope'], scope);

    scope = '28:4:session-b';
    await expectLater(
      service.replaceDraftPayload(
        operation.id,
        payload: {'project_id': 15, 'title': 'Чужое изменение'},
        attachments: const [],
      ),
      throwsA(isA<ApiException>()),
    );
    expect((await store.get(operation.id))?.payload['title'], 'Исправлено');
  });

  test(
    'legacy action without session scope does not block new actions',
    () async {
      final store = _MemorySyncQueueStore();
      await store.put(
        QueuedSyncOperation.fromDraft(
          _siteRequestDraft(),
          createdAt: DateTime(2026, 9, 20),
        ),
      );
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => '27:4:session-a',
        onlineVerified: () => true,
        verifyOnline: () async => true,
      );

      await service.enqueue(_siteRequestDraft());
      final result = await service.retryDueOperations();
      expect(result.successCount, 1);
      expect(result.blockedCount, 1);
      expect(adapter.requests, hasLength(1));
      expect(
        (await store.all()).single.status,
        SyncOperationStatuses.permissionDenied,
      );
    },
  );

  test('legal archive queue waits for online identity verification', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            const _AdapterResponse(statusCode: 200, body: '{"data":{}}'),
          );
    var verified = false;
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      currentScope: () => '27:4:session-a',
      onlineVerified: () => verified,
      verifyOnline: () async => verified,
    );
    await service.enqueue(
      const SyncQueueDraft(
        moduleSlug: 'legal_archive',
        operationType: 'approve',
        method: 'POST',
        endpoint: '/legal-archive/documents/8/actions/approve',
        payload: {
          'idempotency_key': 'action-key',
          'instance_lock_version': 4,
          'step_lock_version': 7,
          'queue_scope': '27:4:session-a',
          'queue_owner_identity': '27:4:session-a',
          'queue_user_id': 27,
          'queue_organization_id': 4,
          'queue_session_id': 'session-a',
        },
      ),
    );

    expect((await service.retryQueuedOperations()).successCount, 0);
    expect(adapter.requests, isEmpty);
    expect((await store.all()).single.status, SyncOperationStatuses.queued);

    verified = true;
    expect((await service.retryQueuedOperations()).successCount, 1);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.headers['Idempotency-Key'], 'action-key');
    expect(
      adapter.requests.single.data.toString(),
      isNot(contains('queue_scope')),
    );
    expect(await store.all(), isEmpty);
  });

  test(
    'journal worker pauses for review after ambiguous submit result',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(
                statusCode: 200,
                body: '{"data":{"id":42,"journal_id":7,"status":"draft"}}',
              ),
            )
            ..responses.add(_AdapterResponse.networkError());
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        now: () => DateTime(2026, 9, 20, 10),
        currentScope: () => '9:3',
      );
      await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'create_entry',
          method: 'POST',
          endpoint: '/construction-journals/7/entries',
          payload: {
            'idempotency_key': 'journal-1',
            'queue_scope': '9:3',
            'journal_id': 7,
            'submit_intent': true,
            'submit_after_create': false,
            'work_description': 'Монтаж',
          },
        ),
      );
      final first = await service.retryDueOperations();
      expect(first.blockedCount, 1);
      expect(first.retryCount, 0);
      final saved = (await store.all()).single;
      expect(saved.payload['created_entry_id'], 42);
      expect(saved.endpoint, '/journal-entries/42/submit');
      expect(saved.status, SyncOperationStatuses.conflict);
      expect(saved.lastBusinessError, SyncQueueMessages.unknownOutcome);
      expect(adapter.requests.map((r) => r.path), [
        '/construction-journals/7/entries',
        '/journal-entries/42/submit',
      ]);
      final restarted = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        now: () => DateTime(2026, 9, 20, 11),
        currentScope: () => '9:3',
      );
      expect((await restarted.retryDueOperations()).blockedCount, 1);
      expect(adapter.requests, hasLength(2));
      expect((await store.all()).single.status, SyncOperationStatuses.conflict);
    },
  );

  test(
    'journal worker recovers interrupted sending with known ID without create',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(
                statusCode: 200,
                body: '{"data":{"id":42,"status":"submitted"}}',
              ),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => '9:3',
      );
      final operation = await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'create_entry',
          method: 'POST',
          endpoint: '/construction-journals/7/entries',
          payload: {
            'idempotency_key': 'journal-1',
            'queue_scope': '9:3',
            'journal_id': 7,
            'submit_intent': true,
            'created_entry_id': 42,
            'stage': 'created',
          },
        ),
      );
      operation.status = SyncOperationStatuses.sending;
      await store.put(operation);
      expect((await service.retryDueOperations()).successCount, 1);
      expect(adapter.requests.single.path, '/journal-entries/42/submit');
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'journal worker does not send scoped operation while logged out',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter = _QueueHttpAdapter();
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => null,
      );
      await store.put(
        QueuedSyncOperation.fromDraft(
          const SyncQueueDraft(
            moduleSlug: 'construction_journal',
            operationType: 'submit_entry',
            method: 'POST',
            endpoint: '/journal-entries/42/submit',
            payload: {'queue_scope': '9:3', 'idempotency_key': 'j'},
          ),
          createdAt: DateTime(2026, 9, 20),
        ),
      );
      expect((await service.retryDueOperations()).blockedCount, 1);
      expect(adapter.requests, isEmpty);
      expect(await store.all(), hasLength(1));
    },
  );

  test('keeps an ambiguous initial send for review', () async {
    final store = _MemorySyncQueueStore();
    final service = SyncQueueService(
      store: store,
      dio: Dio(),
      now: () => DateTime(2026, 5, 22, 10),
    );
    final repository = _QueueAwareHarness(Future.value(service));

    await expectLater(
      repository.submitWithNetworkError(_siteRequestDraft()),
      throwsA(
        predicate<SyncQueuedException>(
          (error) =>
              error.requiresReview &&
              error.message == SyncQueueMessages.unknownOutcome,
        ),
      ),
    );

    final operations = await store.all();
    expect(operations, hasLength(1));
    expect(operations.single.moduleSlug, 'site_requests');
    expect(operations.single.operationType, 'create_site_request');
    expect(operations.single.status, SyncOperationStatuses.conflict);
    expect(
      operations.single.lastBusinessError,
      SyncQueueMessages.unknownOutcome,
    );
    expect(operations.single.attemptCount, 1);
    expect(operations.single.nextAttemptAt, isNull);
  });

  test('keeps a verified connect timeout queued for its first send', () async {
    final store = _MemorySyncQueueStore();
    final service = SyncQueueService(
      store: store,
      dio: Dio(),
      now: () => DateTime(2026, 9, 20, 10),
    );
    final repository = _QueueAwareHarness(Future.value(service));

    await expectLater(
      repository.submitWithNetworkError(
        _siteRequestDraft(),
        type: DioExceptionType.connectionTimeout,
      ),
      throwsA(
        predicate<SyncQueuedException>(
          (error) =>
              !error.requiresReview &&
              error.message == SyncQueueMessages.queuedForNetwork,
        ),
      ),
    );

    final operation = (await store.all()).single;
    expect(operation.status, SyncOperationStatuses.queued);
    expect(operation.attemptCount, 1);
    expect(operation.lastBusinessError, SyncQueueMessages.queuedForNetwork);
    expect(operation.nextAttemptAt, DateTime(2026, 9, 20, 10, 1));
  });

  test(
    'queueAndThrow reports review after an ambiguous initial failure',
    () async {
      final store = _MemorySyncQueueStore();
      final service = SyncQueueService(store: store, dio: Dio());
      final repository = _QueueAwareHarness(Future.value(service));

      await expectLater(
        repository.queueAfterFailure(
          _siteRequestDraft(),
          DioException(
            requestOptions: RequestOptions(path: '/site-requests'),
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        throwsA(
          predicate<SyncQueuedException>(
            (error) =>
                error.requiresReview &&
                error.message == SyncQueueMessages.unknownOutcome,
          ),
        ),
      );
      expect((await store.all()).single.status, SyncOperationStatuses.conflict);
    },
  );

  test(
    'recordInitialFailure distinguishes journal create from submit',
    () async {
      final store = _MemorySyncQueueStore();
      final service = SyncQueueService(store: store, dio: Dio());
      final error = DioException(
        requestOptions: RequestOptions(path: '/journal-entries/42/submit'),
        type: DioExceptionType.receiveTimeout,
      );
      final create = await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'create_entry',
          method: 'POST',
          endpoint: '/construction-journals/7/entries',
          payload: {'idempotency_key': 'journal-create-key'},
        ),
      );
      final submit = await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'submit_entry',
          method: 'POST',
          endpoint: '/journal-entries/42/submit',
          payload: {'idempotency_key': 'journal-submit-key'},
        ),
      );

      final sendingCreate = await service.markOperationSending(create.id);
      final sendingSubmit = await service.markOperationSending(submit.id);
      expect(sendingCreate?.status, SyncOperationStatuses.sending);
      expect(sendingSubmit?.status, SyncOperationStatuses.sending);

      final createAfterFailure = await service.recordInitialFailure(
        create.id,
        error,
      );
      final submitAfterFailure = await service.recordInitialFailure(
        submit.id,
        error,
      );

      expect(createAfterFailure?.status, SyncOperationStatuses.queued);
      expect(createAfterFailure?.attemptCount, 1);
      expect(submitAfterFailure?.status, SyncOperationStatuses.conflict);
      expect(submitAfterFailure?.attemptCount, 1);
      expect(
        submitAfterFailure?.lastBusinessError,
        SyncQueueMessages.unknownOutcome,
      );
    },
  );

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

  test(
    'keeps an unkeyed action for review after receive timeout and restart',
    () async {
      final store = _MemorySyncQueueStore();
      final firstAdapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(
                statusCode: 0,
                body: '',
                errorType: DioExceptionType.receiveTimeout,
              ),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(firstAdapter),
        now: () => DateTime(2026, 9, 20, 10),
        verifyOnline: () async => true,
      );
      final operation = await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'quality_control',
          operationType: 'create_defect',
          method: 'POST',
          endpoint: '/quality-control/defects',
          payload: {'project_id': 7, 'description': 'Трещина'},
        ),
      );

      final firstResult = await service.retryDueOperations();
      final saved = await store.get(operation.id);

      expect(firstResult.blockedCount, 1);
      expect(firstResult.retryCount, 0);
      expect(firstAdapter.requests, hasLength(1));
      expect(saved?.status, SyncOperationStatuses.conflict);
      expect(saved?.nextAttemptAt, isNull);
      expect(saved?.lastBusinessError, SyncQueueMessages.unknownOutcome);

      final retryAdapter = _QueueHttpAdapter();
      final restartedService = SyncQueueService(
        store: store,
        dio: _dio(retryAdapter),
        now: () => DateTime(2026, 9, 20, 10, 5),
        verifyOnline: () async => true,
      );
      final retryResult = await restartedService.retryDueOperations();

      expect(retryResult.blockedCount, 1);
      expect(retryAdapter.requests, isEmpty);
      expect(
        (await store.get(operation.id))?.status,
        SyncOperationStatuses.conflict,
      );
    },
  );

  test('keeps an unkeyed action for review after a server 5xx', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            const _AdapterResponse(statusCode: 503, body: '{"message":"busy"}'),
          );
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      verifyOnline: () async => true,
    );
    final operation = await service.enqueue(
      const SyncQueueDraft(
        moduleSlug: 'quality_control',
        operationType: 'create_defect',
        method: 'POST',
        endpoint: '/quality-control/defects',
        payload: {'project_id': 7},
      ),
    );

    final result = await service.retryDueOperations();

    expect(result.blockedCount, 1);
    expect(result.retryCount, 0);
    expect(
      (await store.get(operation.id))?.status,
      SyncOperationStatuses.conflict,
    );
    expect(
      (await store.get(operation.id))?.lastBusinessError,
      SyncQueueMessages.unknownOutcome,
    );
  });

  test(
    'keeps a keyed action retryable and reports server failure after 5xx',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(
                statusCode: 503,
                body: '{"message":"busy"}',
              ),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        now: () => DateTime(2026, 9, 28, 10),
        verifyOnline: () async => true,
      );
      final operation = await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'construction_journal',
          operationType: 'create_entry',
          method: 'POST',
          endpoint: '/construction-journals/7/entries',
          payload: {'idempotency_key': 'journal-create-key', 'journal_id': 7},
        ),
      );

      final result = await service.retryDueOperations();
      final saved = await store.get(operation.id);

      expect(result.retryCount, 1);
      expect(result.blockedCount, 0);
      expect(saved?.status, SyncOperationStatuses.queued);
      expect(saved?.lastBusinessError, SyncQueueMessages.serverFailure);
      expect(saved?.nextAttemptAt, DateTime(2026, 9, 28, 10, 1));
    },
  );

  test(
    'a client key alone does not authorize retry for an unknown contract',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(
                statusCode: 0,
                body: '',
                errorType: DioExceptionType.receiveTimeout,
              ),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        verifyOnline: () async => true,
      );
      await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'quality_control',
          operationType: 'resolve_defect',
          method: 'POST',
          endpoint: '/quality-control/defects/7/resolve',
          payload: {'idempotency_key': 'unconfirmed-key'},
        ),
      );

      await service.retryDueOperations();

      expect((await store.all()).single.status, SyncOperationStatuses.conflict);
      expect(
        (await store.all()).single.lastBusinessError,
        SyncQueueMessages.unknownOutcome,
      );
    },
  );

  test(
    'retries a verified idempotent action with the same key after timeout',
    () async {
      final store = _MemorySyncQueueStore();
      final firstAdapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(
                statusCode: 0,
                body: '',
                errorType: DioExceptionType.receiveTimeout,
              ),
            );
      var now = DateTime(2026, 9, 20, 10);
      final firstService = SyncQueueService(
        store: store,
        dio: _dio(firstAdapter),
        now: () => now,
        verifyOnline: () async => true,
      );
      await firstService.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'site_requests',
          operationType: 'create_site_request',
          method: 'POST',
          endpoint: '/site-requests',
          payload: {'idempotency_key': 'site-request-42'},
        ),
      );

      final firstResult = await firstService.retryDueOperations();
      expect(firstResult.retryCount, 1);
      expect((await store.all()).single.status, SyncOperationStatuses.queued);

      now = now.add(const Duration(minutes: 2));
      final retryAdapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      final restartedService = SyncQueueService(
        store: store,
        dio: _dio(retryAdapter),
        now: () => now,
        verifyOnline: () async => true,
      );
      final retryResult = await restartedService.retryDueOperations();

      expect(retryResult.successCount, 1);
      expect(
        firstAdapter.requests.single.headers['Idempotency-Key'],
        'site-request-42',
      );
      expect(
        retryAdapter.requests.single.headers['Idempotency-Key'],
        'site-request-42',
      );
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'connect timeout stays queued so an unkeyed action can make its first send',
    () async {
      final store = _MemorySyncQueueStore();
      final firstAdapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(
                statusCode: 0,
                body: '',
                errorType: DioExceptionType.connectionTimeout,
              ),
            );
      var now = DateTime(2026, 9, 20, 10);
      final service = SyncQueueService(
        store: store,
        dio: _dio(firstAdapter),
        now: () => now,
        verifyOnline: () async => true,
      );
      final operation = await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'quality_control',
          operationType: 'create_defect',
          method: 'POST',
          endpoint: '/quality-control/defects',
          payload: {'project_id': 7},
        ),
      );

      final firstResult = await service.retryDueOperations();
      expect(firstResult.retryCount, 1);
      expect(
        (await store.get(operation.id))?.status,
        SyncOperationStatuses.queued,
      );

      now = now.add(const Duration(minutes: 2));
      final retryAdapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      final restartedService = SyncQueueService(
        store: store,
        dio: _dio(retryAdapter),
        now: () => now,
        verifyOnline: () async => true,
      );
      expect((await restartedService.retryDueOperations()).successCount, 1);
      expect(retryAdapter.requests, hasLength(1));
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'stops after an earlier operation retries to preserve dependency order',
    () async {
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
        now: () => DateTime(2026, 8, 23, 10),
      );
      await service.enqueue(
        _siteRequestDraft(idempotencyKey: 'site-request-before-dependent'),
      );
      await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'warehouse',
          operationType: 'receive_project_delivery',
          method: 'POST',
          endpoint: '/warehouse/project-material-deliveries/10/receive',
          payload: <String, dynamic>{
            'quantity': 1,
            'idempotency_key': 'dependent-operation',
          },
        ),
      );

      final result = await service.retryDueOperations();

      expect(result.retryCount, 1);
      expect(result.successCount, 0);
      expect(adapter.requests, hasLength(1));
      expect(await store.all(), hasLength(2));
    },
  );

  test('reuses queued machinery idempotency key as request header', () async {
    final store = _MemorySyncQueueStore();
    final adapter =
        _QueueHttpAdapter()
          ..responses.add(
            _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
          );
    final service = SyncQueueService(
      store: store,
      dio: _dio(adapter),
      now: () => DateTime(2026, 8, 11, 10),
    );
    await service.enqueue(
      const SyncQueueDraft(
        moduleSlug: 'machinery_operations',
        operationType: 'finish_shift',
        method: 'POST',
        endpoint: '/machinery-operations/shift-reports/42/finish',
        payload: <String, dynamic>{
          'meter_end': 108,
          'idempotency_key': 'offline-shift-42',
        },
      ),
    );

    await service.retryDueOperations();

    expect(
      adapter.requests.single.headers['Idempotency-Key'],
      'offline-shift-42',
    );
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

  test(
    'marks conflict for editing and preserves dependent operation order',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              _AdapterResponse(
                statusCode: 409,
                body: '{"message":"Операция конфликтует с текущими данными"}',
              ),
            )
            ..responses.add(
              _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        now: () => DateTime(2026, 8, 23, 10),
      );
      final conflicted = await service.enqueue(_siteRequestDraft());
      await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'warehouse',
          operationType: 'receive_project_delivery',
          method: 'POST',
          endpoint: '/warehouse/project-material-deliveries/10/receive',
          payload: <String, dynamic>{
            'quantity': 1,
            'idempotency_key': 'dependent-operation',
          },
        ),
      );

      final result = await service.retryDueOperations();

      expect(result.blockedCount, 1);
      expect(result.successCount, 0);
      expect(adapter.requests, hasLength(1));
      final blocked = await store.get(conflicted.id);
      expect(blocked?.status, SyncOperationStatuses.conflict);
      expect(
        blocked?.lastBusinessError,
        'Операция конфликтует с текущими данными',
      );
      expect(await store.all(), hasLength(2));
    },
  );

  test(
    'blocked predecessor fences later operations across retry runs',
    () async {
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              _AdapterResponse(
                statusCode: 409,
                body: '{"message":"Смена уже открыта на другом устройстве"}',
              ),
            )
            ..responses.add(
              _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        now: () => DateTime(2026, 8, 23, 10),
      );
      final start = await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'machinery_operations',
          operationType: 'start_shift',
          method: 'POST',
          endpoint: '/machinery-operations/shift-reports',
          payload: <String, dynamic>{'idempotency_key': 'offline-start'},
        ),
      );
      await service.enqueue(
        const SyncQueueDraft(
          moduleSlug: 'machinery_operations',
          operationType: 'finish_shift',
          method: 'POST',
          endpoint: '/machinery-operations/shift-reports/42/finish',
          payload: <String, dynamic>{'idempotency_key': 'offline-finish'},
        ),
      );

      await service.retryDueOperations();
      final secondRun = await service.retryDueOperations();

      expect(secondRun.blockedCount, 1);
      expect(secondRun.successCount, 0);
      expect(adapter.requests, hasLength(1));
      expect(
        (await store.get(start.id))?.status,
        SyncOperationStatuses.conflict,
      );
      expect(await store.all(), hasLength(2));
    },
  );

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
          'idempotency_key': 'receipt-attachment-retry',
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

  test(
    'replays encrypted attachment after picker file is removed and service restarts',
    () async {
      final supportDirectory = await Directory.systemTemp.createTemp(
        'sync-queue-support-',
      );
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'sync-queue-temporary-',
      );
      addTearDown(() async {
        if (await supportDirectory.exists()) {
          await supportDirectory.delete(recursive: true);
        }
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      });
      final fileCache = EncryptedLocalFileCache(
        keyStore: _MemoryFileKeyStore(),
        directoryProvider: () async => supportDirectory,
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );
      final pickerFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}picked.jpg',
      );
      final imageBytes = <int>[1, 2, 3, 4, 5, 6];
      await pickerFile.writeAsBytes(imageBytes);
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(
              const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      const scope = '27:4:session-a';
      List<int>? materializedBytes;

      SyncQueueService createService() => SyncQueueService(
        store: store,
        dio: _dio(adapter),
        currentScope: () => scope,
        onlineVerified: () => true,
        verifyOnline: () async => true,
        stageQueuedAttachment:
            (attachment, ownerIdentity, context) =>
                fileCache.stageQueuedAttachment(
                  ownerIdentity: ownerIdentity,
                  context: context,
                  sourcePath: attachment.path,
                ),
        materializeAttachment: (attachment, ownerIdentity) async {
          final path = await fileCache.materialize(
            ownerIdentity: ownerIdentity,
            encryptedPath: attachment.path,
            context: attachment.context!,
            fileName: attachment.filename,
          );
          materializedBytes = await File(path).readAsBytes();
          return path;
        },
        deleteMaterializedAttachment: fileCache.deleteStagedUpload,
        deleteQueuedAttachment:
            (attachment) => fileCache.deleteStagedUpload(attachment.path),
      );

      final queued = await createService().enqueue(
        SyncQueueDraft(
          moduleSlug: 'warehouse',
          operationType: 'create_receipt',
          method: 'POST',
          endpoint: '/warehouse/operations/receipt',
          payload: const {'idempotency_key': 'receipt-17'},
          attachments: [
            SyncAttachmentRef(
              field: 'photos[]',
              path: pickerFile.path,
              filename: 'picked.jpg',
            ),
          ],
        ),
      );
      final stagedPath = queued.attachments.single.path;
      expect(queued.attachments.single.encrypted, isTrue);
      expect(await File(stagedPath).readAsBytes(), isNot(equals(imageBytes)));

      await pickerFile.delete();
      final result = await createService().retryDueOperations();

      expect(result.successCount, 1);
      expect(materializedBytes, imageBytes);
      expect(adapter.requests.single.headers['Idempotency-Key'], 'receipt-17');
      expect(
        (adapter.requests.single.data as FormData).fields.map(
          (field) => field.key,
        ),
        isNot(contains('queue_scope')),
      );
      expect(await File(stagedPath).exists(), isFalse);
      expect(await store.all(), isEmpty);
    },
  );

  test(
    'marks missing queued attachment for repair instead of hanging',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'sync-queue-missing-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final store = _MemorySyncQueueStore();
      final adapter = _QueueHttpAdapter();
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        now: () => DateTime(2026, 8, 23, 10),
      );
      final queued = await service.enqueue(
        SyncQueueDraft(
          moduleSlug: 'warehouse',
          operationType: 'create_receipt',
          method: 'POST',
          endpoint: '/warehouse/operations/receipt',
          payload: const <String, dynamic>{'idempotency_key': 'receipt-42'},
          attachments: <SyncAttachmentRef>[
            SyncAttachmentRef(
              field: 'photos[]',
              path: '${tempDir.path}${Platform.pathSeparator}missing.jpg',
              filename: 'missing.jpg',
            ),
          ],
        ),
      );

      final result = await service.retryDueOperations();
      final recovered = await store.get(queued.id);

      expect(result.blockedCount, 1);
      expect(recovered?.status, SyncOperationStatuses.needsEdit);
      expect(recovered?.lastBusinessError, isNotEmpty);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'encrypted legal upload keeps owner and idempotency across retry',
    () async {
      final directory = await Directory.systemTemp.createTemp('legal-queue-');
      final materialized = File('${directory.path}/materialized.pdf');
      await materialized.writeAsBytes(<int>[1, 2, 3]);
      final store = _MemorySyncQueueStore();
      final adapter =
          _QueueHttpAdapter()
            ..responses.add(_AdapterResponse.networkError())
            ..responses.add(
              const _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
            );
      var now = DateTime(2026, 8, 23, 10);
      final owners = <String>[];
      final service = SyncQueueService(
        store: store,
        dio: _dio(adapter),
        now: () => now,
        currentScope: () => '27:4:session-a',
        onlineVerified: () => true,
        verifyOnline: () async => true,
        materializeAttachment: (attachment, ownerIdentity) async {
          owners.add(ownerIdentity);
          return materialized.path;
        },
      );
      final queued = await service.enqueue(
        SyncQueueDraft(
          moduleSlug: 'legal_archive',
          operationType: 'upload_paper_original',
          method: 'POST',
          endpoint: '/legal-archive/signature-requests/31/upload-original',
          payload: const {
            'idempotency_key': 'immutable-key',
            'queue_scope': '27:4:session-a',
            'queue_owner_identity': '27:4:session-a',
            'signed_at': '2026-08-23T07:00:00.000Z',
            'lock_version': 5,
          },
          attachments: [
            SyncAttachmentRef(
              field: 'file',
              path: '/protected/upload.enc',
              filename: 'signed.pdf',
              encrypted: true,
              context: 'upload:31:immutable-key',
            ),
          ],
        ),
      );

      final first = await service.retryDueOperations();
      expect(first.retryCount, 1);
      final retained = await store.get(queued.id);
      expect(retained?.payload['queue_owner_identity'], '27:4:session-a');
      expect(
        adapter.requests.single.headers['Idempotency-Key'],
        'immutable-key',
      );

      now = now.add(const Duration(minutes: 2));
      final second = await service.retryDueOperations();
      expect(second.successCount, 1);
      expect(owners, ['27:4:session-a', '27:4:session-a']);
      expect(adapter.requests[1].headers['Idempotency-Key'], 'immutable-key');
      expect(await store.get(queued.id), isNull);
      await directory.delete(recursive: true);
    },
  );
}

SyncQueueDraft _siteRequestDraft({String? idempotencyKey}) {
  return SyncQueueDraft(
    moduleSlug: 'site_requests',
    operationType: 'create_site_request',
    method: 'POST',
    endpoint: '/site-requests',
    payload: {
      'project_id': 15,
      'title': 'Материалы',
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    },
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

  Future<void> submitWithNetworkError(
    SyncQueueDraft draft, {
    DioExceptionType type = DioExceptionType.connectionError,
  }) {
    return executeOrQueue(
      request: () async {
        throw DioException(
          requestOptions: RequestOptions(path: draft.endpoint),
          type: type,
        );
      },
      draft: draft,
      businessMessage: 'Не удалось отправить.',
    );
  }

  Future<Never> queueAfterFailure(SyncQueueDraft draft, DioException error) {
    return queueAndThrow(draft, cause: error);
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

class _MemoryFileKeyStore implements SecureFileKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _QueueHttpAdapter implements HttpClientAdapter {
  final responses = Queue<_AdapterResponse>();
  final requests = <RequestOptions>[];
  Completer<void>? requestStarted;
  Completer<void>? responseGate;

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
    final started = requestStarted;
    if (started != null && !started.isCompleted) started.complete();
    await responseGate?.future;
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
