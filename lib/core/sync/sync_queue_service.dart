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
  }) : _store = store,
       _dio = dio,
       _now = now ?? DateTime.now;

  final SyncQueueStore _store;
  final Dio _dio;
  final DateTime Function() _now;

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

  Future<SyncQueueProcessResult> retryDueOperations() async {
    final now = _now();
    final operations = await _store.due(now);
    var successCount = 0;
    var retryCount = 0;
    var blockedCount = 0;

    for (final operation in operations) {
      final outcome = await _retryOperation(operation);

      switch (outcome) {
        case _RetryOutcome.success:
          successCount++;
        case _RetryOutcome.retry:
          retryCount++;
        case _RetryOutcome.blocked:
          blockedCount++;
      }
    }

    return SyncQueueProcessResult(
      successCount: successCount,
      retryCount: retryCount,
      blockedCount: blockedCount,
    );
  }

  Future<_RetryOutcome> _retryOperation(QueuedSyncOperation operation) async {
    operation
      ..status = SyncOperationStatuses.sending
      ..attemptCount = operation.attemptCount + 1
      ..lastAttemptAt = _now()
      ..lastBusinessError = null;
    await _store.put(operation);

    try {
      await _dio.request<dynamic>(
        operation.endpoint,
        data: await _requestData(operation),
        options: Options(method: operation.method),
      );
      await _store.delete(operation.id);
      return _RetryOutcome.success;
    } on DioException catch (error) {
      await _recordRetryFailure(operation, error);

      if (operation.status == SyncOperationStatuses.queued) {
        return _RetryOutcome.retry;
      }

      return _RetryOutcome.blocked;
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

    operation
      ..status = SyncOperationStatuses.needsEdit
      ..nextAttemptAt = null
      ..lastBusinessError = ApiException.fromDio(error).message;
    await _store.put(operation);
  }

  Future<Object?> _requestData(QueuedSyncOperation operation) async {
    final attachments = operation.attachments;
    if (attachments.isEmpty) {
      return operation.payload;
    }

    final formData = FormData();
    operation.payload.forEach((key, value) {
      if (value != null) {
        formData.fields.add(MapEntry(key, _formValue(value)));
      }
    });

    for (final attachment in attachments) {
      formData.files.add(
        MapEntry(
          attachment.field,
          await MultipartFile.fromFile(
            attachment.path,
            filename: attachment.filename ?? _fileName(attachment.path),
          ),
        ),
      );
    }

    return formData;
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
