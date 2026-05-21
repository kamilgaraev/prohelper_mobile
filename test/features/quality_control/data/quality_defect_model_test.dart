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
      'photos': [
        {
          'id': 4,
          'type': 'after',
          'url': 'https://cdn.example.test/qc-after.jpg',
          'caption': 'Result photo',
          'created_at': '2026-05-22T10:00:00Z',
        },
      ],
      'status_history': [
        {
          'id': 5,
          'from_status': 'in_progress',
          'to_status': 'ready_for_review',
          'comment': 'Fixed',
          'changed_at': '2026-05-22T11:00:00Z',
        },
      ],
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
    expect(defect.photos.single.url, 'https://cdn.example.test/qc-after.jpg');
    expect(defect.statusHistory.single.comment, 'Fixed');
  });

  test('rejects defect payload without explicit severity', () {
    expect(
      () => QualityDefectModel.fromJson({
        'id': 7,
        'defect_number': 'QD-202605-0007',
        'title': 'Damaged coating',
        'status': 'open',
        'inspection_required': true,
      }),
      throwsFormatException,
    );
  });
}
