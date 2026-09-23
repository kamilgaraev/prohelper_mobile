import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../data/legal_document_model.dart';
import '../data/legal_document_repository.dart';
import 'legal_document_state.dart';

class LegalDocumentNotifier extends StateNotifier<LegalDocumentState> {
  LegalDocumentNotifier(this._repository) : super(const LegalDocumentState());
  final LegalDocumentRepository _repository;

  void syncProject(int? projectId) {
    if (state.projectId != projectId) {
      state = state.copyWith(
        projectId: projectId,
        documents: const [],
        error: null,
      );
    }
  }

  Future<void> load() async {
    final projectId = state.projectId;
    if (projectId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final documents = await _repository.fetchDocuments(projectId: projectId);
      if (state.projectId != projectId) {
        return;
      }
      state = state.copyWith(isLoading: false, documents: documents);
    } catch (error) {
      if (state.projectId != projectId) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: UserMessage.fromError(error),
      );
    }
  }

  Future<LegalDocumentModel> detail(int id) => _repository.fetchDocument(id);

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
      return LegalDocumentNotifier(ref.read(legalDocumentRepositoryProvider));
    });
