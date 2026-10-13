import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/data/design_package_model.dart';
import 'package:prohelpers_mobile/features/design_management/data/drawing_annotations.dart';

void main() {
  test('document markup keeps page and normalized points across clients', () {
    final value = DrawingAnnotations.page(2, 12000, 8000, [
      const DrawingStroke(
        tool: DrawingTool.arrow,
        points: [DrawingPoint(0.1, 0.2), DrawingPoint(0.8, 0.9)],
      ),
    ]);
    expect(value.width, 2048);
    expect(value.width / value.height, closeTo(1.5, 0.0001));
    final parsed = DrawingAnnotations.tryParse(value.toJson())!;
    expect(parsed.pageNumber, 2);
    expect(parsed.strokes.single.points.last.x, 0.8);
  });
  test('BIM and malformed markup are not rendered on a document', () {
    final value =
        DrawingAnnotations.page(1, 1000, 700, [
          const DrawingStroke(
            tool: DrawingTool.line,
            points: [DrawingPoint(0, 0), DrawingPoint(1, 1)],
          ),
        ]).toJson();
    expect(
      DrawingAnnotations.tryParse({...value}..remove('page_number')),
      isNull,
    );
    expect(DrawingAnnotations.tryParse({...value, 'page_number': 0}), isNull);
    expect(
      DrawingAnnotations.tryParse({...value, 'width': double.nan}),
      isNull,
    );
    final invalid = {
      ...value,
      'strokes': [
        {
          'kind': 'arrow',
          'color': '#e53935',
          'width': 3,
          'points': [
            {'x': 1.1, 'y': 0},
            {'x': 1, 'y': 1},
          ],
        },
      ],
    };
    expect(DrawingAnnotations.tryParse(invalid), isNull);
  });
  test('older API defaults to read only and current files use version IDs', () {
    final old = DesignPackageFile.fromJson({
      'id': 15,
      'name': 'План.PDF',
      'download_url': 'https://files.test/plan',
    });
    expect(old.canAnnotate, isFalse);
    expect(old.supportsDrawingViewer, isTrue);
    final current = DesignPackageFile.fromJson({
      'id': 15,
      'artifact_id': 7,
      'name': 'План.pdf',
      'mime_type': 'application/pdf',
      'can_annotate': true,
      'version_number': '2',
    });
    expect(current.id, 15);
    expect(current.canAnnotate, isTrue);
    expect(current.versionNumber, '2');
    expect(
      DesignPackageFile.fromJson({
        'id': 2,
        'name': 'План.dwg',
      }).supportsDrawingViewer,
      isFalse,
    );
  });
}
