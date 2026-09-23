import '../data/legal_document_model.dart';

class LegalDocumentState {
  const LegalDocumentState({
    this.isLoading = false,
    this.projectId,
    this.identityKey,
    this.documents = const [],
    this.error,
    this.isPartial = false,
    this.isFromCache = false,
  });

  final bool isLoading;
  final int? projectId;
  final String? identityKey;
  final List<LegalDocumentModel> documents;
  final String? error;
  final bool isPartial;
  final bool isFromCache;

  LegalDocumentState copyWith({
    bool? isLoading,
    Object? projectId = _projectId,
    Object? identityKey = _identityKey,
    List<LegalDocumentModel>? documents,
    Object? error = _error,
    bool? isPartial,
    bool? isFromCache,
  }) => LegalDocumentState(
    isLoading: isLoading ?? this.isLoading,
    projectId:
        identical(projectId, _projectId) ? this.projectId : projectId as int?,
    identityKey:
        identical(identityKey, _identityKey)
            ? this.identityKey
            : identityKey as String?,
    documents: documents ?? this.documents,
    error: identical(error, _error) ? this.error : error as String?,
    isPartial: isPartial ?? this.isPartial,
    isFromCache: isFromCache ?? this.isFromCache,
  );
}

const _projectId = Object();
const _identityKey = Object();
const _error = Object();
