import 'dart:math' as math;

enum DrawingTool { freehand, line, arrow }

class DrawingPoint {
  const DrawingPoint(this.x, this.y);
  final double x;
  final double y;
  Map<String, double> toJson() => {'x': x, 'y': y};
}

class DrawingStroke {
  const DrawingStroke({
    required this.tool,
    required this.points,
    this.color = '#e53935',
    this.width = 3,
  });
  final DrawingTool tool;
  final List<DrawingPoint> points;
  final String color;
  final double width;
  DrawingStroke withPoints(List<DrawingPoint> value) =>
      DrawingStroke(tool: tool, points: value, color: color, width: width);
  Map<String, dynamic> toJson() => {
    'kind': tool.name,
    'color': color,
    'width': width,
    'points': points.map((point) => point.toJson()).toList(),
  };
}

class DrawingAnnotations {
  const DrawingAnnotations({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.strokes,
  });
  final int pageNumber;
  final double width;
  final double height;
  final List<DrawingStroke> strokes;

  factory DrawingAnnotations.page(
    int pageNumber,
    double width,
    double height,
    List<DrawingStroke> strokes,
  ) {
    final scale = math.min(1.0, 2048 / math.max(width, height));
    return DrawingAnnotations(
      pageNumber: pageNumber,
      width: width * scale,
      height: height * scale,
      strokes: strokes,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'page_number': pageNumber,
    'width': width,
    'height': height,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
  };

  static DrawingAnnotations? tryParse(dynamic value) {
    if (value is! Map ||
        value['schema_version'] != 1 ||
        value['page_number'] is! int ||
        value['page_number'] < 1 ||
        value['page_number'] > 10000 ||
        value['width'] is! num ||
        value['height'] is! num ||
        value['strokes'] is! List) {
      return null;
    }
    final width = (value['width'] as num).toDouble();
    final height = (value['height'] as num).toDouble();
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0 ||
        width > 16384 ||
        height > 16384 ||
        width * height > 8000000) {
      return null;
    }
    final rawStrokes = value['strokes'] as List;
    if (rawStrokes.length > 100) return null;
    final strokes = <DrawingStroke>[];
    var pointCount = 0;
    for (final raw in rawStrokes) {
      if (raw is! Map ||
          raw['points'] is! List ||
          raw['color'] is! String ||
          raw['width'] is! num) {
        return null;
      }
      final tool =
          DrawingTool.values
              .where((tool) => tool.name == raw['kind'])
              .firstOrNull;
      final points = raw['points'] as List;
      final strokeWidth = (raw['width'] as num).toDouble();
      if (tool == null ||
          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(raw['color']) ||
          !strokeWidth.isFinite ||
          strokeWidth < 1 ||
          strokeWidth > 20 ||
          points.length < 2 ||
          points.length > 1000 ||
          (tool != DrawingTool.freehand && points.length != 2)) {
        return null;
      }
      pointCount += points.length;
      if (pointCount > 10000) return null;
      final parsed = <DrawingPoint>[];
      for (final point in points) {
        if (point is! Map || point['x'] is! num || point['y'] is! num) {
          return null;
        }
        final x = (point['x'] as num).toDouble();
        final y = (point['y'] as num).toDouble();
        if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
          return null;
        }
        parsed.add(DrawingPoint(x, y));
      }
      strokes.add(
        DrawingStroke(
          tool: tool,
          points: parsed,
          color: raw['color'],
          width: strokeWidth,
        ),
      );
    }
    return DrawingAnnotations(
      pageNumber: value['page_number'],
      width: width,
      height: height,
      strokes: strokes,
    );
  }
}
