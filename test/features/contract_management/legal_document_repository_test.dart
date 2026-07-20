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
      'versions': [
        {
          'id': 10,
          'version_number': 2,
          'content_hash': 'abc',
          'processing_status': 'ready',
          'preview_available': true,
          'mime_type': 'application/pdf',
          'size_bytes': 2048,
        },
      ],
      'signature_requests': [
        {'id': 19, 'method': 'paper'},
      ],
      'lock_version': 4,
    });

    expect(document.workflow.actions.single.action, 'approve');
    expect(document.currentVersion?.contentHash, 'abc');
    expect(document.workflow.problemFlags, ['workflow_overdue']);
    expect(document.currentVersion?.previewAvailable, isTrue);
    expect(document.currentVersion?.sizeBytes, 2048);
    expect(document.signatureRequests.single.supportsPaperOriginal, isTrue);
    expect(document.lockVersion, 4);
  });
}
