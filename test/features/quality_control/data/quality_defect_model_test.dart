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
      'project': {'id': 3, 'name': 'Tower'},
      'assigned_user': {'id': 9, 'name': 'Foreman'},
      'workflow_summary': {
        'status': 'ready_for_review',
        'available_actions': ['verify', 'reject'],
        'problem_flags': [
          {
            'code': 'verification_required',
            'severity': 'warning',
            'message': 'Needs acceptance',
          },
        ],
        'meta': {'overdue': false},
      },
      'photos': [
        {
          'id': 4,
          'type': 'after',
          'url': 'org-3/quality-control/defects/7/result.jpg',
          'preview_url': 'https://cdn.example.test/qc-after.jpg',
          'caption': 'Result photo',
          'created_at': '2026-05-22T10:00:00Z',
        },
      ],
      'status_history': [
        {
          'id': 12,
          'from_status': 'in_progress',
          'to_status': 'ready_for_review',
          'comment': 'QA_RESOLVE_CI37',
          'changed_at': '2026-05-22T12:00:00Z',
        },
        {
          'id': 10,
          'from_status': null,
          'to_status': 'open',
          'comment': 'Создано',
          'changed_at': '2026-05-22T10:00:00Z',
        },
        {
          'id': 11,
          'from_status': 'open',
          'to_status': 'in_progress',
          'comment': 'QA_START_CI37',
          'changed_at': '2026-05-22T11:00:00Z',
        },
        {
          'id': 14,
          'from_status': 'ready_for_review',
          'to_status': 'resolved',
          'comment': 'QA_REVIEW_CI37',
          'changed_at': '2026-05-22T13:00:00Z',
        },
      ],
      'problem_flags': [
        {
          'code': 'verification_required',
          'severity': 'warning',
          'message': 'Needs acceptance',
        },
      ],
      'available_actions': ['verify', 'reject'],
    });

    expect(defect.serverId, 7);
    expect(defect.projectName, 'Tower');
    expect(defect.assignedUserName, 'Foreman');
    expect(defect.problemFlags.single.code, 'verification_required');
    expect(defect.problemFlags.single.message, 'Needs acceptance');
    expect(defect.availableActions, ['verify', 'reject']);
    expect(defect.inspectionRequired, isTrue);
    expect(
      defect.photos.single.url,
      'org-3/quality-control/defects/7/result.jpg',
    );
    expect(
      defect.photos.single.previewUrl,
      'https://cdn.example.test/qc-after.jpg',
    );
    expect(
      defect.photos.single.displayUrl,
      'https://cdn.example.test/qc-after.jpg',
    );
    expect(defect.statusHistory.map((entry) => entry.id), [10, 11, 12, 14]);
    expect(defect.statusHistory.map((entry) => entry.comment), [
      'Создано',
      'QA_START_CI37',
      'QA_RESOLVE_CI37',
      'QA_REVIEW_CI37',
    ]);
  });

  test('orders equal or invalid history timestamps deterministically', () {
    final defect = QualityDefectModel.fromJson({
      'id': 8,
      'defect_number': 'QD-202605-0008',
      'title': 'History order',
      'severity': 'minor',
      'status': 'open',
      'available_actions': [],
      'inspection_required': false,
      'photos': [],
      'problem_flags': [],
      'workflow_summary': {
        'status': 'open',
        'available_actions': [],
        'problem_flags': [],
      },
      'status_history': [
        {'id': 9, 'to_status': 'open', 'changed_at': 'not-a-date'},
        {'id': 4, 'to_status': 'open', 'changed_at': '2026-05-22T10:00:00Z'},
        {'id': 3, 'to_status': 'open', 'changed_at': '2026-05-22T10:00:00Z'},
        {'id': 7, 'to_status': 'open', 'changed_at': null},
      ],
    });

    expect(defect.statusHistory.map((entry) => entry.id), [3, 4, 7, 9]);
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
