import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/data/drawing_annotations.dart';
import 'package:prohelpers_mobile/features/design_management/presentation/drawing_layer.dart';

void main() {
  testWidgets('saves a short line without requiring touch slop', (
    tester,
  ) async {
    DrawingStroke? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 100,
              child: DrawingLayer(
                size: const Size(1000, 500),
                pageNumber: 1,
                saved: const [],
                drafts: const [],
                tool: DrawingTool.line,
                onStroke: (page, stroke) {
                  saved = stroke;
                },
              ),
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(DrawingLayer));
    final gesture = await tester.startGesture(origin + const Offset(20, 30));
    await gesture.moveTo(origin + const Offset(26, 33));
    await gesture.up();
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.points.first.x, closeTo(0.1, 0.001));
    expect(saved!.points.last.x, closeTo(0.13, 0.001));
  });
  testWidgets('starts an arrow at the contact point before touch slop', (
    tester,
  ) async {
    DrawingStroke? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 100,
              child: DrawingLayer(
                size: const Size(1000, 500),
                pageNumber: 2,
                saved: const [],
                drafts: const [],
                tool: DrawingTool.arrow,
                onStroke: (page, stroke) {
                  expect(page, 2);
                  saved = stroke;
                },
              ),
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(DrawingLayer));
    final gesture = await tester.startGesture(origin + const Offset(20, 30));
    await gesture.moveTo(origin + const Offset(150, 70));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.points.first.x, closeTo(0.1, 0.001));
    expect(saved!.points.first.y, closeTo(0.3, 0.001));
  });
}
