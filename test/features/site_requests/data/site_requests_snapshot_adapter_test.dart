import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity_codec.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  test(
    'список и детали заявки переживают перезапуск в выбранном объекте',
    () async {
      final store = MemoryEntitySnapshotStore();
      final owner = EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _SiteRequestsRepository();
      final online = SiteRequestsSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );

      final list = await online.load(online: true, projectId: 15);
      final detail = await online.loadDetail(
        online: true,
        requestId: 42,
        projectId: 15,
      );

      final restarted = SiteRequestsSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );
      final restoredList = await restarted.load(online: false, projectId: 15);
      final restoredDetail = await restarted.loadDetail(
        online: false,
        requestId: 42,
        projectId: 15,
      );
      final mismatchedFilter = await restarted.load(
        online: false,
        projectId: 15,
        status: 'completed',
      );
      final otherProject = await restarted.load(online: false, projectId: 16);
      final otherOwner = SiteRequestsSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(
            store: store,
            resolveOwner: () => EntitySnapshotOwner(userId: 8, orgId: 10),
          ),
        ),
      );
      final otherUser = await otherOwner.load(online: false, projectId: 15);

      expect(list.data?.single.title, 'Аренда лесов');
      expect(detail.data?.title, 'Аренда лесов');
      expect(restoredList.data?.single.title, 'Аренда лесов');
      expect(restoredList.fromCache, isTrue);
      expect(restoredDetail.data?.title, 'Аренда лесов');
      expect(restoredDetail.fromCache, isTrue);
      expect(mismatchedFilter.presence, SnapshotPresence.missing);
      expect(otherProject.presence, SnapshotPresence.missing);
      expect(otherUser.presence, SnapshotPresence.missing);
      expect(repository.listFetchCount, 1);
      expect(repository.detailFetchCount, 1);
    },
  );

  test(
    'после возврата сети обновляет список, а 403 скрывает старый кеш',
    () async {
      final store = MemoryEntitySnapshotStore();
      const owner = EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _SiteRequestsRepository();
      final adapter = SiteRequestsSnapshotAdapter(
        repository: repository,
        snapshots: Future.value(
          EntitySnapshotService(store: store, resolveOwner: () => owner),
        ),
      );

      final initial = await adapter.load(online: true, projectId: 15);
      final offline = await adapter.load(online: false, projectId: 15);
      repository.title = 'Обновлённая заявка';
      final restoredNetwork = await adapter.load(online: true, projectId: 15);

      expect(initial.data?.single.title, 'Аренда лесов');
      expect(offline.fromCache, isTrue);
      expect(restoredNetwork.data?.single.title, 'Обновлённая заявка');
      expect(restoredNetwork.fromCache, isFalse);

      repository.permissionDenied = true;
      final denied = await adapter.load(online: true, projectId: 15);
      final afterRevocation = await adapter.load(online: false, projectId: 15);

      expect(denied.presence, SnapshotPresence.permissionDenied);
      expect(denied.data, isNull);
      expect(afterRevocation.presence, SnapshotPresence.permissionDenied);
      expect(afterRevocation.data, isNull);
    },
  );

  test('HTTP 4xx не подменяется совпадающим кешем и не удаляет его', () async {
    final store = MemoryEntitySnapshotStore();
    const owner = EntitySnapshotOwner(userId: 7, orgId: 10);
    final repository = _SiteRequestsRepository();
    final adapter = SiteRequestsSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(
        EntitySnapshotService(store: store, resolveOwner: () => owner),
      ),
    );
    const search = 'лесов';

    final seeded = await adapter.load(
      online: true,
      projectId: 15,
      search: search,
    );
    expect(seeded.data?.single.title, 'Аренда лесов');

    for (final statusCode in [401, 404, 422]) {
      repository.listErrorStatus = statusCode;
      final failed = await adapter.load(
        online: true,
        projectId: 15,
        search: search,
      );

      expect(failed.presence, SnapshotPresence.error);
      expect(failed.data, isEmpty);
      expect(failed.fromCache, isFalse);
    }

    repository.listErrorStatus = null;
    final stillCached = await adapter.load(
      online: false,
      projectId: 15,
      search: search,
    );
    expect(stillCached.data?.single.title, 'Аренда лесов');
    expect(stillCached.fromCache, isTrue);
  });

  test('403 скрывает чистые строки, но сохраняет dirty снимок', () async {
    final store = MemoryEntitySnapshotStore();
    const owner = EntitySnapshotOwner(userId: 7, orgId: 10);
    final service = EntitySnapshotService(
      store: store,
      resolveOwner: () => owner,
    );
    final repository = _SiteRequestsRepository();
    final adapter = SiteRequestsSnapshotAdapter(
      repository: repository,
      snapshots: Future.value(service),
    );
    await adapter.load(online: true, projectId: 15);
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: SiteRequestsSnapshotAdapter.typeFor(SiteRequestsScope.all),
        remoteId: '43',
        payload: {..._request, 'id': 43, 'title': 'Локальное изменение'},
        projectId: 15,
        dirty: true,
      ),
      expectedOwner: owner,
    );

    repository.permissionDenied = true;
    final denied = await adapter.load(online: true, projectId: 15);
    final remaining = await store.findList(
      userId: owner.userId,
      orgId: owner.orgId,
      type: SiteRequestsSnapshotAdapter.typeFor(SiteRequestsScope.all),
      projectId: 15,
    );

    expect(denied.presence, SnapshotPresence.permissionDenied);
    expect(remaining.map((entity) => entity.remoteId), contains('43'));
    expect(
      remaining.singleWhere((entity) => entity.remoteId == '43').dirty,
      isTrue,
    );
    expect(remaining.map((entity) => entity.remoteId), isNot(contains('42')));
  });
}

class _SiteRequestsRepository extends SiteRequestsRepository {
  _SiteRequestsRepository() : super(Dio());

  var listFetchCount = 0;
  var detailFetchCount = 0;
  var permissionDenied = false;
  int? listErrorStatus;
  String title = 'Аренда лесов';

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
    expect(projectId, 15);
    if (permissionDenied) {
      throw const ApiException('Нет доступа.', statusCode: 403);
    }
    if (listErrorStatus case final statusCode?) {
      throw ApiException('HTTP $statusCode', statusCode: statusCode);
    }
    return [
      {..._request, 'title': title},
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchSiteRequestDetailsPayload(int id) async {
    detailFetchCount++;
    expect(id, 42);
    return _request;
  }
}

final _request = <String, dynamic>{
  'id': 42,
  'project_id': 15,
  'title': 'Аренда лесов',
  'status': 'pending',
  'status_label': 'На согласовании',
  'priority': 'medium',
  'priority_label': 'Средний',
  'request_type': 'equipment_request',
  'request_type_label': 'Техника',
};
