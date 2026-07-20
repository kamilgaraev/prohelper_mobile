import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/contract_management/data/legal_document_model.dart';

void main() {
  test('normalizes workflow actions and optional legal document fields', () {
    final document = LegalDocumentModel.fromJson({
      'id': 44,
      'title': 'Договор подряда',
      'document_type_label': 'Договор',
      'status': 'active',
      'workflow_summary': {
        'status': 'in_progress',
        'available_action_details': [
          {'action': 'approve', 'label': 'Согласовать', 'enabled': true, 'blockers': []},
        ],
        'problem_flags': ['workflow_overdue'],
      },
      'current_version': {'id': 10, 'version_number': 2, 'content_hash': 'abc'},
      'versions': const [],
    });

    expect(document.workflow.actions.single.action, 'approve');
    expect(document.currentVersion?.contentHash, 'abc');
    expect(document.workflow.problemFlags, ['workflow_overdue']);
  });
}
