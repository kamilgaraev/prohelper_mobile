import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test('sends before photo as multipart attachment when creating defect', () async {
    final queue = TestDioResponseQueue();
    queue.respond('POST', '/quality-control/defects', {
      'success': true,
      'data': _defectPayload(),
    });
    final photo = await _createTempPhoto();
    addTearDown(() {
      if (photo.existsSync()) {
        photo.deleteSync();
      }
    });

    final repository = QualityControlRepository(queue.buildDio());

    await repository.createDefect(
      {
        'project_id': 9,
        'title': 'Скол плитки',
        'severity': 'major',
        'inspection_required': false,
      },
      photoPath: photo.path,
    );

    final request = queue.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/quality-control/defects');
    expect(request.data, isA<FormData>());

    final formData = request.data as FormData;
    expect(_field(formData, 'project_id'), '9');
    expect(_field(formData, 'title'), 'Скол плитки');
    expect(_field(formData, 'inspection_required'), '0');
    expect(_field(formData, 'photos[0][type]'), 'before');
    expect(formData.files.single.key, 'photos[0][file]');
    expect(formData.files.single.value.filename, photo.uri.pathSegments.last);
  });
}

Future<File> _createTempPhoto() async {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final file = File(
    '${Directory.systemTemp.path}/quality-before-$timestamp.jpg',
  );

  return file.writeAsBytes(<int>[0, 1, 2, 3]);
}

String? _field(FormData formData, String key) {
  for (final field in formData.fields) {
    if (field.key == key) {
      return field.value;
    }
  }

  return null;
}

Map<String, dynamic> _defectPayload() {
  return {
    'id': 1,
    'defect_number': 'QD-1',
    'title': 'Скол плитки',
    'severity': 'major',
    'status': 'open',
    'inspection_required': false,
    'workflow_summary': {
      'status': 'open',
      'available_actions': ['start'],
      'problem_flags': [],
    },
    'available_actions': ['start'],
    'photos': [],
    'status_history': [],
    'problem_flags': [],
    'created_at': '2026-05-29T10:00:00Z',
    'updated_at': '2026-05-29T10:00:00Z',
  };
}
