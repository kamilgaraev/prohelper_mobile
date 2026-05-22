import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_model.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/domain/handover_acceptance_provider.dart';

class _FakeHandoverAcceptanceRepository extends HandoverAcceptanceRepository {
  _FakeHandoverAcceptanceRepository({this.permissionDenied = false})
    : super(Dio());

  final bool permissionDenied;

  int? loadedProjectId;
  String? loadedStatus;
  String? loadedPlannedFrom;
  String? loadedPlannedTo;
  int? loadedScopeId;
  int? reviewedChecklistItemId;
  int? uploadedDocumentId;
  String? uploadedDocumentPath;
  String? reviewedChecklistStatus;
  String? reviewedChecklistComment;
  int? createdFindingSessionId;
  int? resolvedFindingId;
  int? readyScopeId;
  int? startedScopeId;
  int? acceptedScopeId;
  int? handedOverScopeId;
  int? rejectedScopeId;
  int? reopenedScopeId;
  String? acceptedComment;
  String? rejectedReason;
  String? reopenedReason;

  @override
  Future<List<AcceptanceScopeModel>> fetchScopes({
    int? projectId,
    String? status,
    String? plannedFrom,
    String? plannedTo,
  }) async {
    if (permissionDenied) {
      throw const ApiException(
        'Недостаточно прав для просмотра приемки зон.',
        statusCode: 403,
      );
    }

    loadedProjectId = projectId;
    loadedStatus = status;
    loadedPlannedFrom = plannedFrom;
    loadedPlannedTo = plannedTo;
    return [_scope];
  }

  @override
  Future<AcceptanceScopeModel> fetchScope(int scopeId) async {
    loadedScopeId = scopeId;
    return _scope;
  }

  @override
  Future<AcceptanceChecklistModel> reviewChecklistItem(
    int itemId, {
    required String status,
    String? comment,
  }) async {
    reviewedChecklistItemId = itemId;
    reviewedChecklistStatus = status;
    reviewedChecklistComment = comment;
    return _checklist;
  }

  @override
  Future<HandoverPackageModel> uploadPackageDocument(
    int documentId, {
    required String filePath,
  }) async {
    uploadedDocumentId = documentId;
    uploadedDocumentPath = filePath;
    return _package;
  }

  @override
  Future<AcceptanceFindingModel> createFinding(
    int sessionId,
    Map<String, dynamic> data,
  ) async {
    createdFindingSessionId = sessionId;
    return _finding;
  }

  @override
  Future<AcceptanceFindingModel> resolveFinding(
    int findingId, {
    required String resolutionComment,
  }) async {
    resolvedFindingId = findingId;
    return _finding;
  }

  @override
  Future<AcceptanceScopeModel> readyForReinspection(int scopeId) async {
    readyScopeId = scopeId;
    return _scope;
  }

  @override
  Future<AcceptanceScopeModel> startScope(int scopeId) async {
    startedScopeId = scopeId;
    return _scope;
  }

  @override
  Future<AcceptanceScopeModel> acceptScope(
    int scopeId, {
    String? comment,
  }) async {
    acceptedScopeId = scopeId;
    acceptedComment = comment;
    return _scope;
  }

  @override
  Future<AcceptanceScopeModel> handoverScope(int scopeId) async {
    handedOverScopeId = scopeId;
    return _scope;
  }

  @override
  Future<AcceptanceScopeModel> rejectScope(
    int scopeId, {
    required String reason,
  }) async {
    rejectedScopeId = scopeId;
    rejectedReason = reason;
    return _scope;
  }

  @override
  Future<AcceptanceScopeModel> reopenScope(
    int scopeId, {
    required String reason,
  }) async {
    reopenedScopeId = scopeId;
    reopenedReason = reason;
    return _scope;
  }
}

const _finding = AcceptanceFindingModel(
  id: 31,
  sessionId: 21,
  title: 'Скол плитки',
  severity: 'major',
  status: 'open',
);

const _checklistItem = AcceptanceChecklistItemModel(
  id: 41,
  title: 'Окна проверены',
  required: true,
  status: 'pending',
  availableActions: ['accept', 'reject'],
);

const _checklist = AcceptanceChecklistModel(
  id: 40,
  scopeId: 10,
  title: 'Чек-лист квартиры',
  status: 'active',
  items: [_checklistItem],
);

const _package = HandoverPackageModel(
  id: 50,
  title: 'Комплект передачи',
  status: 'draft',
  documents: [
    HandoverPackageDocumentModel(
      id: 51,
      title: 'Фотофиксация',
      required: true,
      status: 'missing',
      documentType: 'photo_report',
      availableActions: ['upload'],
    ),
  ],
);

