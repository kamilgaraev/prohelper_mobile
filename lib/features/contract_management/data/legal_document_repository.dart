import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/storage/isar_service.dart';
import '../../../core/storage/encrypted_local_file_cache.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../auth/domain/auth_provider.dart';
import 'legal_document_model.dart';
import 'legal_document_snapshot.dart';

class LegalDocumentListResult {
  const LegalDocumentListResult({
    required this.documents,
    required this.isPartial,
    required this.isFromCache,
    this.error,
  });

  final List<LegalDocumentModel> documents;
  final bool isPartial;
  final bool isFromCache;
  final String? error;
}

class LegalDocumentListSnapshotData {
  const LegalDocumentListSnapshotData({
    required this.rawDocuments,
    required this.syncMaxId,
    required this.isComplete,
    this.nextCursor,
  });

  final List<Map<String, dynamic>> rawDocuments;
  final int syncMaxId;
  final int? nextCursor;
  final bool isComplete;
}

typedef LegalDocumentListSnapshotReader =
    Future<LegalDocumentListSnapshotData?> Function(
      int projectId,
      LegalDocumentCacheIdentity identity,
      String kind,
    );
typedef LegalDocumentListSnapshotWriter =
    Future<void> Function(
      int projectId,
      LegalDocumentCacheIdentity identity,
      String kind,
      List<Map<String, dynamic>> documents,
      int syncMaxId,
      int? nextCursor,
      bool isComplete,
      bool clearPartial,
    );

class _LegalDocumentPage {
  const _LegalDocumentPage(
    this.items,
    this.nextCursor,
    this.syncMaxId,
    this.hasMore,
  );
  final List<Map<String, dynamic>> items;
  final int? nextCursor;
  final int? syncMaxId;
  final bool hasMore;
}

class _StoredLegalList {
  const _StoredLegalList({
    required this.rawDocuments,
    required this.documents,
    required this.syncMaxId,
  });
  final List<Map<String, dynamic>> rawDocuments;
  final List<LegalDocumentModel> documents;
  final int syncMaxId;
}

_StoredLegalList _storedList(LegalDocumentListSnapshotData snapshot) =>
    _StoredLegalList(
      rawDocuments: snapshot.rawDocuments,
      documents: snapshot.rawDocuments
          .map(LegalDocumentModel.fromJson)
          .toList(growable: false),
      syncMaxId: snapshot.syncMaxId,
    );

class _PartialLegalList {
  const _PartialLegalList({
    required this.rawDocuments,
    required this.syncMaxId,
    required this.nextCursor,
  });
  final List<Map<String, dynamic>> rawDocuments;
  final int syncMaxId;
  final int nextCursor;
}

typedef LegalDocumentSnapshotReader =
    Future<LegalDocumentModel?> Function(
      int projectId,
      int documentId,
      LegalDocumentCacheIdentity identity,
    );
typedef LegalDocumentSnapshotWriter =
    Future<void> Function(
      int projectId,
      int documentId,
      LegalDocumentCacheIdentity identity,
      Map<String, dynamic> payload,
    );
typedef LegalDocumentSnapshotDeleter =
    Future<void> Function(
      int projectId,
      int documentId,
      LegalDocumentCacheIdentity identity,
    );

