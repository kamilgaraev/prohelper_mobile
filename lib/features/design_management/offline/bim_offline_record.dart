import 'package:isar/isar.dart';

part 'bim_offline_record.g.dart';

@collection
class BimOfflineRecord {
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  late String scope;
  @Index(type: IndexType.value)
  late String key;
  late String kind;
  late String status;
  int versionId = 0;
  String title = '';
  String manifestJson = '{}';
  String encryptedPath = '';
  String propertiesPath = '';
  int geometryBytes = 0;
  int propertiesBytes = 0;
  bool attempted = false;
  int? serverId;
  int? serverRevision;
  String? lastError;
  int attempts = 0;
  List<String> attachmentAcks = [];
  String attachmentRevisionsJson = '{}';
  DateTime? nextAttemptAt;
}

@collection
class BimElementIndex {
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  late String scope;
  @Index(type: IndexType.value)
  late String packageKey;
  int expressId = 0;
  int offset = 0;
  int length = 0;
}
