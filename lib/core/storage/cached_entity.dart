import 'package:isar/isar.dart';

part 'cached_entity.g.dart';

@Collection(accessor: 'cachedEntities')
class CachedEntity {
  CachedEntity();

  Id id = Isar.autoIncrement;

  @Index()
  late int userId;

  @Index()
  late int orgId;

  @Index()
  int? projectId;

  @Index()
  late String type;

  @Index()
  late String remoteId;
  late String payloadJson;
  late DateTime updatedAt;
  late DateTime pulledAt;
  late bool dirty;
}
