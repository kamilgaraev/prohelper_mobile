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
      state = state.copyWith(projectId: projectId, documents: const [], error: null);
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
      state = state.copyWith(isLoading: false, error: UserMessage.fromError(error));
    }
  }

  Future<LegalDocumentModel> detail(int id) => _repository.fetchDocument(id);

  Future<LegalDocumentModel> action({required int id, required LegalDocumentAction action, String? comment, String? reason}) async {
    final document = await _repository.performAction(documentId: id, action: action, comment: comment, reason: reason);
    await load();
    return document;
  }
}

final legalDocumentProvider = StateNotifierProvider<LegalDocumentNotifier, LegalDocumentState>((ref) {
  return LegalDocumentNotifier(ref.read(legalDocumentRepositoryProvider));
});