const _scope = AcceptanceScopeModel(
  id: 10,
  projectId: 15,
  title: 'Секция А',
  status: 'findings_open',
  workflowSummary: HandoverWorkflowSummary(
    status: 'findings_open',
    availableActions: ['resolve_findings', 'ready_for_reinspection'],
    problemFlags: [],
  ),
  plannedAcceptanceDate: '2026-06-10',
  checklists: [_checklist],
  sessions: [
    AcceptanceSessionModel(id: 21, status: 'planned', findings: [_finding]),
  ],
  findings: [_finding],
  handoverPackage: _package,
);

void main() {
  test('загружает зоны приемки по выбранному проекту', () async {
    final repository = _FakeHandoverAcceptanceRepository();
    final notifier = HandoverAcceptanceNotifier(repository);

    notifier.syncProject(15);
    await notifier.loadScopes();

    expect(repository.loadedProjectId, 15);
    expect(notifier.state.scopes.single.id, 10);
    expect(notifier.state.error, isNull);
  });

  test('передает фильтры приемки в репозиторий', () async {
    final repository = _FakeHandoverAcceptanceRepository();
    final notifier = HandoverAcceptanceNotifier(repository)..syncProject(15);

    await notifier.setStatusFilter('planned');
    await notifier.setPlannedFromFilter(DateTime(2026, 6, 1));
    await notifier.setPlannedToFilter(DateTime(2026, 6, 30));

    expect(repository.loadedProjectId, 15);
    expect(repository.loadedStatus, 'planned');
    expect(repository.loadedPlannedFrom, '2026-06-01');
    expect(repository.loadedPlannedTo, '2026-06-30');
  });

  test('загружает детали зоны и обновляет пункт чек-листа', () async {
    final repository = _FakeHandoverAcceptanceRepository();
    final notifier = HandoverAcceptanceNotifier(repository)..syncProject(15);

    await notifier.loadScopeDetail(10);
    await notifier.reviewChecklistItem(
      41,
      status: 'rejected',
      comment: 'Нужно заменить стеклопакет',
    );

    expect(repository.loadedScopeId, 10);
    expect(repository.reviewedChecklistItemId, 41);
    expect(repository.reviewedChecklistStatus, 'rejected');
    expect(repository.reviewedChecklistComment, 'Нужно заменить стеклопакет');
    expect(notifier.state.selectedScope?.id, 10);
  });

  test('загружает файл документа и обновляет детали зоны', () async {
    final repository = _FakeHandoverAcceptanceRepository();
    final notifier = HandoverAcceptanceNotifier(repository)..syncProject(15);

    await notifier.loadScopeDetail(10);
    await notifier.uploadPackageDocument(51, filePath: 'C:\\temp\\photo.jpg');

    expect(repository.uploadedDocumentId, 51);
    expect(repository.uploadedDocumentPath, 'C:\\temp\\photo.jpg');
    expect(repository.loadedScopeId, 10);
    expect(
      notifier.state.selectedScope?.handoverPackage?.documents.single.id,
      51,
    );
  });

  test('после действий обновляет зоны приемки', () async {
    final repository = _FakeHandoverAcceptanceRepository();
    final notifier = HandoverAcceptanceNotifier(repository)..syncProject(15);

    await notifier.createFinding(21, {'title': 'Скол плитки'});
    await notifier.resolveFinding(31, resolutionComment: 'Исправлено');
    await notifier.readyForReinspection(10);
    await notifier.startScope(10);
    await notifier.acceptScope(10, comment: 'Принято');
    await notifier.handoverScope(10);
    await notifier.rejectScope(10, reason: 'Есть замечания');
    await notifier.reopenScope(10, reason: 'Вернуть на проверку');

    expect(repository.createdFindingSessionId, 21);
    expect(repository.resolvedFindingId, 31);
    expect(repository.readyScopeId, 10);
    expect(repository.startedScopeId, 10);
    expect(repository.acceptedScopeId, 10);
    expect(repository.acceptedComment, 'Принято');
    expect(repository.handedOverScopeId, 10);
    expect(repository.rejectedScopeId, 10);
    expect(repository.rejectedReason, 'Есть замечания');
    expect(repository.reopenedScopeId, 10);
    expect(repository.reopenedReason, 'Вернуть на проверку');
    expect(notifier.state.scopes, hasLength(1));
  });

  test('фиксирует состояние недостаточных прав при загрузке', () async {
    final repository = _FakeHandoverAcceptanceRepository(
      permissionDenied: true,
    );
    final notifier = HandoverAcceptanceNotifier(repository)..syncProject(15);

    await notifier.loadScopes();

    expect(notifier.state.permissionDenied, isTrue);
    expect(
      notifier.state.error,
      'Недостаточно прав для просмотра приемки зон.',
    );
    expect(notifier.state.scopes, isEmpty);
  });
}