_LegalDocumentPage _legalDocumentPage(dynamic responseData) {
  final root =
      responseData is Map
          ? Map<String, dynamic>.from(responseData)
          : const <String, dynamic>{};
  final payload = root['data'];
  final payloadMap =
      payload is Map
          ? Map<String, dynamic>.from(payload)
          : const <String, dynamic>{};
  final rawItems =
      payloadMap['data'] is List
          ? payloadMap['data'] as List
          : payloadMap['documents'] is List
          ? payloadMap['documents'] as List
          : payload is List
          ? payload
          : const <dynamic>[];
  final meta =
      root['meta'] is Map
          ? Map<String, dynamic>.from(root['meta'] as Map)
          : payloadMap['meta'] is Map
          ? Map<String, dynamic>.from(payloadMap['meta'] as Map)
          : const <String, dynamic>{};
  final items = rawItems
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
  final nextCursor = _nullableIntValue(meta['next_cursor']);
  final lastPage = _intValue(meta['last_page']);
  final currentPage = _intValue(meta['current_page'], fallback: 1);
  final hasMore =
      meta['has_more'] is bool
          ? meta['has_more'] == true
          : lastPage > 0 && currentPage < lastPage;
  return _LegalDocumentPage(
    items,
    nextCursor,
    _nullableIntValue(meta['sync_max_id']),
    hasMore,
  );
}

int _intValue(Object? value, {int fallback = 0}) =>
    value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? fallback;

int? _nullableIntValue(Object? value) =>
    value == null ? null : _intValue(value);

final legalDocumentRepositoryProvider = Provider<LegalDocumentRepository>((
  ref,
) {
  return LegalDocumentRepository(
    ref.read(dioProvider),
    isar: ref.read(isarProvider.future),
    syncQueueService: () => ref.read(syncQueueServiceProvider.future),
    currentOwnerIdentity: () {
      final state = ref.read(authProvider);
      final identity =
          state is AuthAuthenticated ? state.sessionIdentity : null;
      if (identity == null) return null;
      return '${identity.userId}:${identity.organizationId ?? 0}:${identity.sessionId}';
    },
    fileCache: ref.read(encryptedLocalFileCacheProvider),
  );
});

bool shouldUseOfflineVersionAfterStatus(int? statusCode) =>
    statusCode == null || statusCode == 408 || statusCode >= 500;

class LegalDocumentRepository {
  LegalDocumentRepository(
    this._dio, {
    Future<Isar>? isar,
    Future<SyncQueueService> Function()? syncQueueService,
    String? Function()? currentOwnerIdentity,
    EncryptedLocalFileCache? fileCache,
    LegalDocumentSnapshotReader? snapshotReader,
    LegalDocumentSnapshotWriter? snapshotWriter,
    LegalDocumentSnapshotDeleter? snapshotDeleter,
    LegalDocumentListSnapshotReader? listSnapshotReader,
    LegalDocumentListSnapshotWriter? listSnapshotWriter,
  }) : _isar = isar,
       _snapshotReader = snapshotReader,
       _snapshotWriter = snapshotWriter,
       _snapshotDeleter = snapshotDeleter,
       _syncQueueService = syncQueueService,
       _currentOwnerIdentity = currentOwnerIdentity,
       _fileCache = fileCache,
       _listSnapshotReader = listSnapshotReader,
       _listSnapshotWriter = listSnapshotWriter;

  final Dio _dio;
  final Future<Isar>? _isar;
  final LegalDocumentSnapshotReader? _snapshotReader;
  final LegalDocumentSnapshotWriter? _snapshotWriter;
  final LegalDocumentSnapshotDeleter? _snapshotDeleter;
  final Future<SyncQueueService> Function()? _syncQueueService;
  final String? Function()? _currentOwnerIdentity;
  final EncryptedLocalFileCache? _fileCache;
  final LegalDocumentListSnapshotReader? _listSnapshotReader;
  final LegalDocumentListSnapshotWriter? _listSnapshotWriter;

