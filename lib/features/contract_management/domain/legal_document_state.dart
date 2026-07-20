import '../data/legal_document_model.dart';

class LegalDocumentState {
  const LegalDocumentState({
    this.isLoading = false,
    this.projectId,
    this.documents = const [],
    this.error,
  });

  final bool isLoading;
  final int? projectId;
  final List<LegalDocumentModel> documents;
  final String? error;

  LegalDocumentState copyWith({
    bool? isLoading,
    Object? projectId = _projectId,
    List<LegalDocumentModel>? documents,
    Object? error = _error,
  }) => LegalDocumentState(
    isLoading: isLoading ?? this.isLoading,
    projectId: identical(projectId, _projectId) ? this.projectId : projectId as int?,
    documents: documents ?? this.documents,
    error: identical(error, _error) ? this.error : error as String?,
  );
}

const _projectId = Object();
const _error = Object();
