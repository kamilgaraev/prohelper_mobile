import 'dart:convert';

import '../network/api_exception.dart';
import 'cached_entity.dart';

const snapshotCollectionRemoteId = '__collection__';

CachedEntity cachedEntityFromPayload({
  required String type,
  required String remoteId,
  required Map<String, dynamic> payload,
  int? projectId,
  DateTime? updatedAt,
  DateTime? pulledAt,
  bool dirty = false,
}) {
  final parsedUpdatedAt = DateTime.tryParse(
    payload['updated_at']?.toString() ?? '',
  );
  final stamp = updatedAt ?? parsedUpdatedAt ?? DateTime.now().toUtc();

  return CachedEntity()
    ..userId = 0
    ..orgId = 0
    ..projectId = projectId
    ..type = type
    ..remoteId = remoteId
    ..payloadJson = jsonEncode(payload)
    ..updatedAt = stamp
    ..pulledAt = pulledAt ?? stamp
    ..dirty = dirty;
}

CachedEntity snapshotCollectionMarker({
  required String type,
  int? projectId,
  required DateTime at,
  Map<String, dynamic>? extra,
}) {
  return cachedEntityFromPayload(
    type: type,
    remoteId: snapshotCollectionRemoteId,
    payload: <String, dynamic>{'pulled_at': at.toIso8601String(), ...?extra},
    projectId: projectId,
    updatedAt: at,
    pulledAt: at,
  );
}

Map<String, dynamic> decodeSnapshotPayload(CachedEntity entity) {
  final decoded = jsonDecode(entity.payloadJson);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const FormatException('Snapshot payload must be a JSON object.');
}

bool isSnapshotCollectionMarker(CachedEntity entity) {
  return entity.remoteId == snapshotCollectionRemoteId;
}

bool isSnapshotPermissionRevoked(CachedEntity? entity) {
  if (entity == null || !isSnapshotCollectionMarker(entity)) return false;
  try {
    return decodeSnapshotPayload(entity)['permission_denied'] == true;
  } on FormatException {
    return true;
  }
}

bool isSnapshotPermissionDenied(Object error) {
  return error is ApiException && error.statusCode == 403;
}

bool isSnapshotConflict(Object error) {
  return error is ApiException && error.statusCode == 409;
}

bool isSnapshotOffline(Object error) {
  if (error is ApiException) {
    final statusCode = error.statusCode;
    if (statusCode == 403 || statusCode == 409 || statusCode == 422) {
      return false;
    }
    if (statusCode != null && statusCode >= 500) {
      return true;
    }
    return statusCode == null;
  }
  return false;
}

String snapshotErrorMessage(Object error, String fallback) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is FormatException) {
    return fallback;
  }
  return fallback;
}
