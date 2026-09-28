import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/core/storage/cached_entity.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_service.dart';
import 'package:prohelpers_mobile/core/storage/entity_snapshot_store.dart';
import 'package:prohelpers_mobile/core/storage/snapshot_read.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_snapshot_adapter.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_request_detail_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_scope.dart';

import '../../../helpers/memory_entity_snapshot_store.dart';

void main() {
  test(
    'successful status action refreshes detail cache for offline reopen',
    () async {
      final store = MemoryEntitySnapshotStore();
      const owner = EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _SiteRequestRepository();
      final adapter = _adapter(repository, store: store, owner: () => owner);
      final seeded = await adapter.loadDetail(
        online: true,
        requestId: 42,
        projectId: 15,
      );
      expect(seeded.data?.status, 'pending');

      repository.detailOffline = true;
      final container = _container(repository, adapter);
      addTearDown(container.dispose);
      final provider = siteRequestDetailProvider(42);
      final notifier = container.read(provider.notifier);
      await notifier.loadDetails();
      expect(container.read(provider).request?.status, 'pending');
      expect(container.read(provider).fromCache, isTrue);

      repository.detailOffline = false;
      await notifier.changeStatus('completed');
      final afterMutation = container.read(provider);
      final reopenedOffline = await adapter.loadDetail(
        online: false,
        requestId: 42,
        projectId: 15,
      );

      expect(
        {
          'actionStatus': afterMutation.request?.status,
          'actionFromCache': afterMutation.fromCache,
          'actionHasDirtyLocal': afterMutation.hasDirtyLocal,
          'offlineStatus': reopenedOffline.data?.status,
          'offlineFromCache': reopenedOffline.fromCache,
          'offlineHasDirtyLocal': reopenedOffline.hasDirtyLocal,
        },
        {
          'actionStatus': 'completed',
          'actionFromCache': false,
          'actionHasDirtyLocal': false,
          'offlineStatus': 'completed',
          'offlineFromCache': true,
          'offlineHasDirtyLocal': false,
        },
      );
    },
  );

  test(
    'owner change during a pending status action cannot expose its ACK',
    () async {
      final store = MemoryEntitySnapshotStore();
      var owner = const EntitySnapshotOwner(userId: 7, orgId: 10);
      final repository = _SiteRequestRepository();
      final adapter = _adapter(repository, store: store, owner: () => owner);
      await adapter.loadDetail(online: true, requestId: 42, projectId: 15);
      repository.detailOffline = true;
      repository.pendingStatusResult = Completer<Map<String, dynamic>>();
      repository.statusActionStarted = Completer<void>();
      final container = _container(repository, adapter);
      final provider = siteRequestDetailProvider(42);
      final notifier = container.read(provider.notifier);
      await notifier.loadDetails();

      final mutation = notifier.changeStatus('completed');
      await repository.statusActionStarted!.future;
      owner = const EntitySnapshotOwner(userId: 8, orgId: 10);
      repository.pendingStatusResult!.complete(_updatedPayload(repository));
      await mutation;

      expect(container.read(provider).request, isNull);
      expect(container.read(provider).permissionDenied, isTrue);
      final newOwnerCache = await adapter.readDetailCached(
        requestId: 42,
        projectId: 15,
      );
      expect(newOwnerCache.presence, SnapshotPresence.missing);
      expect(newOwnerCache.data, isNull);
      container.dispose();
    },
  );

  test(
    'status ACK updates existing all-scope list row before list refresh fails',
    () async {
      final repository = _SiteRequestRepository();
      final adapter = _adapter(repository);
      final container = _container(repository, adapter);
      addTearDown(container.dispose);
      await container
          .read(siteRequestsProvider.notifier)
          .loadRequests(refresh: true);
      await adapter.loadDetail(online: true, requestId: 42, projectId: 15);
      repository.detailOffline = true;
      final provider = siteRequestDetailProvider(42);
      final notifier = container.read(provider.notifier);
      await notifier.loadDetails();

      repository.goOfflineAfterStatusAck = true;
      await notifier.changeStatus('completed');

      final listState = container.read(siteRequestsProvider);
      expect(listState.requests.map((request) => request.serverId), [42]);
      expect(listState.requests.single.status, 'completed');
      expect(listState.fromCache, isTrue);
      expect(listState.hasDirtyLocal, isFalse);
      expect(listState.error, isNotNull);

      final callsAfterFailedRefresh = repository.listFetchCount;
      final offlineAll = await adapter.load(
        online: false,
        projectId: 15,
        scope: SiteRequestsScope.all,
      );
      expect(offlineAll.data?.map((request) => request.serverId), [42]);
      expect(offlineAll.data?.single.status, 'completed');
      expect(offlineAll.fromCache, isTrue);
      expect(repository.listFetchCount, callsAfterFailedRefresh);
    },
  );

  test(
    'status ACK makes filtered and approvals list snapshots stale',
    () async {
      final repository = _SiteRequestRepository();
      final adapter = _adapter(repository);
      const owner = EntitySnapshotOwner(userId: 7, orgId: 10);
      await adapter.load(
        online: true,
        projectId: 15,
        status: 'pending',
        scope: SiteRequestsScope.all,
      );
      await adapter.load(
        online: true,
        projectId: 15,
        scope: SiteRequestsScope.approvals,
      );

      await adapter.updateExistingListAliasesFromAcknowledgedDetail(
        payload: _updatedPayload(repository),
        requestId: 42,
        projectId: 15,
        expectedOwner: owner,
      );

      final filteredOffline = await adapter.load(
        online: false,
        projectId: 15,
        status: 'pending',
        scope: SiteRequestsScope.all,
      );
      final approvalsOffline = await adapter.load(
        online: false,
        projectId: 15,
        scope: SiteRequestsScope.approvals,
      );
      expect(filteredOffline.presence, SnapshotPresence.missing);
      expect(approvalsOffline.presence, SnapshotPresence.missing);
      expect(filteredOffline.data, isNull);
      expect(approvalsOffline.data, isNull);
    },
  );

  test(
    'disposed detail notifier can finish an acknowledged action safely',
    () async {
      final repository = _SiteRequestRepository();
      final adapter = _adapter(repository);
      await adapter.loadDetail(online: true, requestId: 42, projectId: 15);
      repository.detailOffline = true;
      repository.pendingStatusResult = Completer<Map<String, dynamic>>();
      repository.statusActionStarted = Completer<void>();
      final container = _container(repository, adapter);
      final notifier = container.read(siteRequestDetailProvider(42).notifier);
      await notifier.loadDetails();

      final mutation = notifier.changeStatus('completed');
      await repository.statusActionStarted!.future;
      container.dispose();
      repository.pendingStatusResult!.complete(_updatedPayload(repository));
      await expectLater(mutation, completes);

      final reopened = await adapter.loadDetail(
        online: false,
        requestId: 42,
        projectId: 15,
      );
      expect(reopened.data?.status, 'completed');
    },
  );

  test(
    'cache write failure does not fail the server action or preserve clean stale data',
    () async {
      final store = _ToggleFailSnapshotStore();
      final repository = _SiteRequestRepository();
      final adapter = _adapter(repository, store: store);
      await adapter.loadDetail(online: true, requestId: 42, projectId: 15);
      repository.detailOffline = true;
      final container = _container(repository, adapter);
      final provider = siteRequestDetailProvider(42);
      final notifier = container.read(provider.notifier);
      await notifier.loadDetails();

      repository.detailOffline = false;
      store.failPuts = true;
      await expectLater(notifier.changeStatus('completed'), completes);

      final state = container.read(provider);
      expect(state.request?.status, 'completed');
      expect(state.fromCache, isFalse);
      expect(state.hasDirtyLocal, isFalse);
      expect(
        state.error,
        'Статус изменён на сервере, но локальная копия не обновлена.',
      );
      final reopened = await adapter.loadDetail(
        online: false,
        requestId: 42,
        projectId: 15,
      );
      expect(reopened.presence, SnapshotPresence.missing);
      expect(reopened.data, isNull);
      container.dispose();
    },
  );
}

