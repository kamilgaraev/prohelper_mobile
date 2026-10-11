import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/acts/data/act_model.dart';

void main() {
  test('explicit actual project wins over the contract project', () {
    final act = ActModel.fromJson({
      'id': 21,
      'project_id': 9,
      'project': {'id': 31},
      'contract': {'id': 7, 'project_id': 31},
    });
    expect(act.projectId, 9);
  });
  test('typed files and project scope do not guess capabilities', () {
    final act = ActModel.fromJson({
      'id': 21,
      'project': {'id': 9},
      'files': [
        {
          'id': 7,
          'name': 'КС-2.pdf',
          'mime_type': 'application/pdf',
          'size': 125,
        },
      ],
      'capabilities': {'can_view_files': true, 'can_field_confirm': false},
    });
    expect(act.projectId, 9);
    expect(act.files.single.id, 7);
    expect(act.files.single.name, 'КС-2.pdf');
    expect(act.canViewFiles, isTrue);
    expect(act.canFieldConfirm, isFalse);
    final legacy = ActModel.fromJson({'id': 22});
    expect(legacy.files, isEmpty);
    expect(legacy.canViewFiles, isFalse);
  });
  test('exposes field confirmation only from backend capability', () {
    final permitted = ActModel.fromJson({
      'id': 21,
      'capabilities': {'can_field_confirm': true},
    });
    final denied = ActModel.fromJson({
      'id': 22,
      'capabilities': {'can_field_confirm': false},
    });

    expect(permitted.canFieldConfirm, isTrue);
    expect(denied.canFieldConfirm, isFalse);
  });

  test(
    'does not treat legal signature state as field confirmation capability',
    () {
      final act = ActModel.fromJson({'id': 23, 'signature_status': 'pending'});
      expect(act.canFieldConfirm, isFalse);
    },
  );

  test('shows act workflow statuses in Russian', () {
    for (final entry
        in {
          'draft': 'Черновик',
          'pending_approval': 'На согласовании',
          'approved': 'Утвержден',
          'rejected': 'Отклонен',
          'signed': 'Подписан',
          'annulled': 'Аннулирован',
        }.entries) {
      final act = ActModel.fromJson({'id': 24, 'status': entry.key});
      expect(act.status, entry.value);
    }
  });

  test('translates a raw status label and preserves a readable label', () {
    final raw = ActModel.fromJson({
      'id': 25,
      'status': 'approved',
      'status_label': 'approved',
    });
    final readable = ActModel.fromJson({
      'id': 26,
      'status': 'approved',
      'status_label': 'Утверждён руководителем',
    });

    expect(raw.status, 'Утвержден');
    expect(readable.status, 'Утверждён руководителем');
  });
}
