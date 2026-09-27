import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'queued_sync_operation.dart';
import 'sync_queue_draft.dart';
import 'sync_queue_store.dart';

class SyncQueueMessages {
  static const queuedForNetwork = 'Будет отправлено при восстановлении связи';
  static const permissionDenied =
      'Недостаточно прав для отправки сохраненной операции.';
  static const unknownOutcome =
      'Неизвестно, выполнено ли действие на сервере. Проверьте его перед повторной отправкой.';
  static const attachmentUnavailable =
      'Не удалось открыть вложение. Прикрепите файл повторно.';
}

class SyncQueuedException extends ApiException {
  const SyncQueuedException({this.queueId, this.requiresReview = false})
    : super(
        requiresReview
            ? SyncQueueMessages.unknownOutcome
            : SyncQueueMessages.queuedForNetwork,
      );

  final int? queueId;
  final bool requiresReview;
}

class SyncQueueProcessResult {
  const SyncQueueProcessResult({
    required this.successCount,
    required this.retryCount,
    required this.blockedCount,
  });

  final int successCount;
  final int retryCount;
  final int blockedCount;
}

class SyncQueueService {
  SyncQueueService({
    required SyncQueueStore store,
    required Dio dio,
    DateTime Function()? now,
    String? Function()? currentScope,
    bool Function()? onlineVerified,
    Future<String> Function(
      SyncAttachmentRef attachment,
      String ownerIdentity,
      String context,
    )?
    stageQueuedAttachment,
    Future<String> Function(SyncAttachmentRef attachment, String ownerIdentity)?
    materializeAttachment,
    Future<void> Function(String path)? deleteMaterializedAttachment,
    Future<void> Function(SyncAttachmentRef attachment)? deleteQueuedAttachment,
    Future<bool> Function()? verifyOnline,
  }) : _store = store,
       _dio = dio,
       _now = now ?? DateTime.now,
       _currentScope = currentScope,
       _onlineVerified = onlineVerified,
       _stageQueuedAttachment = stageQueuedAttachment,
       _materializeAttachment = materializeAttachment,
       _deleteMaterializedAttachment = deleteMaterializedAttachment,
       _deleteQueuedAttachment = deleteQueuedAttachment,
       _verifyOnline = verifyOnline;

  final SyncQueueStore _store;
  final Dio _dio;
  final DateTime Function() _now;
  final String? Function()? _currentScope;
  final bool Function()? _onlineVerified;
  final Future<String> Function(
    SyncAttachmentRef attachment,
    String ownerIdentity,
    String context,
  )?
  _stageQueuedAttachment;
  final Future<String> Function(
    SyncAttachmentRef attachment,
    String ownerIdentity,
  )?
  _materializeAttachment;
  final Future<void> Function(String path)? _deleteMaterializedAttachment;
  final Future<void> Function(SyncAttachmentRef attachment)?
  _deleteQueuedAttachment;
  final Future<bool> Function()? _verifyOnline;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  var _changeVersion = 0;
  Future<SyncQueueProcessResult>? _processing;

  String? get currentScope => _currentScope?.call();
  bool get requiresScope => _currentScope != null;
  Stream<int> get changes => _changes.stream;

  Future<QueuedSyncOperation> _save(QueuedSyncOperation operation) async {
    final stored = await _store.put(operation);
    _changes.add(++_changeVersion);
    return stored;
  }

  Future<void> _remove(int id) async {
    await _store.delete(id);
    _changes.add(++_changeVersion);
  }

  static bool shouldQueueDioException(DioException error) {
    if (_isNetworkError(error)) {
      return true;
    }

    final statusCode = error.response?.statusCode;
    return statusCode != null && statusCode >= 500;
  }