  Future<LegalDocumentListResult> fetchDocumentList({
    required int projectId,
    LegalDocumentCacheIdentity? identity,
    CancelToken? cancelToken,
    bool Function()? isCurrent,
  }) async {
    final cached = await _readListSnapshot(projectId, identity);
    final pending = await _readPartialSnapshot(projectId, identity);
    final oldDocuments = cached?.documents ?? const <LegalDocumentModel>[];
    final cachedMaxId = pending?.nextCursor ?? 0;
    final updates = <int, Map<String, dynamic>>{
      for (final item
          in pending?.rawDocuments ?? const <Map<String, dynamic>>[])
        _intValue(item['id']): item,
    };
    var cursor = cachedMaxId;
    int? syncMaxId = pending?.syncMaxId;

    try {
      var hasMore = true;
      while (hasMore) {
        final response = await _dio.get(
          '/legal-archive/documents',
          queryParameters: {
            'project_id': projectId,
            'per_page': 50,
            'sync_after_id': cursor,
            if (syncMaxId != null) 'sync_max_id': syncMaxId,
          },
          cancelToken: cancelToken,
        );
        if (isCurrent != null && !isCurrent()) {
          throw DioException(
            requestOptions: response.requestOptions,
            type: DioExceptionType.cancel,
          );
        }
        final page = _legalDocumentPage(response.data);
        for (final item in page.items) {
          final id = _intValue(item['id']);
          if (id > 0) updates[id] = item;
        }
        syncMaxId ??= page.syncMaxId;
        final nextCursor = page.nextCursor;
        hasMore = page.hasMore;
        if (hasMore && (nextCursor == null || nextCursor <= cursor)) {
          throw const FormatException('legal_document_cursor_did_not_advance');
        }
        if (nextCursor != null) cursor = nextCursor;
        if (page.items.isEmpty && hasMore) {
          throw const FormatException('legal_document_empty_page_with_more');
        }
        if (hasMore) {
          if (isCurrent != null && !isCurrent()) {
            throw DioException(
              requestOptions: response.requestOptions,
              type: DioExceptionType.cancel,
            );
          }
          await _writeListSnapshot(
            projectId,
            identity,
            updates.values.toList(growable: false),
            syncMaxId ?? 0,
            kind: 'partial',
            isComplete: false,
            nextCursor: cursor,
          );
          if (isCurrent != null && !isCurrent()) {
            await _deleteListSnapshots(projectId, identity);
            throw DioException(
              requestOptions: response.requestOptions,
              type: DioExceptionType.cancel,
            );
          }
        }
      }

      final rawDocuments =
          updates.values.toList()..sort(
            (left, right) =>
                _intValue(left['id']).compareTo(_intValue(right['id'])),
          );
      final documents = rawDocuments
          .map(LegalDocumentModel.fromJson)
          .toList(growable: false);
      if (isCurrent != null && !isCurrent()) {
        throw DioException(
          requestOptions: RequestOptions(path: '/legal-archive/documents'),
          type: DioExceptionType.cancel,
        );
      }
      final finalMaxId =
          syncMaxId ??
          (rawDocuments.isEmpty
              ? cachedMaxId
              : _intValue(rawDocuments.last['id']));
      await _writeListSnapshot(
        projectId,
        identity,
        rawDocuments,
        finalMaxId,
        clearPartial: true,
      );
      if (isCurrent != null && !isCurrent()) {
        await _deleteListSnapshots(projectId, identity);
        throw DioException(
          requestOptions: RequestOptions(path: '/legal-archive/documents'),
          type: DioExceptionType.cancel,
        );
      }
      return LegalDocumentListResult(
        documents: documents,
        isPartial: false,
        isFromCache: false,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      final statusCode = error.response?.statusCode;
      if (statusCode != null && statusCode < 500) {
        if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
          await _deleteListSnapshots(projectId, identity);
          if (statusCode == 401 || statusCode == 403) {
            await _clearIdentityAfterAccessDenied(identity);
          }
        }
        throw ApiException.fromDio(error);
      }
      final partialDocuments = updates.values
          .map(LegalDocumentModel.fromJson)
          .toList(growable: false);
      final visible = <int, LegalDocumentModel>{
        for (final item in oldDocuments) item.id: item,
        for (final item in partialDocuments) item.id: item,
      }.values.toList(growable: false);
      return LegalDocumentListResult(
        documents: visible,
        isPartial: true,
        isFromCache: oldDocuments.isNotEmpty,
        error: ApiException.fromDio(error).message,
      );
    } on FormatException catch (error) {
      final partialDocuments = updates.values
          .map(LegalDocumentModel.fromJson)
          .toList(growable: false);
      final visible = <int, LegalDocumentModel>{
        for (final item in oldDocuments) item.id: item,
        for (final item in partialDocuments) item.id: item,
      }.values.toList(growable: false);
      return LegalDocumentListResult(
        documents: visible,
        isPartial: true,
        isFromCache: oldDocuments.isNotEmpty,
        error: error.message,
      );
    }
  }

