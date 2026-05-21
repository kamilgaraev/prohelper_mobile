import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_model.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/domain/handover_acceptance_provider.dart';

class _FakeHandoverAcceptanceRepository extends HandoverAcceptanceRepository {
  _FakeHandoverAcceptanceRepository() : super(Dio());

  int? loadedProjectId;
  int? createdFindingSessionId;
  int? resolvedFindingId;
  int? readyScopeId;

  @override
  Future<List<AcceptanceScopeModel>> fetchScopes({int? projectId}) async {
    loadedProjectId = projectId;
    return [_scope];
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
}

const _finding = AcceptanceFindingModel(
  id: 31,
  sessionId: 21,
  title: 'Скол плитки',
  severity: 'major',
  status: 'open',
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
  sessions: [
    AcceptanceSessionModel(id: 21, status: 'planned', findings: [_finding]),
  ],
  findings: [_finding],
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

  test('после действий обновляет зоны приемки', () async {
    final repository = _FakeHandoverAcceptanceRepository();
    final notifier = HandoverAcceptanceNotifier(repository)..syncProject(15);

    await notifier.createFinding(21, {'title': 'Скол плитки'});
    await notifier.resolveFinding(31, resolutionComment: 'Исправлено');
    await notifier.readyForReinspection(10);

    expect(repository.createdFindingSessionId, 21);
    expect(repository.resolvedFindingId, 31);
    expect(repository.readyScopeId, 10);
    expect(notifier.state.scopes, hasLength(1));
  });
}
