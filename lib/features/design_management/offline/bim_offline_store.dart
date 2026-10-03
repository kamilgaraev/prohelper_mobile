import 'package:isar/isar.dart';
import 'bim_offline_record.dart';

abstract interface class BimOfflineStore {
  Future<List<BimOfflineRecord>> records(String scope);
  Future<BimOfflineRecord?> get(String key);
  Future<void> put(BimOfflineRecord record);
  Future<void> delete(String key);
  Future<void> putElements(List<BimElementIndex> elements);
  Future<BimElementIndex?> element(String packageKey, int expressId);
  Future<void> clearElements(String packageKey);
}

class IsarBimOfflineStore implements BimOfflineStore {
  IsarBimOfflineStore(this.isar);
  final Isar isar;
  @override
  Future<List<BimOfflineRecord>> records(String scope) =>
      isar.bimOfflineRecords.where().scopeEqualTo(scope).findAll();
  @override
  Future<BimOfflineRecord?> get(String key) =>
      isar.bimOfflineRecords.where().keyEqualTo(key).findFirst();
  @override
  Future<void> put(BimOfflineRecord record) async => isar.writeTxn(() async {
    await isar.bimOfflineRecords.put(record);
  });
  @override
  Future<void> delete(String key) async => isar.writeTxn(() async {
    await isar.bimOfflineRecords.where().keyEqualTo(key).deleteAll();
  });
  @override
  Future<void> putElements(List<BimElementIndex> elements) async =>
      isar.writeTxn(() async {
        await isar.bimElementIndexs.putAll(elements);
      });
  @override
  Future<BimElementIndex?> element(String packageKey, int expressId) =>
      isar.bimElementIndexs
          .where()
          .packageKeyEqualTo(packageKey)
          .filter()
          .expressIdEqualTo(expressId)
          .findFirst();
  @override
  Future<void> clearElements(String packageKey) async =>
      isar.writeTxn(() async {
        await isar.bimElementIndexs
            .where()
            .packageKeyEqualTo(packageKey)
            .deleteAll();
      });
}
