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
      'location': {
        'id': 7,
        'name': 'Этаж 2',
        'path': 'Секция А / этаж 2',
      },
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
            'is_required': true,
            'status': 'draft',
          },
          {
            'id': 42,
            'title': 'Фотофиксация',
            'is_required': true,
            'status': 'approved',
          },
        ],
      },
    });

    expect(scope.project?.name, 'ЖК Север');
    expect(scope.locationLabel, 'Секция А / этаж 2');
    expect(scope.workflowSummary.availableActions, contains('ready_for_reinspection'));
    expect(scope.workflowSummary.problemFlags.single.count, 1);
    expect(scope.sessions.single.findings.single.qualityDefectId, 55);
    expect(scope.openFindings, 1);
    expect(scope.handoverPackage?.requiredDocuments, 2);
    expect(scope.handoverPackage?.approvedRequiredDocuments, 1);
  });
}