  Future<QueuedSyncOperation> enqueue(
    SyncQueueDraft draft, {
    DioException? initialFailure,
  }) async {
    final scope = currentScope;
    if (requiresScope && (scope == null || scope.isEmpty)) {
      throw const ApiException(SyncQueueMessages.permissionDenied);
    }
    final draftScope = draft.payload['queue_scope']?.toString();
    if (requiresScope &&
        draftScope != null &&
        draftScope.isNotEmpty &&
        draftScope != scope) {
      throw const ApiException(SyncQueueMessages.permissionDenied);
    }
    final scopedDraft =
        scope == null
            ? draft
            : SyncQueueDraft(
              moduleSlug: draft.moduleSlug,
              operationType: draft.operationType,
              method: draft.method,
              endpoint: draft.endpoint,
              payload: {...draft.payload, 'queue_scope': scope},
              attachments: draft.attachments,
            );
    final (preparedDraft, stagedAttachments) = await _stageDraftAttachments(
      scopedDraft,
      ownerIdentity: scope,
    );
    try {
      if (requiresScope && scope != currentScope) {
        throw const ApiException(SyncQueueMessages.permissionDenied);
      }
      final operation = QueuedSyncOperation.fromDraft(
        preparedDraft,
        createdAt: _now(),
      );
      if (initialFailure != null) {
        _recordInitialFailure(operation, initialFailure);
      }
      final stored = await _save(operation);
      if (requiresScope && scope != currentScope) {
        await _remove(stored.id);
        throw const ApiException(SyncQueueMessages.permissionDenied);
      }
      return stored;
    } catch (_) {
      await _deleteQueuedAttachments(stagedAttachments);
      rethrow;
    }
  }

  Future<QueuedSyncOperation?> recordInitialFailure(
    int operationId,
    DioException error,
  ) async {
    final operation = await _store.get(operationId);
    if (operation == null) return null;

    final scope = currentScope;
    final operationScope = operation.payload['queue_scope']?.toString();
    if (requiresScope &&
        (scope == null || scope.isEmpty || operationScope != scope)) {
      throw const ApiException(SyncQueueMessages.permissionDenied);
    }

    _recordInitialFailure(operation, error, incrementAttempt: true);
    return _save(operation);
  }

  Future<QueuedSyncOperation?> markOperationSending(int operationId) async {
    final operation = await _store.get(operationId);
    if (operation == null || operation.status != SyncOperationStatuses.queued) {
      return null;
    }

    final scope = currentScope;
    final operationScope = operation.payload['queue_scope']?.toString();
    if (requiresScope &&
        (scope == null || scope.isEmpty || operationScope != scope)) {
      throw const ApiException(SyncQueueMessages.permissionDenied);
    }
    if (requiresScope && scope != currentScope) {
      throw const ApiException(SyncQueueMessages.permissionDenied);
    }

    operation
      ..status = SyncOperationStatuses.sending
      ..attemptCount = operation.attemptCount + 1
      ..lastAttemptAt = _now()
      ..nextAttemptAt = null
      ..lastBusinessError = null;
    return _save(operation);
  }

  Future<List<QueuedSyncOperation>> all() {
    return _store.all();
  }

  Future<QueuedSyncOperation?> get(int id) {
    return _store.get(id);
  }

  Future<void> delete(int id) {
    return _deleteOperation(id);
  }

  Future<void> _deleteOperation(int id) async {
    final operation = await _store.get(id);
    await _remove(id);
    if (operation != null) {
      await _deleteQueuedAttachments(operation.attachments);
    }
  }

  Future<void> clearScope(String ownerIdentity) async {
    final processing = _processing;
    if (processing != null) {
      try {
        await processing;
      } catch (_) {}
    }
    for (final operation in await _store.all()) {
      if (operation.payload['queue_scope']?.toString() == ownerIdentity) {
        await _deleteOperation(operation.id);
      }
    }
  }

  Future<(SyncQueueDraft, List<SyncAttachmentRef>)> _stageDraftAttachments(
    SyncQueueDraft draft, {
    required String? ownerIdentity,
  }) async {
    final stageAttachment = _stageQueuedAttachment;
    if (stageAttachment == null ||
        ownerIdentity == null ||
        ownerIdentity.isEmpty ||
        draft.attachments.isEmpty) {
      return (draft, const <SyncAttachmentRef>[]);
    }

    final attachments = <SyncAttachmentRef>[];
    final staged = <SyncAttachmentRef>[];
    try {
      for (var index = 0; index < draft.attachments.length; index++) {
        final attachment = draft.attachments[index];
        if (attachment.encrypted) {
          attachments.add(attachment);
          continue;
        }
        final context = _newAttachmentContext(draft, index);
        final encrypted = SyncAttachmentRef(
          field: attachment.field,
          path: await stageAttachment(attachment, ownerIdentity, context),
          filename: attachment.filename,
          encrypted: true,
          context: context,
        );
        attachments.add(encrypted);
        staged.add(encrypted);
      }
    } catch (_) {
      await _deleteQueuedAttachments(staged);
      rethrow;
    }

    return (
      SyncQueueDraft(
        moduleSlug: draft.moduleSlug,
        operationType: draft.operationType,
        method: draft.method,
        endpoint: draft.endpoint,
        payload: draft.payload,
        attachments: attachments,
      ),
      staged,
    );
  }

