import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_model.dart';

void main() {
  test('parses handover acceptance workflow from backend payload', () {
    final scope = AcceptanceScopeModel.fromJson({
      'id': 10,
      'project_id': 9,
      'title': 'Секция А / этаж 2',
      'description': 'Чистовая приемка',
      'status': 'findings_open',
      'project': {'id': 9, 'name': 'ЖК Север'},
      'location': {'id': 7, 'name': 'Этаж 2', 'path': 'Секция А / этаж 2'},
      'workflow_summary': {
        'status': 'findings_open',
        'available_actions': ['resolve_findings', 'ready_for_reinspection'],
        'problem_flags': [
          {
            'key': 'open_findings',
            'severity': 'warning',
            'label': 'Есть открытые замечания',
            'count': 1,
          },
        ],
      },
      'checklists': [
        {
          'id': 12,
          'acceptance_scope_id': 10,
          'title': 'Чек-лист квартиры',
          'status': 'active',
          'items': [
            {
              'id': 13,
              'title': 'Окна проверены',
              'is_required': true,
              'status': 'pending',
              'available_actions': ['accept', 'reject'],
            },
          ],
        },
      ],
      'sessions': [
        {
          'id': 21,
          'status': 'planned',
          'findings': [
            {
              'id': 31,
              'acceptance_session_id': 21,
              'quality_defect_id': 55,
              'title': 'Скол плитки',
              'severity': 'major',
              'status': 'open',
            },
          ],
        },
      ],
      'findings': [
        {
          'id': 31,
          'acceptance_session_id': 21,
          'quality_defect_id': 55,
          'title': 'Скол плитки',
          'severity': 'major',
          'status': 'open',
        },
      ],
      'handover_package': {
        'id': 40,
        'title': 'Комплект передачи',
        'status': 'draft',
        'documents': [
          {
            'id': 41,
            'title': 'Исполнительная документация',
            'document_type': 'executive_document',
            'is_required': true,
            'status': 'draft',
            'available_actions': ['upload'],
          },
          {
            'id': 42,
            'title': 'Фотофиксация',
            'document_type': 'photo_report',
            'is_required': true,
            'status': 'approved',
            'external_url': 'https://storage.example/photo.pdf',
            'available_actions': [],
          },
        ],
      },
    });

    expect(scope.project?.name, 'ЖК Север');
    expect(scope.locationLabel, 'Секция А / этаж 2');
    expect(
      scope.workflowSummary.availableActions,
      contains('ready_for_reinspection'),
    );
    expect(scope.workflowSummary.problemFlags.single.count, 1);
    expect(scope.checklists.single.items.single.availableActions, [
      'accept',
      'reject',
    ]);
    expect(scope.checklists.single.requiredItems, 1);
    expect(scope.sessions.single.findings.single.qualityDefectId, 55);
    expect(scope.openFindings, 1);
    expect(scope.handoverPackage?.requiredDocuments, 2);
    expect(scope.handoverPackage?.approvedRequiredDocuments, 1);
    expect(scope.handoverPackage?.documents.first.availableActions, ['upload']);
    expect(
      scope.handoverPackage?.documents.last.externalUrl,
      'https://storage.example/photo.pdf',
    );
  });

  test('reads new readiness blockers with object targets', () {
    final scope = AcceptanceScopeModel.fromJson({
      'id': 10,
      'project_id': 9,
      'title': 'Секция А / этаж 2',
      'status': 'in_progress',
      'workflow_summary': {
        'status': 'in_progress',
        'available_actions': ['create_finding'],
        'problem_flags': [
          {
            'code': 'open_findings',
            'severity': 'warning',
            'message': 'Есть открытые замечания',
          },
        ],
        'readiness': {
          'ready': false,
          'blockers': [
            {
              'code': 'quantity_source_changed',
              'requirement_id': 'req-9',
              'scope_id': 10,
              'stage': 'technical_acceptance',
              'message': 'Нет протокола для участка А',
              'target': {'type': 'acceptance_scope', 'id': 10},
            },
          ],
        },
      },
      'checklists': [],
      'sessions': [],
      'findings': [],
    });

    expect(scope.workflowSummary.readinessReady, isFalse);
    expect(
      scope.workflowSummary.readinessBlockers.single.message,
      'Нет протокола для участка А',
    );
    expect(scope.workflowSummary.availableActions, isNot(contains('accept')));
    expect(scope.workflowSummary.problemFlags.single.count, 0);
  });

  test('reads an unknown scope status without failing', () {
    final scope = AcceptanceScopeModel.fromJson({
      'id': 10,
      'project_id': 9,
      'title': 'Секция А / этаж 2',
      'status': 'awaiting_customer',
      'workflow_summary': {
        'status': 'awaiting_customer',
        'available_actions': ['view'],
        'problem_flags': [],
      },
      'checklists': [],
      'sessions': [],
      'findings': [],
    });

    expect(scope.status, 'awaiting_customer');
    expect(scope.workflowSummary.status, 'awaiting_customer');
  });

  test('rejects scope payload without workflow summary', () {
    expect(
      () => AcceptanceScopeModel.fromJson({
        'id': 10,
        'project_id': 9,
        'title': 'Секция А / этаж 2',
        'status': 'findings_open',
      }),
      throwsFormatException,
    );
  });
}
