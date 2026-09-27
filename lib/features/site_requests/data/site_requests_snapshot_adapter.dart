import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/storage/cached_entity.dart';
import '../../../core/storage/cached_entity_codec.dart';
import '../../../core/storage/entity_snapshot_service.dart';
import '../../../core/storage/entity_snapshot_store.dart';
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

      final previousMarker = await currentService.getOne(
        type,
        snapshotCollectionRemoteId,
        projectId: projectId,
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
        snapshotCollectionMarker(
          type: type,
          projectId: projectId,
          at: pulledAt,
          extra: {
            'query_hash': queryHash,
            'item_ids': previousIds.toList()..sort(),
            'has_more': payloads.length >= perPage,
          },
        ),
        expectedOwner: expectedOwner,
      );

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
      if (isSnapshotOffline(error) || cached.hasData) {
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
    CachedEntity? marker;
    for (final entity in entities) {
      if (isSnapshotCollectionMarker(entity)) {
        marker = entity;
        break;
      }
    }
    if (marker == null) {
      return const SnapshotRead(
        presence: SnapshotPresence.missing,
        error: SnapshotUserMessages.openSiteRequestsOnce,
      );
    }
    if (isSnapshotPermissionRevoked(marker)) {
      return const SnapshotRead(
        presence: SnapshotPresence.permissionDenied,
        error: SnapshotUserMessages.permissionRevoked,
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
      if (isSnapshotCollectionMarker(entity) ||
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