  Future<List<LegalDocumentModel>> fetchDocuments({
    required int projectId,
  }) async => (await fetchDocumentList(projectId: projectId)).documents;

  Future<LegalDocumentModel> fetchDocument(
    int id, {
    required int projectId,
    LegalDocumentCacheIdentity? identity,
    bool Function()? isCurrent,
  }) async {
    try {
      final response = await _dio.get('/legal-archive/documents/$id');
      if (isCurrent != null && !isCurrent()) {
        throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
        );
      }
      final payload = MobileApiResponse.dataMap(response.data);
      final document = LegalDocumentModel.fromJson(payload);
      await _writeDetailSnapshot(projectId, identity, id, payload);
      if (isCurrent != null && !isCurrent()) {
        await _deleteDetailSnapshot(projectId, identity, id);
        throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
        );
      }
      return document;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      final statusCode = error.response?.statusCode;
      if (statusCode == 403 || statusCode == 404) {
        await _deleteDetailSnapshot(projectId, identity, id);
        if (statusCode == 403) {
          await _clearIdentityAfterAccessDenied(identity);
        }
        throw ApiException.fromDio(error);
      }
      if (statusCode != null && statusCode < 500) {
        throw ApiException.fromDio(error);
      }
      final cached = await readDocumentSnapshot(
        projectId: projectId,
        documentId: id,
        identity: identity,
      );
      if (cached != null) return cached;
      throw ApiException.fromDio(error);
    }
  }

  Future<LegalDocumentModel?> readDocumentSnapshot({
    required int projectId,
    required int documentId,
    LegalDocumentCacheIdentity? identity,
  }) async {
    if (_snapshotReader != null && identity != null) {
      return _snapshotReader(projectId, documentId, identity);
    }
    final isar = await _isar;
    if (isar == null || identity == null || identity.organizationId == null) {
      return null;
    }
    final snapshot =
        await isar.legalDocumentSnapshots
            .filter()
            .cacheKeyEqualTo(identity.key(projectId, 'detail', documentId))
            .findFirst();
    return snapshot == null
        ? null
        : LegalDocumentModel.fromJson(snapshot.payload);
  }

  Future<void> saveDocumentSnapshot({
    required int projectId,
    required int documentId,
    required LegalDocumentCacheIdentity identity,
    required Map<String, dynamic> payload,
  }) => _writeDetailSnapshot(projectId, identity, documentId, payload);

  Future<void> clearSnapshotScope(LegalDocumentCacheIdentity identity) async {
    final isar = await _isar;
    if (isar == null || identity.organizationId == null) return;
    final snapshots =
        await isar.legalDocumentSnapshots
            .filter()
            .userIdEqualTo(identity.userId)
            .and()
            .organizationIdEqualTo(identity.organizationId!)
            .and()
            .sessionIdEqualTo(identity.sessionId)
            .findAll();
    await isar.writeTxn(() async {
      await isar.legalDocumentSnapshots.deleteAll(
        snapshots.map((snapshot) => snapshot.id).toList(growable: false),
      );
    });
  }

  Future<LegalDocumentListResult> readListSnapshot({
    required int projectId,
    required LegalDocumentCacheIdentity identity,
  }) async {
    final snapshot = await _readListSnapshot(projectId, identity);
    return LegalDocumentListResult(
      documents: snapshot?.documents ?? const <LegalDocumentModel>[],
      isPartial: false,
      isFromCache: true,
    );
  }

  Future<_StoredLegalList?> _readListSnapshot(
    int projectId,
    LegalDocumentCacheIdentity? identity,
  ) async {
    if (_listSnapshotReader != null && identity != null) {
      final snapshot = await _listSnapshotReader(projectId, identity, 'list');
      if (snapshot == null || !snapshot.isComplete) return null;
      return _storedList(snapshot);
    }
    final isar = await _isar;
    if (isar == null || identity == null || identity.organizationId == null) {
      return null;
    }
    final snapshot =
        await isar.legalDocumentSnapshots
            .filter()
            .cacheKeyEqualTo(identity.key(projectId, 'list'))
            .findFirst();
    if (snapshot == null || !snapshot.isComplete) return null;
    final payload = snapshot.payload;
    final raw =
        payload['documents'] is List
            ? (payload['documents'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
    return _StoredLegalList(
      rawDocuments: raw,
      documents: raw.map(LegalDocumentModel.fromJson).toList(growable: false),
      syncMaxId: _intValue(payload['sync_max_id']),
    );
  }

  Future<_PartialLegalList?> _readPartialSnapshot(
    int projectId,
    LegalDocumentCacheIdentity? identity,
  ) async {
    if (_listSnapshotReader != null && identity != null) {
      final snapshot = await _listSnapshotReader(
        projectId,
        identity,
        'partial',
      );
      if (snapshot == null || snapshot.isComplete) return null;
      return _PartialLegalList(
        rawDocuments: snapshot.rawDocuments,
        syncMaxId: snapshot.syncMaxId,
        nextCursor: snapshot.nextCursor ?? 0,
      );
    }
    final isar = await _isar;
    if (isar == null || identity == null || identity.organizationId == null) {
      return null;
    }
    final snapshot =
        await isar.legalDocumentSnapshots
            .filter()
            .cacheKeyEqualTo(identity.key(projectId, 'partial'))
            .findFirst();
    if (snapshot == null || snapshot.isComplete) return null;
    final payload = snapshot.payload;
    final raw =
        payload['documents'] is List
            ? (payload['documents'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
    return _PartialLegalList(
      rawDocuments: raw,
      syncMaxId: _intValue(payload['sync_max_id']),
      nextCursor: _intValue(payload['next_cursor']),
    );
  }

  Future<void> _writeListSnapshot(
    int projectId,
    LegalDocumentCacheIdentity? identity,
    List<Map<String, dynamic>> documents,
    int maxId, {
    String kind = 'list',
    bool isComplete = true,
    int? nextCursor,
    bool clearPartial = false,
  }) async {
    if (_listSnapshotWriter != null &&
        identity != null &&
        identity.organizationId != null) {
      await _listSnapshotWriter(
        projectId,
        identity,
        kind,
        documents,
        maxId,
        nextCursor,
        isComplete,
        clearPartial,
      );
      return;
    }
    final isar = await _isar;
    if (isar == null || identity == null || identity.organizationId == null) {
      return;
    }
    final snapshot =
        LegalDocumentSnapshot()
          ..cacheKey = identity.key(projectId, kind)
          ..userId = identity.userId
          ..organizationId = identity.organizationId!
          ..projectId = projectId
          ..sessionId = identity.sessionId
          ..kind = kind
          ..payloadJson = jsonEncode({
            'documents': documents,
            'sync_max_id': maxId,
            if (nextCursor != null) 'next_cursor': nextCursor,
          })
          ..isComplete = isComplete
          ..savedAt = DateTime.now().toUtc();
    await isar.writeTxn(() async {
      await isar.legalDocumentSnapshots.put(snapshot);
      if (clearPartial) {
        final partial =
            await isar.legalDocumentSnapshots
                .filter()
                .cacheKeyEqualTo(identity.key(projectId, 'partial'))
                .findFirst();
        if (partial != null) {
          await isar.legalDocumentSnapshots.delete(partial.id);
        }
      }
    });
  }

  Future<void> _writeDetailSnapshot(
    int projectId,
    LegalDocumentCacheIdentity? identity,
    int documentId,
    Map<String, dynamic> payload,
  ) async {
    if (_snapshotWriter != null &&
        identity != null &&
        identity.organizationId != null) {
      await _snapshotWriter(projectId, documentId, identity, payload);
      return;
    }
    final isar = await _isar;
    if (isar == null || identity == null || identity.organizationId == null) {
      return;
    }
    final snapshot =
        LegalDocumentSnapshot()
          ..cacheKey = identity.key(projectId, 'detail', documentId)
          ..userId = identity.userId
          ..organizationId = identity.organizationId!
          ..projectId = projectId
          ..sessionId = identity.sessionId
          ..kind = 'detail'
          ..documentId = documentId
          ..payloadJson = jsonEncode(payload)
          ..isComplete = true
          ..savedAt = DateTime.now().toUtc();
    await isar.writeTxn(() => isar.legalDocumentSnapshots.put(snapshot));
  }

  Future<void> _deleteDetailSnapshot(
    int projectId,
    LegalDocumentCacheIdentity? identity,
    int documentId,
  ) async {
    if (_snapshotDeleter != null && identity != null) {
      await _snapshotDeleter(projectId, documentId, identity);
      return;
    }
    final isar = await _isar;
    if (isar == null || identity == null || identity.organizationId == null) {
      return;
    }
    final snapshot =
        await isar.legalDocumentSnapshots
            .filter()
            .cacheKeyEqualTo(identity.key(projectId, 'detail', documentId))
            .findFirst();
    if (snapshot != null) {
      await isar.writeTxn(
        () => isar.legalDocumentSnapshots.delete(snapshot.id),
      );
    }
  }

  Future<void> _deleteListSnapshots(
    int projectId,
    LegalDocumentCacheIdentity? identity,
  ) async {
    final isar = await _isar;
    if (isar == null || identity == null || identity.organizationId == null) {
      return;
    }
    final list =
        await isar.legalDocumentSnapshots
            .filter()
            .cacheKeyEqualTo(identity.key(projectId, 'list'))
            .findFirst();
    final partial =
        await isar.legalDocumentSnapshots
            .filter()
            .cacheKeyEqualTo(identity.key(projectId, 'partial'))
            .findFirst();
    await isar.writeTxn(() async {
      if (list != null) await isar.legalDocumentSnapshots.delete(list.id);
      if (partial != null) await isar.legalDocumentSnapshots.delete(partial.id);
    });
  }

  Future<void> _clearIdentityAfterAccessDenied(
    LegalDocumentCacheIdentity? identity,
  ) async {
    if (identity == null) return;
    await clearSnapshotScope(identity);
    final scope =
        '${identity.userId}:${identity.organizationId ?? 0}:${identity.sessionId}';
    await _fileCache?.clearIdentity(scope);
    final queueProvider = _syncQueueService;
    if (queueProvider != null) {
      await (await queueProvider()).clearScope(scope);
    }
  }

  Future<LegalDocumentModel> performAction({
    required int documentId,
    required LegalDocumentAction action,
    String? comment,
    String? reason,
  }) async {
    final identityAtStart = _currentOwnerIdentity?.call();
    final idempotencyKey = _idempotencyKey();
    final payload = <String, dynamic>{
      'idempotency_key': idempotencyKey,
      'target_step_id': action.targetStepId,
      'instance_lock_version': action.expectedInstanceLockVersion,
      'step_lock_version': action.expectedStepLockVersion,
      if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
      if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
    };
    final endpoint =
        '/legal-archive/documents/$documentId/actions/${action.action}';
    try {
      final response = await _dio.post(
        endpoint,
        data: payload,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return LegalDocumentModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        if (identityAtStart == null ||
            identityAtStart.isEmpty ||
            _currentOwnerIdentity?.call() != identityAtStart) {
          throw StateError('Владелец данных изменился во время действия.');
        }
        final service = await _requireQueueService();
        if (_currentOwnerIdentity?.call() != identityAtStart) {
          throw StateError('Владелец данных изменился во время действия.');
        }
        final queued = await service.enqueue(
          SyncQueueDraft(
            moduleSlug: 'legal_archive',
            operationType: action.action,
            method: 'POST',
            endpoint: endpoint,
            payload: {
              ...payload,
              ..._queueIdentity(identityAtStart, documentId),
            },
          ),
        );
        throw SyncQueuedException(queueId: queued.id);
      }
      throw ApiException.fromDio(error);
    }
  }

  Future<Uri> fetchVersionUrl({
    required int documentId,
    required int versionId,
    required String purpose,
  }) async {
    if (purpose != 'preview' && purpose != 'download') {
      throw ArgumentError.value(purpose, 'purpose');
    }
    try {
      final response = await _dio.get(
        '/legal-archive/documents/$documentId/versions/$versionId/$purpose',
      );
      final url = MobileApiResponse.dataMap(response.data)['url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('legal_document_temporary_url_invalid');
      }

      return uri;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> uploadPaperOriginal({
    required int documentId,
    required int signatureRequestId,
    required String filePath,
    required DateTime signedAt,
    required int documentLockVersion,
    required String idempotencyKey,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final identity = _requireOwnerIdentity();
    final fileCache = _requireFileCache();
    final stagedPath = await fileCache.stageUpload(
      ownerIdentity: identity,
      signatureRequestId: signatureRequestId,
      idempotencyKey: idempotencyKey,
      sourcePath: filePath,
    );
    final context = 'upload:$signatureRequestId:$idempotencyKey';
    String? temporaryPath;
    try {
      temporaryPath = await fileCache.materialize(
        ownerIdentity: identity,
        encryptedPath: stagedPath,
        context: context,
      );
      await _dio.post(
        '/legal-archive/signature-requests/$signatureRequestId/upload-original',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            temporaryPath,
            filename: _fileName(filePath),
          ),
          'signed_at': signedAt.toUtc().toIso8601String(),
          'lock_version': documentLockVersion,
          'idempotency_key': idempotencyKey,
        }),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      await fileCache.deleteStagedUpload(stagedPath);
    } on DioException catch (error) {
      if (SyncQueueService.shouldQueueDioException(error)) {
        if (_currentOwnerIdentity?.call() != identity) {
          await fileCache.deleteStagedUpload(stagedPath);
          throw StateError('Владелец данных изменился во время загрузки.');
        }
        final service = await _requireQueueService();
        final queued = await service.enqueue(
          SyncQueueDraft(
            moduleSlug: 'legal_archive',
            operationType: 'upload_paper_original',
            method: 'POST',
            endpoint:
                '/legal-archive/signature-requests/$signatureRequestId/upload-original',
            payload: {
              'signed_at': signedAt.toUtc().toIso8601String(),
              'lock_version': documentLockVersion,
              'idempotency_key': idempotencyKey,
              ..._queueIdentity(identity, documentId),
            },
            attachments: [
              SyncAttachmentRef(
                field: 'file',
                path: stagedPath,
                filename: _fileName(filePath),
                encrypted: true,
                context: context,
              ),
            ],
          ),
        );
        throw SyncQueuedException(queueId: queued.id);
      }
      await fileCache.deleteStagedUpload(stagedPath);
      throw ApiException.fromDio(error);
    } finally {
      if (temporaryPath != null) {
        await fileCache.deleteStagedUpload(temporaryPath);
      }
    }
  }

  Future<String> saveVersionForOffline({
    required int documentId,
    required LegalDocumentVersion version,
  }) async {
    final identity = _requireOwnerIdentity();
    final cache = _requireFileCache();
    final url = await fetchVersionUrl(
      documentId: documentId,
      versionId: version.id,
      purpose: 'download',
    );
    final temporary = await _temporaryFile(version.fileName);
    try {
      final client = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 2),
          headers: const {'Accept': '*/*'},
        ),
      );
      try {
        await client.download(url.toString(), temporary.path);
      } finally {
        client.close(force: true);
      }
      if (version.contentHash != null &&
          RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(version.contentHash!)) {
        final actual = await sha256.bind(temporary.openRead()).first;
        if (actual.toString().toLowerCase() !=
            version.contentHash!.toLowerCase()) {
          throw const FormatException(
            'Не удалось проверить целостность файла.',
          );
        }
      }
      if (_currentOwnerIdentity?.call() != identity) {
        throw StateError('Владелец данных изменился во время загрузки.');
      }
      return cache.saveForOffline(
        ownerIdentity: identity,
        documentId: documentId,
        versionId: version.id,
        sourcePath: temporary.path,
      );
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<bool> isVersionSaved({
    required int documentId,
    required int versionId,
  }) => _requireFileCache().isSaved(
    ownerIdentity: _requireOwnerIdentity(),
    documentId: documentId,
    versionId: versionId,
  );

  Future<void> deleteSavedVersion({
    required int documentId,
    required int versionId,
  }) => _requireFileCache().deleteSavedVersion(
    ownerIdentity: _requireOwnerIdentity(),
    documentId: documentId,
    versionId: versionId,
  );

  Future<String> openSavedVersion({
    required int documentId,
    required int versionId,
    String? fileName,
  }) async {
    final identity = _requireOwnerIdentity();
    final cache = _requireFileCache();
    return cache.materialize(
      ownerIdentity: identity,
      encryptedPath: await cache.savedPath(
        ownerIdentity: identity,
        documentId: documentId,
        versionId: versionId,
      ),
      context: 'document:$documentId:$versionId',
      fileName: fileName,
    );
  }

  Future<File> _temporaryFile(String? filename) async {
    final root = await getTemporaryDirectory();
    final safeName = _fileName(filename ?? 'legal-document');
    return File(
      '${root.path}${Platform.pathSeparator}most-download-${DateTime.now().microsecondsSinceEpoch}-$safeName',
    );
  }

  Map<String, dynamic> _queueIdentity(String identity, int documentId) {
    final parts = identity.split(':');
    return {
      'queue_scope': identity,
      'queue_owner_identity': identity,
      'queue_document_id': documentId,
      'queue_user_id': parts.isNotEmpty ? int.tryParse(parts[0]) : null,
      'queue_organization_id': parts.length > 1 ? int.tryParse(parts[1]) : null,
      'queue_session_id': parts.length > 2 ? parts.sublist(2).join(':') : null,
    };
  }

  String _requireOwnerIdentity() {
    final identity = _currentOwnerIdentity?.call();
    if (identity == null || identity.isEmpty) {
      throw StateError('Действие требует активной пользовательской сессии.');
    }
    return identity;
  }

  Future<SyncQueueService> _requireQueueService() async {
    final service = _syncQueueService;
    if (service == null) throw StateError('Синхронизация не настроена.');
    return service();
  }

  EncryptedLocalFileCache _requireFileCache() {
    final cache = _fileCache;
    if (cache == null) throw StateError('Локальное хранилище недоступно.');
    return cache;
  }
}

String _idempotencyKey() {
  final suffix = DateTime.now().microsecondsSinceEpoch.toString();
  return '00000000-0000-4000-8000-${suffix.substring(suffix.length - 12)}';
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final segments = normalized.split('/');

  return segments.isEmpty || segments.last.isEmpty
      ? 'paper-original.jpg'
      : segments.last;
}
