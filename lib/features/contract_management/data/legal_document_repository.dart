import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import '../../../core/storage/encrypted_local_file_cache.dart';
import '../../../core/sync/sync_queue_draft.dart';
import '../../../core/sync/sync_queue_provider.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../auth/domain/auth_provider.dart';
import 'legal_document_model.dart';

final legalDocumentRepositoryProvider = Provider<LegalDocumentRepository>((
  ref,
) {
  return LegalDocumentRepository(
    ref.read(dioProvider),
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
    Future<SyncQueueService> Function()? syncQueueService,
    String? Function()? currentOwnerIdentity,
    EncryptedLocalFileCache? fileCache,
  }) : _syncQueueService = syncQueueService,
       _currentOwnerIdentity = currentOwnerIdentity,
       _fileCache = fileCache;

  final Dio _dio;
  final Future<SyncQueueService> Function()? _syncQueueService;
  final String? Function()? _currentOwnerIdentity;
  final EncryptedLocalFileCache? _fileCache;

  Future<List<LegalDocumentModel>> fetchDocuments({
    required int projectId,
  }) async {
    try {
      final response = await _dio.get(
        '/legal-archive/documents',
        queryParameters: {'project_id': projectId, 'per_page': 50},
      );
      final data = MobileApiResponse.dataMap(response.data);
      final records =
          data['data'] is List
              ? data['data'] as List
              : data['documents'] as List? ?? const [];
      return records
          .whereType<Map>()
          .map(
            (item) =>
                LegalDocumentModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<LegalDocumentModel> fetchDocument(int id) async {
    try {
      final response = await _dio.get('/legal-archive/documents/$id');
      return LegalDocumentModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<LegalDocumentModel> performAction({
    required int documentId,
    required LegalDocumentAction action,
    String? comment,
    String? reason,
  }) async {
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
        final identity = _requireOwnerIdentity();
        final service = await _requireQueueService();
        final request = <String, dynamic>{
          ...payload,
          ..._queueIdentity(identity, documentId),
        };
        final queued = await service.enqueue(
          SyncQueueDraft(
            moduleSlug: 'legal_archive',
            operationType: action.action,
            method: 'POST',
            endpoint: endpoint,
            payload: request,
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
        final queuePayload = <String, dynamic>{
          'signed_at': signedAt.toUtc().toIso8601String(),
          'lock_version': documentLockVersion,
          'idempotency_key': idempotencyKey,
          ..._queueIdentity(identity, documentId),
        };
        final service = await _requireQueueService();
        final queued = await service.enqueue(
          SyncQueueDraft(
            moduleSlug: 'legal_archive',
            operationType: 'upload_paper_original',
            method: 'POST',
            endpoint:
                '/legal-archive/signature-requests/$signatureRequestId/upload-original',
            payload: queuePayload,
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
    final fileCache = _requireFileCache();
    final url = await fetchVersionUrl(
      documentId: documentId,
      versionId: version.id,
      purpose: 'download',
    );
    final temporary = await _temporaryFile(version.fileName);
    try {
      final signedFileClient = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 2),
          headers: const {'Accept': '*/*'},
        ),
      );
      try {
        await signedFileClient.download(url.toString(), temporary.path);
      } finally {
        signedFileClient.close(force: true);
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
      return fileCache.saveForOffline(
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
  }) {
    return _requireFileCache().isSaved(
      ownerIdentity: _requireOwnerIdentity(),
      documentId: documentId,
      versionId: versionId,
    );
  }

  Future<void> deleteSavedVersion({
    required int documentId,
    required int versionId,
  }) {
    return _requireFileCache().deleteSavedVersion(
      ownerIdentity: _requireOwnerIdentity(),
      documentId: documentId,
      versionId: versionId,
    );
  }

  Future<String> openSavedVersion({
    required int documentId,
    required int versionId,
    String? fileName,
  }) async {
    final identity = _requireOwnerIdentity();
    return _requireFileCache().materialize(
      ownerIdentity: identity,
      encryptedPath: await _requireFileCache().savedPath(
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
    final provider = _syncQueueService;
    if (provider == null) throw StateError('Синхронизация не настроена.');
    return provider();
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
