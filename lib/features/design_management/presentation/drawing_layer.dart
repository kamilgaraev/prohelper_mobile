import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../data/drawing_annotations.dart';

class DrawingAuthorLabel {
  const DrawingAuthorLabel(this.name, this.point);
  final String name;
  final DrawingPoint point;
}

class DrawingLayer extends StatefulWidget {
  const DrawingLayer({
    super.key,
    required this.size,
    required this.pageNumber,
    required this.saved,
    required this.drafts,
    required this.onStroke,
    this.tool,
    this.labels = const [],
  });
  final Size size;
  final int pageNumber;
  final List<DrawingAnnotations> saved;
  final List<DrawingStroke> drafts;
  final DrawingTool? tool;
  final List<DrawingAuthorLabel> labels;
  final void Function(int pageNumber, DrawingStroke stroke) onStroke;
  @override
  State<DrawingLayer> createState() => _DrawingLayerState();
}

class _DrawingLayerState extends State<DrawingLayer> {
  DrawingStroke? _stroke;
  int? _pointer;
  DrawingPoint _point(Offset position, Size bounds) => DrawingPoint(
    (position.dx / bounds.width).clamp(0.0, 1.0),
    (position.dy / bounds.height).clamp(0.0, 1.0),
  );
  @override
  void didUpdateWidget(DrawingLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool != widget.tool ||
        oldWidget.pageNumber != widget.pageNumber) {
      _stroke = null;
      _pointer = null;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bounds = constraints.biggest;
      final draft = DrawingAnnotations.page(
        widget.pageNumber,
        widget.size.width,
        widget.size.height,
        [...widget.drafts, if (_stroke != null) _stroke!],
      );
      final paint = CustomPaint(
        painter: _DrawingPainter(
          [...widget.saved, draft],
          widget.labels,
          Theme.of(context).textTheme.labelMedium ??
              const TextStyle(fontSize: 13),
          Theme.of(context).colorScheme.surface,
          Theme.of(context).colorScheme.outlineVariant,
          MediaQuery.textScalerOf(context),
        ),
        child: const SizedBox.expand(),
      );
      if (widget.tool == null) return IgnorePointer(child: paint);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (details) {
          if (_pointer != null ||
              details.buttons != kPrimaryButton ||
              widget.drafts.length >= 100 ||
              widget.drafts.fold<int>(
                    0,
                    (total, stroke) => total + stroke.points.length,
                  ) >=
                  9000 ||
              bounds.isEmpty) {
            return;
          }
          final point = _point(details.localPosition, bounds);
          _pointer = details.pointer;
          setState(
            () =>
                _stroke = DrawingStroke(
                  tool: widget.tool!,
                  points: [point, point],
                ),
          );
        },
        onPointerMove: (details) {
          final stroke = _stroke;
          if (stroke == null || _pointer != details.pointer) return;
          final point = _point(details.localPosition, bounds);
          final points =
              stroke.tool == DrawingTool.freehand
                  ? [...stroke.points, point].take(1000).toList()
                  : [stroke.points.first, point];
          setState(() => _stroke = stroke.withPoints(points));
        },
        onPointerUp: (details) {
          if (_pointer != details.pointer) return;
          final stroke = _stroke;
          setState(() {
            _stroke = null;
            _pointer = null;
          });
          if (stroke != null &&
              stroke.points.any(
                (point) =>
                    point.x != stroke.points.first.x ||
                    point.y != stroke.points.first.y,
              )) {
            widget.onStroke(widget.pageNumber, stroke);
          }
        },
        onPointerCancel: (details) {
          if (_pointer == details.pointer) {
            setState(() {
              _stroke = null;
              _pointer = null;
            });
          }
        },
        child: paint,
      );
    },
  );
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter(
    this.annotations,
    this.labels,
    this.labelStyle,
    this.labelBackground,
    this.labelBorder,
    this.textScaler,
  );
  final List<DrawingAnnotations> annotations;
  final List<DrawingAuthorLabel> labels;
  final TextStyle labelStyle;
  final Color labelBackground;
  final Color labelBorder;
  final TextScaler textScaler;
  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      final scale = size.width / annotation.width;
      for (final stroke in annotation.strokes) {
        if (stroke.points.length < 2) continue;
        final points =
            stroke.points
                .map(
                  (point) =>
                      Offset(point.x * size.width, point.y * size.height),
                )
                .toList();
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        if (stroke.tool == DrawingTool.arrow) {
          final end = points.last;
          final angle = math.atan2(
            end.dy - points.first.dy,
            end.dx - points.first.dx,
          );
          final length = math.max(12.0, stroke.width * 4) * scale;
          path.moveTo(
            end.dx - length * math.cos(angle - math.pi / 6),
            end.dy - length * math.sin(angle - math.pi / 6),
          );
          path.lineTo(end.dx, end.dy);
          path.lineTo(
            end.dx - length * math.cos(angle + math.pi / 6),
            end.dy - length * math.sin(angle + math.pi / 6),
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = Color(
              0xff000000 | int.parse(stroke.color.substring(1), radix: 16),
            )
            ..strokeWidth = stroke.width * scale
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    for (final label in labels) {
      final text = TextPainter(
        text: TextSpan(
          text:
              label.name.length > 26
                  ? '${label.name.substring(0, 25)}…'
                  : label.name,
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: math.max(1, size.width - 20));
      final x =
          (label.point.x * size.width + 6)
              .clamp(4.0, math.max(4.0, size.width - text.width - 16))
              .toDouble();
      final y =
          (label.point.y * size.height - text.height - 12)
              .clamp(4.0, math.max(4.0, size.height - text.height - 12))
              .toDouble();
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, text.width + 12, text.height + 8),
        const Radius.circular(4),
      );
      canvas.drawRRect(box, Paint()..color = labelBackground);
      canvas.drawRRect(
        box,
        Paint()
          ..color = labelBorder
          ..style = PaintingStyle.stroke,
      );
      text.paint(canvas, Offset(x + 6, y + 4));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}
