import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity.dart';
import 'package:prohelpers_mobile/core/storage/isar_entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';

void main() {
  test(
    'search cache and status ACK preserve the full list across store reopen',
    () async {
      await _initializeIsarCoreForTest();
      final directory = await Directory.systemTemp.createTemp(
        'site-requests-snapshot-isas-',
      );
      var isar = await _openIsar(directory);
      addTearDown(() async {
        if (isar.isOpen) await isar.close(deleteFromDisk: true);
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      const owner = EntitySnapshotOwner(userId: 39, orgId: 38);
      final repository = _PersistedSnapshotRepository();
      SiteRequestsSnapshotAdapter createAdapter(
        Isar database, {
        EntitySnapshotOwner? currentOwner,
      }) => SiteRequestsSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(
            store: IsarEntitySnapshotStore(database),
            resolveOwner: () => currentOwner ?? owner,
          ),
        ),
      );

      var adapter = createAdapter(isar);
      final all = await adapter.load(online: true, projectId: 52);
      final filtered = await adapter.load(
        online: true,
        projectId: 52,
        search: 'QA_FINAL_IN',
      );
      final alternateFilter = await adapter.load(
        online: true,
        projectId: 52,
        search: 'FINAL',
      );
      expect(all.data, hasLength(9));
      expect(filtered.data?.map((request) => request.serverId), [577]);
      expect(alternateFilter.data?.map((request) => request.serverId), [577]);

      final cancelledPayload = {
        ..._qaRequest,
        'status': 'cancelled',
        'status_label': 'Отменена',
      };
      await adapter.saveAcknowledgedDetail(
        payload: cancelledPayload,
        requestId: 577,
        projectId: 52,
        expectedOwner: owner,
      );
      await adapter.updateExistingListAliasesFromAcknowledgedDetail(
        payload: cancelledPayload,
        requestId: 577,
        projectId: 52,
        expectedOwner: owner,
      );

      await isar.close();
      isar = await _openIsar(directory);
      adapter = createAdapter(isar);

      final offlineSearch = await adapter.load(
        online: false,
        projectId: 52,
        search: 'QA_FINAL_IN',
      );
      final offlineAlternateFilter = await adapter.load(
        online: false,
        projectId: 52,
        search: 'FINAL',
      );
      final offlineCleared = await adapter.load(online: false, projectId: 52);
      final offlineDetail = await adapter.loadDetail(
        online: false,
        requestId: 577,
        projectId: 52,
      );
      final otherProject = await adapter.load(online: false, projectId: 53);
      final otherScope = await adapter.load(
        online: false,
        projectId: 52,
        scope: SiteRequestsScope.own,
      );
      final otherOwner = await createAdapter(
        isar,
        currentOwner: const EntitySnapshotOwner(userId: 40, orgId: 38),
      ).load(online: false, projectId: 52);

      expect(offlineSearch.data?.single.status, 'cancelled');
      expect(offlineAlternateFilter.data?.single.status, 'cancelled');
      expect(offlineCleared.data, hasLength(9));
      expect(offlineCleared.data!.map((request) => request.serverId), [
        569,
        570,
        571,
        572,
        573,
        574,
        575,
        576,
        577,
      ]);
      expect(
        offlineCleared.data!.singleWhere((r) => r.serverId == 577).status,
        'cancelled',
      );
      expect(offlineDetail.data?.status, 'cancelled');
      expect(otherProject.presence, SnapshotPresence.missing);
      expect(otherScope.presence, SnapshotPresence.missing);
      expect(otherOwner.presence, SnapshotPresence.missing);
      expect(offlineCleared.fromCache, isTrue);
      expect(repository.listFetchCount, 3);
      expect(repository.detailFetchCount, 0);
    },
  );
}

Future<Isar> _openIsar(Directory directory) => Isar.open(
  [CachedEntitySchema],
  directory: directory.path,
  name: 'site-requests-snapshot-test',
);

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

class _PersistedSnapshotRepository extends SiteRequestsRepository {
  _PersistedSnapshotRepository() : super(Dio());

  var listFetchCount = 0;
  var detailFetchCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchSiteRequestPayloads({
    int page = 1,
    int perPage = 20,
    String? status,
    int? projectId,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.own,
  }) async {
    listFetchCount++;
    expect(projectId, 52);
    if (search == null) {
      return [
        for (var id = 569; id <= 577; id++)
          {
            ..._qaRequest,
            'id': id,
            'title': id == 577 ? 'QA_FINAL_IN' : 'Заявка $id',
          },
      ];
    }
    expect(search, anyOf('QA_FINAL_IN', 'FINAL'));
    return [
      {..._qaRequest, 'title': 'QA_FINAL_IN'},
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchSiteRequestDetailsPayload(int id) async {
    detailFetchCount++;
    throw StateError('Offline test must not fetch detail.');
  }
}

final _qaRequest = <String, dynamic>{
  'id': 577,
  'project_id': 52,
  'title': 'QA_FINAL_IN',
  'status': 'draft',
  'status_label': 'Черновик',
  'priority': 'medium',
  'priority_label': 'Средний',
  'request_type': 'equipment_request',
  'request_type_label': 'Техника',
};