ProviderContainer _container(
  _SiteRequestRepository repository,
  SiteRequestsSnapshotAdapter adapter,
) => ProviderContainer(
  overrides: [
    siteRequestsRepositoryProvider.overrideWithValue(repository),
    siteRequestsSnapshotAdapterProvider.overrideWithValue(adapter),
    siteRequestsProvider.overrideWith(
      (ref) => SiteRequestsNotifier(
        repository,
        snapshotAdapter: adapter,
        initialProjectId: 15,
      ),
    ),
    siteRequestDetailProvider.overrideWith(
      (ref, id) => SiteRequestDetailNotifier(
        repository,
        ref,
        id,
        snapshotAdapter: adapter,
        projectId: 15,
      ),
    ),
  ],
);

SiteRequestsSnapshotAdapter _adapter(
  _SiteRequestRepository repository, {
  EntitySnapshotStore? store,
  EntitySnapshotOwner? Function()? owner,
}) => SiteRequestsSnapshotAdapter(
  repository: repository,
  snapshots: Future.value(
    EntitySnapshotService(
      store: store ?? MemoryEntitySnapshotStore(),
      resolveOwner:
          owner ?? () => const EntitySnapshotOwner(userId: 7, orgId: 10),
    ),
  ),
);

Map<String, dynamic> _updatedPayload(_SiteRequestRepository repository) => {
  ...repository.payload,
  'status': 'completed',
  'status_label': 'Завершена',
};

