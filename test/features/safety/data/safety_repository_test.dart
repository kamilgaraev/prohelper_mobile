import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/safety/data/safety_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('sends violation evidence as photos[] multipart files', () async {
    final directory = await Directory.systemTemp.createTemp('safety-photo-');
    addTearDown(() => directory.delete(recursive: true));
    final photo = File('${directory.path}/evidence.jpg');
    await photo.writeAsBytes([1, 2, 3]);
    final queue =
        TestDioResponseQueue()
          ..respond('POST', '/safety-management/violations', {
            'success': true,
            'data': {
              'id': 4,
              'project_id': 9,
              'violation_number': 'HSE-V-4',
              'title': 'Нет ограждения',
              'severity': 'high',
              'status': 'open',
              'status_label': 'Открыто',
              'available_actions': ['resolve'],
            },
          });

    await SafetyRepository(queue.buildDio()).createViolation(
      {'project_id': 9, 'title': 'Нет ограждения', 'severity': 'high'},
      photoPaths: [photo.path],
    );

    final formData = queue.requests.single.data! as FormData;
    expect(queue.requests.single.path, '/safety-management/violations');
    expect(
      formData.fields.any(
        (entry) => entry.key == 'project_id' && entry.value == '9',
      ),
      isTrue,
    );
    expect(formData.files.map((entry) => entry.key), ['photos[]']);
    expect(formData.files.single.value.filename, 'evidence.jpg');
  });
}
