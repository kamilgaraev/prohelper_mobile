import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/handover_acceptance/data/handover_acceptance_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('sends checklist review photos[] with existing form fields', () async {
    final directory = await Directory.systemTemp.createTemp('handover-photo-');
    addTearDown(() => directory.delete(recursive: true));
    final photo = File('${directory.path}/checklist.jpg');
    await photo.writeAsBytes([1, 2, 3]);
    final queue =
        TestDioResponseQueue()
          ..respond('POST', '/handover-acceptance/checklist-items/31/review', {
            'success': true,
            'data': {
              'id': 30,
              'acceptance_scope_id': 5,
              'title': 'Окна проверены',
              'status': 'active',
              'items': [
                {
                  'id': 31,
                  'title': 'Окна проверены',
                  'is_required': true,
                  'status': 'accepted',
                  'available_actions': [],
                  'comment': 'Осмотрено',
                },
              ],
            },
          });

    await HandoverAcceptanceRepository(queue.buildDio()).reviewChecklistItem(
      31,
      status: 'accepted',
      comment: 'Осмотрено',
      photoPaths: [photo.path],
    );

    final formData = queue.requests.single.data! as FormData;
    expect(
      queue.requests.single.path,
      '/handover-acceptance/checklist-items/31/review',
    );
    expect(
      formData.fields.any(
        (entry) => entry.key == 'status' && entry.value == 'accepted',
      ),
      isTrue,
    );
    expect(
      formData.fields.any(
        (entry) => entry.key == 'comment' && entry.value == 'Осмотрено',
      ),
      isTrue,
    );
    expect(formData.files.map((entry) => entry.key), ['photos[]']);
    expect(formData.files.single.value.filename, 'checklist.jpg');
  });
}
