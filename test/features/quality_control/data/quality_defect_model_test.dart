import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_defect_model.dart';

void main() {
  test('parses quality defect workflow fields from backend payload', () {
    final defect = QualityDefectModel.fromJson({
      'id': 7,
      'project_id': 3,
      'defect_number': 'QD-202605-0007',
      'title': 'Damaged coating',
      'severity': 'critical',
      'status': 'ready_for_review',
      'inspection_required': true,
      'location_name': 'Section A',
      'project': {'name': 'Tower'},
      'assigned_user': {'full_name': 'Foreman'},
      'problem_flags': [
        {'key': 'verification_required', 'label': 'Needs acceptance'},
      ],
      'available_actions': [
        {'key': 'verify', 'label': 'Accept'},
        {'key': 'reject', 'label': 'Return'},
      ],
    });

    expect(defect.serverId, 7);
    expect(defect.projectName, 'Tower');
    expect(defect.assignedUserName, 'Foreman');
    expect(defect.problemFlags.single.code, 'verification_required');
    expect(defect.problemFlags.single.message, 'Needs acceptance');
    expect(defect.availableActions, ['verify', 'reject']);
    expect(defect.inspectionRequired, isTrue);
  });
}
