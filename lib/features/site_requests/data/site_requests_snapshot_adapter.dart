import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/cached_entity.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/entity_snapshot_store.dart';
import '../../../core/storage/list_snapshot.dart';
import '../../../core/storage/snapshot_load.dart';
import '../../../core/storage/snapshot_read.dart';
import '../domain/site_requests_scope.dart';
import 'site_request_model.dart';
import 'site_requests_repository.dart';

class SiteRequestsSnapshotAdapter {
  SiteRequestsSnapshotAdapter({
    required SiteRequestsRepository repository,
    required Future<EntitySnapshotService> snapshots,
    Future<void> Function()? flushQueue,
  }) : _repository = repository,
       _snapshots = snapshots,
       _flushQueue = flushQueue;

  final SiteRequestsRepository _repository;
  final Future<EntitySnapshotService> _snapshots;
  final Future<void> Function()? _flushQueue;

  static const detailType = 'site_request_detail';
  static const _queryMarkerPrefix = '$snapshotCollectionRemoteId:';

  Future<EntitySnapshotOwner?> currentOwner() async =>
      (await _snapshots).currentOwner;

  Future<bool> isCurrentOwner(EntitySnapshotOwner? expectedOwner) async {
    try {
      return (await _snapshots).currentOwner == expectedOwner;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveAcknowledgedDetail({
    required Map<String, dynamic> payload,
    required int requestId,
    required int? projectId,
    required EntitySnapshotOwner? expectedOwner,
  }) async {
    if (expectedOwner == null) return;
    final service = await _snapshots;
    if (service.currentOwner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
    await service.pullAndMerge(
      detailType,
      () async => [
        cachedEntityFromPayload(
          type: detailType,
          remoteId: '$requestId',
          payload: payload,
          projectId: projectId ?? snapshotProjectIdOf(payload),
        ),
      ],
      expectedOwner: expectedOwner,
    );
    if (service.currentOwner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
  }

  Future<void> updateExistingListAliasesFromAcknowledgedDetail({
    required Map<String, dynamic> payload,
    required int requestId,
    required int? projectId,
    required EntitySnapshotOwner? expectedOwner,
  }) async {
    if (expectedOwner == null) return;
    final service = await _snapshots;
    final scopedProjectId = projectId ?? snapshotProjectIdOf(payload);
    if (service.currentOwner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
    final updatedAt = DateTime.now().toUtc();
    for (final type in const [
      'site_request_all',
      'site_request',
      'site_request_approvals',
    ]) {
      final local = await service.getOne(
        type,
        '$requestId',
        projectId: scopedProjectId,
      );
      if (service.currentOwner != expectedOwner) {
        throw const SnapshotOwnerChangedException();
      }

      final entities = await service.getList(type, scopedProjectId);
      final markers = <CachedEntity>[];
      for (final entity in entities) {
        if (entity.remoteId.startsWith(_queryMarkerPrefix)) {
          markers.add(entity);
        }
      }
      final queryHashes =
          markers
              .map(
                (marker) =>
                    marker.remoteId.substring(_queryMarkerPrefix.length),
              )
              .toSet();
      for (final entity in entities) {
        if (entity.remoteId != snapshotCollectionRemoteId) continue;
        final legacyPayload = decodeSnapshotPayload(entity);
        if (legacyPayload['permission_denied'] != true &&
            legacyPayload['query_hash'] is String &&
            !queryHashes.contains(legacyPayload['query_hash'])) {
          markers.add(entity);
        }
      }
      final aliases = <({CachedEntity marker, Map<String, dynamic> payload})>[];
      for (final marker in markers) {
        final markerPayload = decodeSnapshotPayload(marker);
        final ids =
            (markerPayload['item_ids'] as List? ?? const [])
                .map((value) => value.toString())
                .toSet();
        if (ids.contains('$requestId')) {
          aliases.add((marker: marker, payload: markerPayload));
        }
      }
      if (local != null && !local.dirty && aliases.isNotEmpty) {
        try {
          final mergedPayload = {...decodeSnapshotPayload(local), ...payload};
          await service.putSnapshot(
            cachedEntityFromPayload(
              type: type,
              remoteId: '$requestId',
              payload: mergedPayload,
              projectId: scopedProjectId,
              updatedAt: updatedAt,
              pulledAt: updatedAt,
            ),
            expectedOwner: expectedOwner,
          );
        } catch (_) {
          for (final alias in aliases) {
            await _markListStale(
              service: service,
              marker: alias.marker,
              projectId: scopedProjectId,
              type: type,
              expectedOwner: expectedOwner,
              at: updatedAt,
            );
          }
          rethrow;
        }
      }

      for (final alias in aliases) {
        final markerPayload = alias.payload;
        final queryStatus = markerPayload['query_status'];
        final queryScope = markerPayload['query_scope'];
        if (!markerPayload.containsKey('query_status') ||
            queryStatus != null ||
            queryScope == SiteRequestsScope.approvals.value) {
          await _markListStale(
            service: service,
            marker: alias.marker,
            projectId: scopedProjectId,
            type: type,
            expectedOwner: expectedOwner,
            at: updatedAt,
          );
        }
      }
    }
    if (service.currentOwner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
  }

  Future<void> _markListStale({
    required EntitySnapshotService service,
    required CachedEntity marker,
    required int? projectId,
    required String type,
    required EntitySnapshotOwner expectedOwner,
    required DateTime at,
  }) async {
    if (service.currentOwner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
    await service.putSnapshot(
      cachedEntityFromPayload(
        type: type,
        remoteId:
            marker.remoteId == snapshotCollectionRemoteId
                ? _queryMarkerPrefix +
                    (decodeSnapshotPayload(marker)['query_hash'] as String)
                : marker.remoteId,
        payload: {
          'pulled_at': at.toIso8601String(),
          ...decodeSnapshotPayload(marker),
          'stale_after_mutation': true,
        },
        projectId: projectId,
        updatedAt: at,
        pulledAt: at,
      ),
      expectedOwner: expectedOwner,
    );
  }

  Future<void> invalidateCleanDetail({
    required int requestId,
    required int? projectId,
    required Map<String, dynamic> payload,
    required EntitySnapshotOwner expectedOwner,
  }) async {
    final service = await _snapshots;
    if (service.currentOwner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
    final scopedProjectId = projectId ?? snapshotProjectIdOf(payload);
    final current = await service.getList(detailType, scopedProjectId);
    if (service.currentOwner != expectedOwner) {
      throw const SnapshotOwnerChangedException();
    }
    final keepRemoteIds = {
      snapshotCollectionRemoteId,
      for (final entity in current)
        if (entity.remoteId != '$requestId') entity.remoteId,
    };
    await service.replaceFullList(
      type: detailType,
      projectId: scopedProjectId,
      remoteIds: keepRemoteIds,
      expectedOwner: expectedOwner,
    );
  }

  static String typeFor(SiteRequestsScope scope) {
    return switch (scope) {
      SiteRequestsScope.all => 'site_request_all',
      SiteRequestsScope.own => 'site_request',
      SiteRequestsScope.approvals => 'site_request_approvals',
    };
  }

  Future<SnapshotRead<List<SiteRequestModel>>> load({
    required bool online,
    int? projectId,
    String? status,
    String? search,
    bool urgentOnly = false,
    int? assignedUserId,
    String? requestType,
    DateTime? requiredFrom,
    DateTime? requiredTo,
    SiteRequestsScope scope = SiteRequestsScope.all,
    int page = 1,
    int perPage = 20,
  }) async {
    if (projectId == null) {
      if (!online) {
        return const SnapshotRead(
          presence: SnapshotPresence.missing,
          error: 'Выберите объект, чтобы открыть сохранённые заявки без сети.',
        );
      }
      try {
        final payloads = await _fetchPayloads(
          projectId: null,
          status: status,
          search: search,
          urgentOnly: urgentOnly,
          assignedUserId: assignedUserId,
          requestType: requestType,
          requiredFrom: requiredFrom,
          requiredTo: requiredTo,
          scope: scope,
          page: page,
          perPage: perPage,
        );
        return SnapshotRead(
          presence:
              payloads.isEmpty
                  ? SnapshotPresence.empty
                  : SnapshotPresence.ready,
          data: payloads.map(SiteRequestModel.fromJson).toList(),
          hasMore: payloads.length >= perPage,
        );
      } catch (error) {
        return SnapshotRead(
          presence: SnapshotPresence.error,
          error: snapshotErrorMessage(
            error,
            'Не удалось загрузить заявки. Для просмотра без сети выберите объект.',
          ),
        );
      }
    }

    final queryHash = _queryHash(
      projectId: projectId,
      status: status,
      search: search,
      urgentOnly: urgentOnly,
      assignedUserId: assignedUserId,
      requestType: requestType,
      requiredFrom: requiredFrom,
      requiredTo: requiredTo,
      scope: scope,
      perPage: perPage,
    );
    final cached = await readCached(
      projectId: projectId,
      queryHash: queryHash,
      scope: scope,
    );
    if (!online) {
      return cached;
    }

    EntitySnapshotService? service;
    EntitySnapshotOwner? owner;
    var permissionDeniedByFetch = false;
    final type = typeFor(scope);
    try {
      await _flushQueue?.call();
      final currentService = await _snapshots;
      final expectedOwner = currentService.currentOwner;
      if (expectedOwner == null) return cached;
      service = currentService;
      owner = expectedOwner;
      final pulledAt = DateTime.now().toUtc();
      late final List<Map<String, dynamic>> payloads;
      await currentService.pullAndMerge(type, () async {
        try {
          payloads = await _fetchPayloads(
            projectId: projectId,
            status: status,
            search: search,
            urgentOnly: urgentOnly,
            assignedUserId: assignedUserId,
            requestType: requestType,
            requiredFrom: requiredFrom,
            requiredTo: requiredTo,
            scope: scope,
            page: page,
            perPage: perPage,
          );
        } catch (error) {
          permissionDeniedByFetch = isSnapshotPermissionDenied(error);
          rethrow;
        }
        return [
          for (final payload in payloads)
            cachedEntityFromPayload(
              type: type,
              remoteId: '${payload['id']}',
              payload: payload,
              projectId: projectId,
              updatedAt:
                  DateTime.tryParse(payload['updated_at']?.toString() ?? '') ??
                  pulledAt,
            ),
        ];
      }, expectedOwner: expectedOwner);

      final previousMarker = await _findQueryMarker(
        service: currentService,
        type: type,
        projectId: projectId,
        queryHash: queryHash,
      );
      final previousExtra =
          previousMarker == null
              ? const <String, dynamic>{}
              : decodeSnapshotPayload(previousMarker);
      final previousIds =
          page > 1 && previousExtra['query_hash'] == queryHash
              ? (previousExtra['item_ids'] as List? ?? const [])
                  .map((value) => value.toString())
                  .toSet()
              : <String>{};
      previousIds.addAll(payloads.map((payload) => '${payload['id']}'));
      await currentService.putSnapshot(
        _querySnapshotMarker(
          type: type,
          projectId: projectId,
          queryHash: queryHash,
          at: pulledAt,
          extra: {
            'query_hash': queryHash,
            'item_ids': previousIds.toList()..sort(),
            'has_more': payloads.length >= perPage,
            'query_status': status,
            'query_scope': scope.value,
          },
        ),
        expectedOwner: expectedOwner,
      );
      final refreshedEntities = await currentService.getList(type, projectId);
      CachedEntity? permissionMarker;
      for (final entity in refreshedEntities) {
        if (entity.remoteId == snapshotCollectionRemoteId) {
          permissionMarker = entity;
          break;
        }
      }
      if (isSnapshotPermissionRevoked(permissionMarker)) {
        await currentService.putSnapshot(
          snapshotCollectionMarker(
            type: type,
            projectId: projectId,
            at: pulledAt,
          ),
          expectedOwner: expectedOwner,
        );
      }

      final next = await readCached(
        projectId: projectId,
        queryHash: queryHash,
        scope: scope,
        fromNetwork: true,
      );
      return SnapshotRead(
        presence: next.presence,
        data: next.data,
        error: next.error,
        fromCache: false,
        hasDirtyLocal: next.hasDirtyLocal,
        hasMore: payloads.length >= perPage,
      );
    } catch (error) {
      if (isSnapshotPermissionDenied(error)) {
        if (permissionDeniedByFetch && service != null && owner != null) {
          try {
            await service.invalidateScope(
              type,
              projectId,
              expectedOwner: owner,
            );
          } catch (_) {}
        }
        return SnapshotRead(
          presence: SnapshotPresence.permissionDenied,
          error: snapshotErrorMessage(
            error,
            'Недостаточно прав для просмотра заявок.',
          ),
        );
      }
      if (isSnapshotConflict(error)) {
        return SnapshotRead(
          presence: SnapshotPresence.conflict,
          data: cached.data ?? const <SiteRequestModel>[],
          error: SnapshotUserMessages.conflict,
          fromCache: cached.hasData,
          hasDirtyLocal: true,
        );
      }
      if (error is ApiException &&
          error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500) {
        return SnapshotRead(
          presence: SnapshotPresence.error,
          data: const <SiteRequestModel>[],
          error: snapshotErrorMessage(error, 'Не удалось загрузить заявки.'),
        );
      }
      if (isSnapshotOffline(error)) {
        return SnapshotRead(
          presence: cached.presence,
          data: cached.data,
          error: snapshotErrorMessage(
            error,
            'Нет связи. Показаны сохранённые заявки.',
          ),
          fromCache: cached.hasData,
          hasDirtyLocal: cached.hasDirtyLocal,
        );
      }
      return SnapshotRead(
        presence: SnapshotPresence.error,
        error: snapshotErrorMessage(
          error,
          'Данные заявки пришли неполными. Обновите экран и повторите попытку.',
        ),
      );
    }
  }

  Future<SnapshotRead<List<SiteRequestModel>>> readCached({
    required int projectId,
    required String queryHash,
    SiteRequestsScope scope = SiteRequestsScope.all,
    bool fromNetwork = false,
  }) async {
    final type = typeFor(scope);
    final service = await _snapshots;
    final entities = await service.getList(type, projectId);
    CachedEntity? permissionMarker;
    for (final entity in entities) {
      if (entity.remoteId == snapshotCollectionRemoteId) {
        permissionMarker = entity;
        break;
      }
    }
    if (isSnapshotPermissionRevoked(permissionMarker)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final markerId = _queryMarkerId(queryHash);
    CachedEntity? marker;
    for (final entity in entities) {
      if (entity.remoteId == markerId) {
        marker = entity;
        break;
      }
    }
    if (marker == null && permissionMarker != null) {
      final legacy = decodeSnapshotPayload(permissionMarker);
      if (legacy['permission_denied'] != true &&
          legacy['query_hash'] == queryHash) {
        marker = permissionMarker;
      }
    }
    if (marker == null) {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openSiteRequestsOnce,
      );
    }
    final extra = decodeSnapshotPayload(marker);
    if (extra['query_hash'] != queryHash) {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openSiteRequestsOnce,
      );
    }
    final ids =
        (extra['item_ids'] as List? ?? const [])
            .map((value) => value.toString())
            .toSet();
    final rows = <SiteRequestModel>[];
    var dirty = false;
    for (final entity in entities) {
      if (_isCollectionMarker(entity.remoteId) ||
          !ids.contains(entity.remoteId)) {
        continue;
      }
      try {
        rows.add(SiteRequestModel.fromJson(decodeSnapshotPayload(entity)));
        dirty |= entity.dirty;
      } on FormatException {
        continue;
      }
    }

    if (dirty) {
      return SnapshotRead(
        presence: SnapshotPresence.conflict,
        data: rows,
        error: SnapshotUserMessages.conflict,
        fromCache: !fromNetwork,
        hasDirtyLocal: true,
      );
    }
    if (extra['stale_after_mutation'] == true) {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openSiteRequestsOnce,
      );
    }
    return SnapshotRead(
      presence: rows.isEmpty ? SnapshotPresence.empty : SnapshotPresence.ready,
      data: rows,
      fromCache: !fromNetwork,
    );
  }

  Future<SnapshotRead<SiteRequestModel>> loadDetail({
    required bool online,
    required int requestId,
    required int? projectId,
  }) async {
    if (projectId == null) {
      if (!online) {
        return const SnapshotRead(
          presence: SnapshotPresence.missing,
          error: SnapshotUserMessages.openSiteRequestsOnce,
        );
      }
      try {
        return SnapshotRead(
          presence: SnapshotPresence.ready,
          data: SiteRequestModel.fromJson(
            await _repository.fetchSiteRequestDetailsPayload(requestId),
          ),
        );
      } catch (error) {
        return SnapshotRead(
          presence: SnapshotPresence.error,
          error: snapshotErrorMessage(
            error,
            'Не удалось загрузить детали заявки.',
          ),
        );
      }
    }
    return loadSingleEntitySnapshot<SiteRequestModel>(
      online: online,
      readCached:
          ({bool fromNetwork = false}) => readDetailCached(
            requestId: requestId,
            projectId: projectId,
            fromNetwork: fromNetwork,
          ),
      flushQueue: _flushQueue,
      snapshots: _snapshots,
      type: detailType,
      remoteId: '$requestId',
      projectId: projectId,
      fetchPayload: () => _repository.fetchSiteRequestDetailsPayload(requestId),
      permissionFallback: 'Недостаточно прав для просмотра заявки.',
      malformedFallback:
          'Данные заявки пришли неполными. Обновите экран и повторите попытку.',
    );
  }

  Future<SnapshotRead<SiteRequestModel>> readDetailCached({
    required int requestId,
    required int projectId,
    bool fromNetwork = false,
  }) async {
    final service = await _snapshots;
    final scoped = await service.getList(detailType, projectId);
    if (scoped.any(isSnapshotPermissionRevoked)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
      );
    }
    final entity = await service.getOne(
      detailType,
      '$requestId',
      projectId: projectId,
    );
    try {
      return decodeSingleSnapshot(
        entity: entity,
        decode: SiteRequestModel.fromJson,
        missingMessage: SnapshotUserMessages.openSiteRequestsOnce,
        isEmpty: (_) => false,
        fromNetwork: fromNetwork,
      );
    } on FormatException {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openSiteRequestsOnce,
      );
    }
  }

  Future<CachedEntity?> _findQueryMarker({
    required EntitySnapshotService service,
    required String type,
    required int projectId,
    required String queryHash,
  }) async {
    final entities = await service.getList(type, projectId);
    for (final entity in entities) {
      if (entity.remoteId == _queryMarkerId(queryHash)) return entity;
    }
    for (final entity in entities) {
      if (entity.remoteId != snapshotCollectionRemoteId) continue;
      final legacy = decodeSnapshotPayload(entity);
      if (legacy['permission_denied'] != true &&
          legacy['query_hash'] == queryHash) {
        return entity;
      }
    }
    return null;
  }

  CachedEntity _querySnapshotMarker({
    required String type,
    required int projectId,
    required String queryHash,
    required DateTime at,
    required Map<String, dynamic> extra,
  }) => cachedEntityFromPayload(
    type: type,
    remoteId: _queryMarkerId(queryHash),
    payload: {'pulled_at': at.toIso8601String(), ...extra},
    projectId: projectId,
    updatedAt: at,
    pulledAt: at,
  );

  String _queryMarkerId(String queryHash) => '$_queryMarkerPrefix$queryHash';

  bool _isCollectionMarker(String remoteId) =>
      remoteId == snapshotCollectionRemoteId ||
      remoteId.startsWith(_queryMarkerPrefix);

  Future<List<Map<String, dynamic>>> _fetchPayloads({
    required int? projectId,
    required String? status,
    required String? search,
    required bool urgentOnly,
    required int? assignedUserId,
    required String? requestType,
    required DateTime? requiredFrom,
    required DateTime? requiredTo,
    required SiteRequestsScope scope,
    required int page,
    required int perPage,
  }) {
    return _repository.fetchSiteRequestPayloads(
      page: page,
      perPage: perPage,
      status: status,
      projectId: projectId,
      search: search,
      urgentOnly: urgentOnly,
      assignedUserId: assignedUserId,
      requestType: requestType,
      requiredFrom: requiredFrom,
      requiredTo: requiredTo,
      scope: scope,
    );
  }

  String _queryHash({
    required int projectId,
    required String? status,
    required String? search,
    required bool urgentOnly,
    required int? assignedUserId,
    required String? requestType,
    required DateTime? requiredFrom,
    required DateTime? requiredTo,
    required SiteRequestsScope scope,
    required int perPage,
  }) {
    final query = <String, Object?>{
      'project_id': projectId,
      'scope': scope.value,
      'status': status,
      'search': search?.trim().toLowerCase(),
      'urgent': urgentOnly,
      'assigned_user_id': assignedUserId,
      'request_type': requestType,
      'required_from': requiredFrom?.toIso8601String().split('T').first,
      'required_to': requiredTo?.toIso8601String().split('T').first,
      'per_page': perPage,
    };
    return sha256.convert(utf8.encode(jsonEncode(query))).toString();
  }
}
