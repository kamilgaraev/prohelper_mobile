import 'dart:convert';

import 'package:isar/isar.dart';

import '../../auth/data/auth_session_identity.dart';

part 'legal_document_snapshot.g.dart';

class LegalDocumentCacheIdentity {
  const LegalDocumentCacheIdentity({
    required this.userId,
    required this.organizationId,
    required this.sessionId,
  });

  factory LegalDocumentCacheIdentity.fromAuth(AuthSessionIdentity identity) =>
      LegalDocumentCacheIdentity(
        userId: identity.userId,
        organizationId: identity.organizationId,
        sessionId: identity.sessionId,
      );

  final int userId;
  final int? organizationId;
  final String sessionId;

  String key(int projectId, String kind, [int? documentId]) =>
      '$userId:${organizationId ?? 0}:$sessionId:$projectId:$kind:${documentId ?? 0}';
}

@collection
class LegalDocumentSnapshot {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String cacheKey;

  late int userId;
  late int organizationId;
  late int projectId;
  late String sessionId;
  late String kind;
  int? documentId;
  late String payloadJson;
  late bool isComplete;
  late DateTime savedAt;

  @ignore
  Map<String, dynamic> get payload {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Legal document snapshot is invalid.');
  }
}
