import 'dart:convert';

import 'package:isar/isar.dart';

import 'sync_queue_draft.dart';

part 'queued_sync_operation.g.dart';

class SyncOperationStatuses {
  static const queued = 'queued';
  static const sending = 'sending';
  static const needsEdit = 'needs_edit';
  static const permissionDenied = 'permission_denied';
}

@collection
class QueuedSyncOperation {
  QueuedSyncOperation();

  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String moduleSlug;

  @Index(type: IndexType.value)
  late String operationType;

  @Index(type: IndexType.value)
  late String status;

  late String method;
  late String endpoint;
  late String payloadJson;
  late String attachmentsJson;
  late List<String> localAttachments;
  late DateTime createdAt;
  DateTime? lastAttemptAt;
  DateTime? nextAttemptAt;
  int attemptCount = 0;
  String? lastBusinessError;

  @ignore
  Map<String, dynamic> get payload {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const FormatException('Queued sync payload must be an object.');
  }

  @ignore
  List<SyncAttachmentRef> get attachments {
    return SyncAttachmentRef.decodeList(attachmentsJson);
  }

  factory QueuedSyncOperation.fromDraft(
    SyncQueueDraft draft, {
    required DateTime createdAt,
  }) {
    return QueuedSyncOperation()
      ..moduleSlug = draft.moduleSlug
      ..operationType = draft.operationType
      ..status = SyncOperationStatuses.queued
      ..method = draft.method
      ..endpoint = draft.endpoint
      ..payloadJson = draft.encodePayload()
      ..attachmentsJson = draft.encodeAttachments()
      ..localAttachments = draft.localAttachments
      ..createdAt = createdAt;
  }
}
