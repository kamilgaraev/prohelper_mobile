import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
import '../../../core/error/user_message.dart';
import '../data/legal_document_model.dart';
import '../data/legal_document_repository.dart';
import '../data/legal_document_snapshot.dart';
import 'legal_document_state.dart';

class LegalDocumentNotifier extends StateNotifier<LegalDocumentState> {
  LegalDocumentNotifier(
    this._repository, {
    LegalDocumentCacheIdentity? identity,
  }) : _identity = identity,
       super(const LegalDocumentState());
  final LegalDocumentRepository _repository;
  LegalDocumentCacheIdentity? _identity;
  CancelToken? _listCancelToken;
  Future<void>? _activeLoad;
  int _generation = 0;

  void syncProject(int? projectId, {LegalDocumentCacheIdentity? identity}) {
    final nextIdentity = identity ?? _identity;
    final nextKey = nextIdentity?.key(projectId ?? 0, 'list');
    if (state.projectId != projectId || state.identityKey != nextKey) {
      _generation++;
      _listCancelToken?.cancel('legal_document_context_changed');
      _identity = nextIdentity;
      state = state.copyWith(
        projectId: projectId,
        identityKey: nextKey,
        documents: const [],
        error: null,
        isPartial: false,
        isFromCache: false,
      );
    }
  }

  Future<void> load() {
    final active = _activeLoad;
    if (active != null) return active;
    final future = _performLoad();
    _activeLoad = future;
    return future.whenComplete(() {
      if (identical(_activeLoad, future)) _activeLoad = null;
    });
  }

  Future<void> _performLoad() async {
    final projectId = state.projectId;
    if (projectId == null) return;
    final generation = _generation;
    final identity = _identity;
    final cancelToken = CancelToken();
    _listCancelToken = cancelToken;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.fetchDocumentList(
        projectId: projectId,
        identity: identity,
        cancelToken: cancelToken,
        isCurrent:
            () =>
                _generation == generation &&
                state.projectId == projectId &&
                _identity?.key(projectId, 'list') ==
                    identity?.key(projectId, 'list'),
      );
      if (_generation != generation || state.projectId != projectId) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        documents: result.documents,
        error: result.error,
        isPartial: result.isPartial,
        isFromCache: result.isFromCache,
      );
    } catch (error) {
      if (_generation != generation ||
          state.projectId != projectId ||
          (error is DioException && CancelToken.isCancel(error))) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: UserMessage.fromError(error),
      );
    } finally {
      if (identical(_listCancelToken, cancelToken)) _listCancelToken = null;
    }
  }

  Future<LegalDocumentModel> detail(int id) {
    final projectId = state.projectId;
    if (projectId == null) throw StateError('legal_document_project_required');
    final generation = _generation;
    final identity = _identity;
    return _repository.fetchDocument(
      id,
      projectId: projectId,
      identity: identity,
      isCurrent:
          () =>
              _generation == generation &&
              state.projectId == projectId &&
              _identity?.key(projectId, 'list') ==
                  identity?.key(projectId, 'list'),
    );
  }

  Future<LegalDocumentModel> action({
    required int id,
    required LegalDocumentAction action,
    String? comment,
    String? reason,
  }) async {
    final document = await _repository.performAction(
      documentId: id,
      action: action,
      comment: comment,
      reason: reason,
    );
    await load();
    return document;
  }

  Future<Uri> versionUrl({
    required int documentId,
    required int versionId,
    required String purpose,
  }) {
    return _repository.fetchVersionUrl(
      documentId: documentId,
      versionId: versionId,
      purpose: purpose,
    );
  }

  Future<String> saveVersionForOffline({
    required int documentId,
    required LegalDocumentVersion version,
  }) {
    return _repository.saveVersionForOffline(
      documentId: documentId,
      version: version,
    );
  }

  Future<bool> isVersionSaved({
    required int documentId,
    required int versionId,
  }) {
    return _repository.isVersionSaved(
      documentId: documentId,
      versionId: versionId,
    );
  }

  Future<void> deleteSavedVersion({
    required int documentId,
    required int versionId,
  }) {
    return _repository.deleteSavedVersion(
      documentId: documentId,
      versionId: versionId,
    );
  }

  Future<String> openSavedVersion({
    required int documentId,
    required int versionId,
    String? fileName,
  }) {
    return _repository.openSavedVersion(
      documentId: documentId,
      versionId: versionId,
      fileName: fileName,
    );
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
    await _repository.uploadPaperOriginal(
      documentId: documentId,
      signatureRequestId: signatureRequestId,
      filePath: filePath,
      signedAt: signedAt,
      documentLockVersion: documentLockVersion,
      idempotencyKey: idempotencyKey,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    await load();
  }
}

final legalDocumentProvider =
    StateNotifierProvider<LegalDocumentNotifier, LegalDocumentState>((ref) {
      final authState = ref.watch(authProvider);
      final repository = ref.read(legalDocumentRepositoryProvider);
      ref.listen<AuthState>(authProvider, (previous, next) {
        final previousIdentity =
            previous is AuthAuthenticated ? previous.sessionIdentity : null;
        final nextIdentity =
            next is AuthAuthenticated ? next.sessionIdentity : null;
        if (previousIdentity != null && previousIdentity != nextIdentity) {
          unawaited(
            repository.clearSnapshotScope(
              LegalDocumentCacheIdentity.fromAuth(previousIdentity),
            ),
          );
        }
      });
      final identity =
          authState is AuthAuthenticated
              ? authState.sessionIdentity == null
                  ? null
                  : LegalDocumentCacheIdentity.fromAuth(
                    authState.sessionIdentity!,
                  )
              : null;
      return LegalDocumentNotifier(repository, identity: identity);
    });
