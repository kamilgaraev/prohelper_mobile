import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'queued_sync_operation.dart';
import 'sync_queue_draft.dart';
import 'sync_queue_store.dart';

class SyncQueueMessages {
  static const queuedForNetwork = 'Будет отправлено при восстановлении связи';
  static const permissionDenied =
      'Недостаточно прав для отправки сохраненной операции.';
}

class SyncQueuedException extends ApiException {
  const SyncQueuedException({this.queueId})
    : super(SyncQueueMessages.queuedForNetwork);

  final int? queueId;
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
  )?
  _materializeAttachment;
  final Future<void> Function(String path)? _deleteMaterializedAttachment;
  final Future<void> Function(SyncAttachmentRef attachment)?
  _deleteQueuedAttachment;
  final Future<bool> Function()? _verifyOnline;
  Future<SyncQueueProcessResult>? _processing;

  String? get currentScope => _currentScope?.call();
  bool get requiresScope => _currentScope != null;

  static bool shouldQueueDioException(DioException error) {
    if (_isNetworkError(error)) {
      return true;
    }

    final statusCode = error.response?.statusCode;
    return statusCode != null && statusCode >= 500;
  }

  Future<QueuedSyncOperation> enqueue(SyncQueueDraft draft) async {
    final operation = QueuedSyncOperation.fromDraft(draft, createdAt: _now());

    return _store.put(operation);
  }

  Future<List<QueuedSyncOperation>> all() {
    return _store.all();
  }

  Future<QueuedSyncOperation?> get(int id) {
    return _store.get(id);
  }

  Future<void> delete(int id) {
    return _store.delete(id);
  }

  Future<void> clearScope(String ownerIdentity) async {
    for (final operation in await _store.all()) {
      if (operation.payload['queue_scope']?.toString() == ownerIdentity) {
        await _store.delete(operation.id);
      }
    }
  }

  Future<void> update(QueuedSyncOperation operation) {
    return _store.put(operation);
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

    final draft = SyncQueueDraft(
      moduleSlug: operation.moduleSlug,
      operationType: operation.operationType,
      method: operation.method,
      endpoint: operation.endpoint,
      payload: payload,
      attachments: attachments,
    );

    operation
      ..payloadJson = draft.encodePayload()
      ..attachmentsJson = draft.encodeAttachments()
      ..localAttachments = draft.localAttachments
      ..status = SyncOperationStatuses.queued
      ..attemptCount = 0
      ..lastAttemptAt = null
      ..nextAttemptAt = null
      ..lastBusinessError = null;

    await _store.put(operation);
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
      final interruptedJournal =
          operation.moduleSlug == 'construction_journal' &&
          operation.status == SyncOperationStatuses.sending;
      final interruptedLegalAction =
          operation.moduleSlug == 'legal_archive' &&
          operation.status == SyncOperationStatuses.sending;
      if (operation.status != SyncOperationStatuses.queued &&
          !interruptedJournal &&
          !interruptedLegalAction) {
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
      await _store.put(operation);
      return _RetryOutcome.blocked;
    }
    if ((requiresScope &&
            [
              'construction_journal',
              'legal_archive',
            ].contains(operation.moduleSlug) &&
            operationScope == null) ||
        (operationScope != null &&
            operationScope.isNotEmpty &&
            (currentScope == null || operationScope != currentScope))) {
      operation
        ..status = SyncOperationStatuses.permissionDenied
        ..lastBusinessError = SyncQueueMessages.permissionDenied;
      await _store.put(operation);
      return _RetryOutcome.blocked;
    }
    operation
      ..status = SyncOperationStatuses.sending
      ..attemptCount = operation.attemptCount + 1
      ..lastAttemptAt = _now()
      ..lastBusinessError = null;
    await _store.put(operation);

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
        await _store.put(operation);
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
        await _store.put(operation);
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
      for (final attachment in operation.attachments) {
        if (attachment.encrypted) {
          await _deleteQueuedAttachment?.call(attachment);
        }
      }
      await _store.delete(operation.id);
      return _RetryOutcome.success;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if ((statusCode == 403 || statusCode == 422) &&
          operation.moduleSlug == 'construction_journal' &&
          RegExp(
            r'^/journal-entries/\d+/submit$',
          ).hasMatch(operation.endpoint) &&
          await _submitWasAlreadyApplied(operation.endpoint)) {
        await _store.delete(operation.id);
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
      await _store.put(operation);
      return _RetryOutcome.blocked;
    } finally {
      for (final path in temporaryAttachments) {
        await _deleteMaterializedAttachment?.call(path);
      }
    }
  }

  Future<void> _advanceJournalToSubmit(
    QueuedSyncOperation operation,
    int entryId,
  ) async {
    final payload = operation.payload;
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
    await _store.put(operation);
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
      operation
        ..status = SyncOperationStatuses.queued
        ..nextAttemptAt = _now().add(_backoff(operation.attemptCount))
        ..lastBusinessError = SyncQueueMessages.queuedForNetwork;
      await _store.put(operation);
      return;
    }

    if (statusCode == 403) {
      operation
        ..status = SyncOperationStatuses.permissionDenied
        ..nextAttemptAt = null
        ..lastBusinessError = SyncQueueMessages.permissionDenied;
      await _store.put(operation);
      return;
    }

    if (statusCode == 409) {
      operation
        ..status = SyncOperationStatuses.conflict
        ..nextAttemptAt = null
        ..lastBusinessError = ApiException.fromDio(error).message;
      await _store.put(operation);
      return;
    }

    operation
      ..status = SyncOperationStatuses.needsEdit
      ..nextAttemptAt = null
      ..lastBusinessError = ApiException.fromDio(error).message;
    await _store.put(operation);
  }

  Future<Object?> _requestData(
    QueuedSyncOperation operation,
    List<String> temporaryAttachments,
  ) async {
    final attachments = operation.attachments;
    final payload = operation.payload;
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
    final ownerIdentity = operation.payload['queue_owner_identity']?.toString();
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