  String _newAttachmentContext(SyncQueueDraft draft, int index) {
    final idempotencyKey = draft.payload['idempotency_key']?.toString();
    final uniqueOperation =
        idempotencyKey != null && idempotencyKey.isNotEmpty
            ? idempotencyKey
            : '${_now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
    return 'sync-queue:${draft.moduleSlug}:${draft.operationType}:$uniqueOperation:$index';
  }

  Future<void> _deleteQueuedAttachments(
    Iterable<SyncAttachmentRef> attachments,
  ) async {
    final deleteAttachment = _deleteQueuedAttachment;
    if (deleteAttachment == null) return;
    for (final attachment in attachments) {
      if (!attachment.encrypted) continue;
      try {
        await deleteAttachment(attachment);
      } catch (_) {}
    }
  }

  Future<List<QueuedSyncOperation>> forCurrentOwner() async {
    final scope = currentScope;
    if (scope == null || scope.isEmpty) return const [];
    final operations = await _store.all();
    return operations
        .where((operation) => operation.payload['queue_scope'] == scope)
        .toList();
  }

  Future<void> update(QueuedSyncOperation operation) {
    return _save(operation);
  }

  Future<void> replaceDraftPayload(
    int id, {
    required Map<String, dynamic> payload,
    required List<SyncAttachmentRef> attachments,
  }) async {
    final operation = await _store.get(id);
    if (operation == null) {
      throw const FormatException('Queued operation was not found.');
    }
    final operationScope = operation.payload['queue_scope']?.toString();
    final replacementScope = payload['queue_scope']?.toString();
    final scope = currentScope;
    if (requiresScope &&
        (scope == null ||
            scope.isEmpty ||
            operationScope != scope ||
            (replacementScope != null && replacementScope != operationScope))) {
      throw const ApiException(SyncQueueMessages.permissionDenied);
    }

    final draft = SyncQueueDraft(
      moduleSlug: operation.moduleSlug,
      operationType: operation.operationType,
      method: operation.method,
      endpoint: operation.endpoint,
      payload:
          operationScope == null
              ? payload
              : {...payload, 'queue_scope': operationScope},
      attachments: attachments,
    );
    final previousAttachments = operation.attachments;
    final (preparedDraft, stagedAttachments) = await _stageDraftAttachments(
      draft,
      ownerIdentity: operationScope,
    );
    try {
      if (requiresScope && scope != currentScope) {
        throw const ApiException(SyncQueueMessages.permissionDenied);
      }
      operation
        ..payloadJson = preparedDraft.encodePayload()
        ..attachmentsJson = preparedDraft.encodeAttachments()
        ..localAttachments = preparedDraft.localAttachments
        ..status = SyncOperationStatuses.queued
        ..attemptCount = 0
        ..lastAttemptAt = null
        ..nextAttemptAt = null
        ..lastBusinessError = null;

      await _save(operation);
      if (requiresScope && scope != currentScope) {
        await _remove(operation.id);
        throw const ApiException(SyncQueueMessages.permissionDenied);
      }
    } catch (_) {
      await _deleteQueuedAttachments(stagedAttachments);
      rethrow;
    }

    final retainedPaths =
        preparedDraft.attachments.map((item) => item.path).toSet();
    await _deleteQueuedAttachments(
      previousAttachments.where((item) => !retainedPaths.contains(item.path)),
    );
  }

  Future<SyncQueueProcessResult> retryDueOperations() {
    return _processing ??= _verifyAndProcess().whenComplete(() {
      _processing = null;
    });
  }

  Future<SyncQueueProcessResult> _verifyAndProcess() async {
    final initialScope = currentScope;
    if ((_verifyOnline == null && _onlineVerified?.call() == false) ||
        (requiresScope && initialScope == null && _verifyOnline != null)) {
      return const SyncQueueProcessResult(
        successCount: 0,
        retryCount: 0,
        blockedCount: 0,
      );
    }
    final verifyOnline = _verifyOnline;
    if (verifyOnline != null && !await verifyOnline()) {
      return const SyncQueueProcessResult(
        successCount: 0,
        retryCount: 0,
        blockedCount: 0,
      );
    }
    if (initialScope != currentScope || _onlineVerified?.call() == false) {
      return const SyncQueueProcessResult(
        successCount: 0,
        retryCount: 0,
        blockedCount: 0,
      );
    }
    return _processDueOperations();
  }