class _SiteRequestRepository extends SiteRequestsRepository {
  _SiteRequestRepository() : super(Dio());

  final payload = <String, dynamic>{
    'id': 42,
    'project_id': 15,
    'title': 'Аренда лесов',
    'status': 'pending',
    'status_label': 'На согласовании',
    'priority': 'medium',
    'request_type': 'equipment_request',
  };
  bool detailOffline = false;
  bool listOffline = false;
  bool goOfflineAfterStatusAck = false;
  int listFetchCount = 0;
  Completer<Map<String, dynamic>>? pendingStatusResult;
  Completer<void>? statusActionStarted;

  @override
  Future<Map<String, dynamic>> fetchSiteRequestDetailsPayload(int id) async {
    if (detailOffline) {
      throw ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/site-requests/$id'),
          type: DioExceptionType.connectionError,
        ),
        fallbackMessage: 'Не удалось загрузить детали заявки.',
      );
    }
    return Map<String, dynamic>.from(payload);
  }

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
    if (listOffline) {
      throw ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/site-requests'),
          type: DioExceptionType.connectionError,
        ),
        fallbackMessage: 'Не удалось загрузить заявки.',
      );
    }
    return [Map<String, dynamic>.from(payload)];
  }

  @override
  Future<Map<String, dynamic>> changeSiteRequestStatusPayload(
    int id,
    String status, {
    String? notes,
  }) async {
    if (pendingStatusResult != null) {
      statusActionStarted?.complete();
      return pendingStatusResult!.future;
    }
    payload['status'] = status;
    payload['status_label'] = 'Завершена';
    if (goOfflineAfterStatusAck) listOffline = true;
    return Map<String, dynamic>.from(payload);
  }
}

class _ToggleFailSnapshotStore implements EntitySnapshotStore {
  final _store = MemoryEntitySnapshotStore();
  bool failPuts = false;

  @override
  Future<void> put(CachedEntity entity) {
    if (failPuts) throw StateError('snapshot store temporarily unavailable');
    return _store.put(entity);
  }

  @override
  Future<void> deleteCleanScope({
    required int userId,
    required int orgId,
    required String type,
    required int? projectId,
    required Set<String> keepRemoteIds,
  }) => _store.deleteCleanScope(
    userId: userId,
    orgId: orgId,
    type: type,
    projectId: projectId,
    keepRemoteIds: keepRemoteIds,
  );

  @override
  Future<CachedEntity?> findOne({
    required int userId,
    required int orgId,
    required String type,
    required String remoteId,
    int? projectId,
  }) => _store.findOne(
    userId: userId,
    orgId: orgId,
    type: type,
    remoteId: remoteId,
    projectId: projectId,
  );

  @override
  Future<List<CachedEntity>> findList({
    required int userId,
    required int orgId,
    required String type,
    int? projectId,
  }) => _store.findList(
    userId: userId,
    orgId: orgId,
    type: type,
    projectId: projectId,
  );
}
