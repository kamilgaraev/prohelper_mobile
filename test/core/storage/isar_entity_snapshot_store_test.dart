import 'dart:ffi';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity.dart';
import 'package:prohelpers_mobile/core/storage/isar_entity_snapshot_store.dart';

void main() {
  test(
    'snapshot schema opens and upserts by the full owner/project scope',
    () async {
      for (final index in CachedEntitySchema.indexes.values) {
        expect(index.properties.length, lessThanOrEqualTo(3));
      }

      await _initializeIsarCoreForTest();
      final directory = await Directory.systemTemp.createTemp(
        'entity-snapshot-isar-',
      );
      final isar = await Isar.open(
        [CachedEntitySchema],
        directory: directory.path,
        name: 'entity-snapshot-test',
      );
      addTearDown(() async {
        await isar.close(deleteFromDisk: true);
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final store = IsarEntitySnapshotStore(isar);
      await store.put(_entity(userId: 7, projectId: 15, payload: 'first'));
      await store.put(_entity(userId: 7, projectId: 15, payload: 'updated'));
      await store.put(_entity(userId: 7, projectId: null, payload: 'unscoped'));
      await store.put(
        _entity(userId: 8, projectId: 15, payload: 'other owner'),
      );

      final ownerProject = await store.findList(
        userId: 7,
        orgId: 10,
        type: 'site_requests',
        projectId: 15,
      );
      final ownerUnscoped = await store.findList(
        userId: 7,
        orgId: 10,
        type: 'site_requests',
      );
      final otherOwner = await store.findList(
        userId: 8,
        orgId: 10,
        type: 'site_requests',
        projectId: 15,
      );

      expect(ownerProject, hasLength(1));
      expect(ownerProject.single.payloadJson, 'updated');
      expect(ownerUnscoped, hasLength(1));
      expect(ownerUnscoped.single.payloadJson, 'unscoped');
      expect(otherOwner, hasLength(1));
      expect(otherOwner.single.payloadJson, 'other owner');
    },
  );
}

Future<void> _initializeIsarCoreForTest() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

  final packageConfigFile = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final packageConfig =
      jsonDecode(await packageConfigFile.readAsString())
          as Map<String, dynamic>;
  final packages = packageConfig['packages'] as List<dynamic>;
  final package = packages.cast<Map<String, dynamic>>().firstWhere(
    (entry) => entry['name'] == 'isar_flutter_libs',
  );
  final packageDirectory = Directory.fromUri(
    packageConfigFile.absolute.uri.resolve(package['rootUri'] as String),
  );
  final libraryPath = switch (Platform.operatingSystem) {
    'windows' => '${packageDirectory.path}/windows/isar.dll',
    'linux' => '${packageDirectory.path}/linux/libisar.so',
    'macos' => '${packageDirectory.path}/macos/libisar.dylib',
    _ => throw UnsupportedError(Platform.operatingSystem),
  };
  await Isar.initializeIsarCore(libraries: {Abi.current(): libraryPath});
}

CachedEntity _entity({
  required int userId,
  required int? projectId,
  required String payload,
}) {
  final now = DateTime.utc(2026, 9, 27);
  return CachedEntity()
    ..userId = userId
    ..orgId = 10
    ..projectId = projectId
    ..type = 'site_requests'
    ..remoteId = 'same-remote-id'
    ..payloadJson = payload
    ..updatedAt = now
    ..pulledAt = now
    ..dirty = false;
}