  Future<SyncQueueProcessResult> _processDueOperations() async {
    final now = _now();
    final verifiedScope = currentScope;
    final operations = await _store.all();
    var successCount = 0;
    var retryCount = 0;
    var blockedCount = 0;

    for (final operation in operations) {
      final operationScope = operation.payload['queue_scope']?.toString();
      if (requiresScope &&
          (operationScope == null ||
              operationScope.isEmpty ||
              operationScope != verifiedScope)) {
        if (operationScope == null || operationScope.isEmpty) {
          operation
            ..status = SyncOperationStatuses.permissionDenied
            ..lastBusinessError = SyncQueueMessages.permissionDenied;
          await _save(operation);
        }
        blockedCount++;
        continue;
      }
      final hasConfirmedIdempotency = _hasConfirmedIdempotencyContract(
        operation,
      );
      if (operation.status != SyncOperationStatuses.queued &&
          !(operation.status == SyncOperationStatuses.sending &&
              hasConfirmedIdempotency)) {
        if (operation.status == SyncOperationStatuses.sending) {
          operation
            ..status = SyncOperationStatuses.conflict
            ..lastBusinessError = SyncQueueMessages.unknownOutcome;
          await _save(operation);
        }
        blockedCount++;
        break;
      }
      if (operation.nextAttemptAt?.isAfter(now) ?? false) {
        retryCount++;
        break;
      }
      final outcome = await _retryOperation(
        operation,
        verifiedScope: verifiedScope,
      );

      switch (outcome) {
        case _RetryOutcome.success:
          successCount++;
        case _RetryOutcome.retry:
          retryCount++;
        case _RetryOutcome.blocked:
          blockedCount++;
      }

      if (outcome != _RetryOutcome.success) {
        break;
      }
    }

    return SyncQueueProcessResult(
      successCount: successCount,
      retryCount: retryCount,
      blockedCount: blockedCount,
    );
  }

