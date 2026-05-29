import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/quality_control/data/quality_control_repository.dart';

import '../../../helpers/mobile_integration_test_helpers.dart';

void main() {
  test(
    'sends before photos as multipart attachments when creating defect',
    () async {
      final queue = TestDioResponseQueue();
      queue.respond('POST', '/quality-control/defects', {
        'success': true,
        'data': _defectPayload(),
      });
      final photos = await _createTempPhotos('quality-before', 2);

      final repository = QualityControlRepository(queue.buildDio());

      await repository.createDefect({
        'project_id': 9,
        'title': 'Скол плитки',
        'severity': 'major',
        'inspection_required': false,
      }, photoPaths: photos.map((photo) => photo.path).toList());

      final request = queue.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/quality-control/defects');
      expect(request.data, isA<FormData>());

      final formData = request.data as FormData;
      expect(_field(formData, 'project_id'), '9');
      expect(_field(formData, 'title'), 'Скол плитки');
      expect(_field(formData, 'inspection_required'), '0');
      expect(_field(formData, 'photos[0][type]'), 'before');
      expect(_field(formData, 'photos[1][type]'), 'before');
      expect(formData.files[0].key, 'photos[0][file]');
      expect(formData.files[0].value.filename, photos[0].uri.pathSegments.last);
      expect(formData.files[1].key, 'photos[1][file]');
      expect(formData.files[1].value.filename, photos[1].uri.pathSegments.last);
    },
  );

  test(
    'sends after photos as multipart attachments when resolving defect',
    () async {
      final queue = TestDioResponseQueue();
      queue.respond('POST', '/quality-control/defects/7/resolve', {
        'success': true,
        'data': _defectPayload(status: 'ready_for_review'),
      });
      final photos = await _createTempPhotos('quality-after', 2);

      final repository = QualityControlRepository(queue.buildDio());

      await repository.resolveDefect(
        7,
        comment: 'Исправлено',
        photoPaths: photos.map((photo) => photo.path).toList(),
      );

      final request = queue.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/quality-control/defects/7/resolve');
      expect(request.data, isA<FormData>());

      final formData = request.data as FormData;
      expect(_field(formData, 'comment'), 'Исправлено');
      expect(_field(formData, 'photos[0][type]'), 'after');
      expect(_field(formData, 'photos[1][type]'), 'after');
      expect(formData.files[0].key, 'photos[0][file]');
      expect(formData.files[0].value.filename, photos[0].uri.pathSegments.last);
      expect(formData.files[1].key, 'photos[1][file]');
      expect(formData.files[1].value.filename, photos[1].uri.pathSegments.last);
    },
  );
}

Future<List<File>> _createTempPhotos(String prefix, int count) async {
  final files = <File>[];
  for (var index = 0; index < count; index++) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      '${Directory.systemTemp.path}/$prefix-$timestamp-$index.jpg',
    );
    files.add(await file.writeAsBytes(<int>[0, 1, 2, 3]));
  }
  addTearDown(() {
    for (final file in files) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });

  return files;
}

String? _field(FormData formData, String key) {
  for (final field in formData.fields) {
    if (field.key == key) {
      return field.value;
    }
  }

  return null;
}

Map<String, dynamic> _defectPayload({String status = 'open'}) {
  return {
    'id': 1,
    'defect_number': 'QD-1',
    'title': 'Скол плитки',
    'severity': 'major',
    'status': status,
    'inspection_required': false,
    'workflow_summary': {
      'status': status,
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