  Future<_RetryOutcome> _retryOperation(
    QueuedSyncOperation operation, {
    required String? verifiedScope,
  }) async {
    final operationScope = operation.payload['queue_scope']?.toString();
    if (requiresScope && verifiedScope != currentScope) {
      operation
        ..status = SyncOperationStatuses.permissionDenied
        ..lastBusinessError = SyncQueueMessages.permissionDenied;
      await _save(operation);
      return _RetryOutcome.blocked;
    }
    if ((requiresScope &&
            (operationScope == null ||
                operationScope.isEmpty ||
                operationScope != currentScope)) ||
        (operationScope != null &&
            operationScope.isNotEmpty &&
            operationScope != currentScope)) {
      operation
        ..status = SyncOperationStatuses.permissionDenied
        ..lastBusinessError = SyncQueueMessages.permissionDenied;
      await _save(operation);
      return _RetryOutcome.blocked;
    }
    operation
      ..status = SyncOperationStatuses.sending
      ..attemptCount = operation.attemptCount + 1
      ..lastAttemptAt = _now()
      ..lastBusinessError = null;
    await _save(operation);

    final temporaryAttachments = <String>[];
    try {
      var journalCreate =
          operation.moduleSlug == 'construction_journal' &&
          RegExp(
            r'^/construction-journals/\d+/entries$',
          ).hasMatch(operation.endpoint);
      final knownId = int.tryParse(
        operation.payload['created_entry_id']?.toString() ?? '',
      );
      if (journalCreate &&
          knownId != null &&
          operation.payload['submit_intent'] == true) {
        await _advanceJournalToSubmit(operation, knownId);
        journalCreate = false;
      }
      final idempotencyKey = operation.payload['idempotency_key']?.toString();
      final requestData = await _requestData(operation, temporaryAttachments);
      if (requiresScope && verifiedScope != currentScope) {
        operation
          ..status = SyncOperationStatuses.queued
          ..lastBusinessError = SyncQueueMessages.permissionDenied;
        await _save(operation);
        return _RetryOutcome.blocked;
      }
      final response = await _dio.request<dynamic>(
        operation.endpoint,
        data: requestData,
        options: Options(
          method: operation.method,
          headers: {
            if (idempotencyKey != null && idempotencyKey.isNotEmpty)
              'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      if (requiresScope && verifiedScope != currentScope) {
        operation
          ..status = SyncOperationStatuses.queued
          ..lastBusinessError = SyncQueueMessages.permissionDenied;
        await _save(operation);
        return _RetryOutcome.blocked;
      }
      if (journalCreate && operation.payload['submit_intent'] == true) {
        final raw = response.data;
        final data = raw is Map && raw['data'] is Map ? raw['data'] : raw;
        final id =
            data is Map ? int.tryParse(data['id']?.toString() ?? '') : null;
        final status = data is Map ? data['status']?.toString() : null;
        if (id == null ||
            id <= 0 ||
            !['draft', 'submitted', 'approved', 'rejected'].contains(status)) {
          throw const FormatException(
            'Не удалось подтвердить состояние созданной записи.',
          );
        }
        if (status == 'draft') {
          await _advanceJournalToSubmit(operation, id);
          return _retryOperation(operation, verifiedScope: verifiedScope);
        }
      }
      await _remove(operation.id);
      await _deleteQueuedAttachments(operation.attachments);
      return _RetryOutcome.success;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if ((statusCode == 403 || statusCode == 422) &&
          operation.moduleSlug == 'construction_journal' &&
          RegExp(
            r'^/journal-entries/\d+/submit$',
          ).hasMatch(operation.endpoint) &&
          await _submitWasAlreadyApplied(operation.endpoint)) {
        await _deleteOperation(operation.id);
        return _RetryOutcome.success;
      }
      await _recordRetryFailure(operation, error);

      if (operation.status == SyncOperationStatuses.queued) {
        return _RetryOutcome.retry;
      }

      return _RetryOutcome.blocked;
    } on FormatException catch (error) {
      operation
        ..status = SyncOperationStatuses.needsEdit
        ..lastBusinessError = error.message;
      await _save(operation);
      return _RetryOutcome.blocked;
    } on FileSystemException {
      operation
        ..status = SyncOperationStatuses.needsEdit
        ..lastBusinessError = SyncQueueMessages.attachmentUnavailable;
      await _save(operation);
      return _RetryOutcome.blocked;
    } finally {
      for (final path in temporaryAttachments) {
        try {
          await _deleteMaterializedAttachment?.call(path);
        } catch (_) {}
      }
    }
  }

  Future<void> _advanceJournalToSubmit(
    QueuedSyncOperation operation,
    int entryId,
  ) async {
    final payload = Map<String, dynamic>.from(operation.payload);
    final createKey =
        payload['create_idempotency_key'] ?? payload['idempotency_key'];
    operation
      ..operationType = 'submit_entry'
      ..endpoint = '/journal-entries/$entryId/submit'
      ..method = 'POST'
      ..payloadJson = jsonEncode({
        ...payload,
        'stage': 'submit',
        'created_entry_id': entryId,
        'entry_id': entryId,
        'create_idempotency_key': createKey,
        'idempotency_key': '$createKey:submit',
      });
    await _save(operation);
  }

  Future<bool> _submitWasAlreadyApplied(String submitEndpoint) async {
    final entryEndpoint = submitEndpoint.substring(
      0,
      submitEndpoint.length - '/submit'.length,
    );
    try {
      final response = await _dio.get(entryEndpoint);
      final data = response.data;
      final payload = data is Map && data['data'] is Map ? data['data'] : data;
      final status = payload is Map ? payload['status']?.toString() : null;
      return status == 'submitted' || status == 'approved';
    } on DioException catch (_) {
      return false;
    }
  }

  Future<void> _recordRetryFailure(
    QueuedSyncOperation operation,
    DioException error,
  ) async {
    final statusCode = error.response?.statusCode;
    if (_isNetworkError(error) || (statusCode != null && statusCode >= 500)) {
      if (error.type == DioExceptionType.connectionTimeout ||
          _hasConfirmedIdempotencyContract(operation)) {
        operation
          ..status = SyncOperationStatuses.queued
          ..nextAttemptAt = _now().add(_backoff(operation.attemptCount))
          ..lastBusinessError = SyncQueueMessages.queuedForNetwork;
      } else {
        operation
          ..status = SyncOperationStatuses.conflict
          ..nextAttemptAt = null
          ..lastBusinessError = SyncQueueMessages.unknownOutcome;
      }
      await _save(operation);
      return;
    }

    if (statusCode == 403) {
      operation
        ..status = SyncOperationStatuses.permissionDenied
        ..nextAttemptAt = null
        ..lastBusinessError = SyncQueueMessages.permissionDenied;
      await _save(operation);
      return;
    }

    if (statusCode == 409) {
      operation
        ..status = SyncOperationStatuses.conflict
        ..nextAttemptAt = null
        ..lastBusinessError = ApiException.fromDio(error).message;
      await _save(operation);
      return;
    }

    operation
      ..status = SyncOperationStatuses.needsEdit
      ..nextAttemptAt = null
      ..lastBusinessError = ApiException.fromDio(error).message;
    await _save(operation);
  }

  void _recordInitialFailure(
    QueuedSyncOperation operation,
    DioException error, {
    bool incrementAttempt = false,
  }) {
    final statusCode = error.response?.statusCode;
    final attemptedAt = _now();
    final wasSending = operation.status == SyncOperationStatuses.sending;
    operation
      ..attemptCount =
          wasSending
              ? operation.attemptCount
              : incrementAttempt
              ? operation.attemptCount + 1
              : 1
      ..lastAttemptAt = operation.lastAttemptAt ?? attemptedAt;

    if (_isNetworkError(error) || (statusCode != null && statusCode >= 500)) {
      if (error.type == DioExceptionType.connectionTimeout ||
          _hasConfirmedIdempotencyContract(operation)) {
        operation
          ..status = SyncOperationStatuses.queued
          ..nextAttemptAt = attemptedAt.add(_backoff(operation.attemptCount))
          ..lastBusinessError = SyncQueueMessages.queuedForNetwork;
      } else {
        operation
          ..status = SyncOperationStatuses.conflict
          ..nextAttemptAt = null
          ..lastBusinessError = SyncQueueMessages.unknownOutcome;
      }
      return;
    }

    if (statusCode == 403) {
      operation
        ..status = SyncOperationStatuses.permissionDenied
        ..nextAttemptAt = null
        ..lastBusinessError = SyncQueueMessages.permissionDenied;
      return;
    }

    operation
      ..status =
          statusCode == 409
              ? SyncOperationStatuses.conflict
              : SyncOperationStatuses.needsEdit
      ..nextAttemptAt = null
      ..lastBusinessError = ApiException.fromDio(error).message;
  }

  bool _hasConfirmedIdempotencyContract(QueuedSyncOperation operation) {
    final key = operation.payload['idempotency_key']?.toString().trim();
    if (key == null ||
        key.isEmpty ||
        operation.method.toUpperCase() != 'POST') {
      return false;
    }

    final path = Uri.tryParse(operation.endpoint)?.path ?? operation.endpoint;
    return switch ((operation.moduleSlug, operation.operationType)) {
      ('site_requests', 'create_site_request') => path == '/site-requests',
      ('machinery_operations', 'start_shift') =>
        path == '/machinery-operations/shift-reports',
      ('machinery_operations', 'finish_shift') => RegExp(
        r'^/machinery-operations/shift-reports/\d+/finish$',
      ).hasMatch(path),
      ('machinery_operations', 'submit_shift') => RegExp(
        r'^/machinery-operations/shift-reports/\d+/submit$',
      ).hasMatch(path),
      ('machinery_operations', 'record_downtime') =>
        path == '/machinery-operations/downtimes',
      ('machinery_operations', 'record_fuel') =>
        path == '/machinery-operations/fuel-issues',
      ('machinery_operations', 'complete_maintenance') => RegExp(
        r'^/machinery-operations/maintenance-orders/\d+/complete$',
      ).hasMatch(path),
      ('machinery_operations', 'issue_asset') =>
        path == '/warehouse/custody/issue',
      ('production_labor', 'record_output') =>
        path == '/production-labor/output-entries',
      ('safety', 'create_incident') => path == '/safety-management/incidents',
      ('safety', 'create_violation') => path == '/safety-management/violations',
      ('safety', 'create_inspection_finding') =>
        path == '/safety-management/inspection-findings',
      ('warehouse', 'custody_issue') => path == '/warehouse/custody/issue',
      ('warehouse', 'write_off') => path == '/warehouse/operations/write-off',
      ('warehouse', 'custody_return') => path == '/warehouse/custody/return',
      ('warehouse', 'receive_project_delivery') => RegExp(
        r'^/warehouse/project-material-deliveries/\d+/receive$',
      ).hasMatch(path),
      ('warehouse', 'create_receipt') =>
        path == '/warehouse/operations/receipt',
      ('warehouse', 'create_transfer') =>
        path == '/warehouse/operations/transfer',
      ('procurement', 'receive_materials') => RegExp(
        r'^/procurement/purchase-orders/\d+/receive-materials$',
      ).hasMatch(path),
      ('legal_archive', 'upload_paper_original') => RegExp(
        r'^/legal-archive/signature-requests/\d+/upload-original$',
      ).hasMatch(path),
      ('legal_archive', final action) =>
        RegExp(
              r'^/legal-archive/documents/\d+/actions/[^/]+$',
            ).hasMatch(path) &&
            path.endsWith('/actions/$action'),
      ('construction_journal', 'create_entry' || 'create_and_submit_entry') =>
        RegExp(r'^/construction-journals/\d+/entries$').hasMatch(path),
      _ => false,
    };
  }

  Future<Object?> _requestData(
    QueuedSyncOperation operation,
    List<String> temporaryAttachments,
  ) async {
    final attachments = operation.attachments;
    final payload = operation.payload;
    payload.remove('queue_scope');
    payload.remove('queue_owner_identity');
    payload.remove('queue_session_id');
    payload.remove('queue_user_id');
    payload.remove('queue_organization_id');
    payload.remove('queue_document_id');
    payload.remove('queue_encrypted_attachment');
    if (operation.moduleSlug == 'construction_journal') {
      if (RegExp(
        r'^/journal-entries/\d+/submit$',
      ).hasMatch(operation.endpoint)) {
        return {'idempotency_key': payload['idempotency_key']};
      }
      for (final key in [
        'queue_scope',
        'stage',
        'created_entry_id',
        'submit_intent',
        'create_idempotency_key',
        'journal_id',
        'entry_id',
      ]) {
        payload.remove(key);
      }
    }
    if (operation.moduleSlug == 'legal_archive') {
      for (final key in [
        'queue_scope',
        'queue_owner_identity',
        'queue_session_id',
        'queue_user_id',
        'queue_organization_id',
        'queue_document_id',
        'queue_encrypted_attachment',
      ]) {
        payload.remove(key);
      }
    }
    if (attachments.isEmpty) {
      return payload;
    }

    final formData = FormData();
    payload.forEach((key, value) {
      if (value != null) {
        formData.fields.add(MapEntry(key, _formValue(value)));
      }
    });

    for (final attachment in attachments) {
      formData.files.add(
        MapEntry(
          attachment.field,
          await MultipartFile.fromFile(
            attachment.encrypted
                ? await _materializeQueuedAttachment(
                  attachment,
                  operation,
                  temporaryAttachments,
                )
                : attachment.path,
            filename: attachment.filename ?? _fileName(attachment.path),
          ),
        ),
      );
    }

    return formData;
  }

  Future<String> _materializeQueuedAttachment(
    SyncAttachmentRef attachment,
    QueuedSyncOperation operation,
    List<String> temporaryAttachments,
  ) async {
    final callback = _materializeAttachment;
    final ownerIdentity =
        operation.payload['queue_owner_identity']?.toString() ??
        operation.payload['queue_scope']?.toString();
    if (callback == null || ownerIdentity == null || ownerIdentity.isEmpty) {
      throw const FormatException('Не удалось открыть файл для отправки.');
    }
    final path = await callback(attachment, ownerIdentity);
    temporaryAttachments.add(path);
    return path;
  }

  Duration _backoff(int attemptCount) {
    final minutes = switch (attemptCount) {
      <= 1 => 1,
      2 => 3,
      3 => 10,
      4 => 30,
      _ => 60,
    };

    return Duration(minutes: minutes);
  }

  static bool _isNetworkError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown => error.response == null,
      _ => false,
    };
  }

  String _formValue(Object value) {
    if (value is String) {
      return value;
    }

    return value.toString();
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');

    return parts.isEmpty ? path : parts.last;
  }
}

enum _RetryOutcome { success, retry, blocked }
