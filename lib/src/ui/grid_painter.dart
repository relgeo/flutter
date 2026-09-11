import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../geometry/types.dart'; // BoundingBox

class GridPainter extends CustomPainter {
  final Matrix4 transform;
  final BoundingBox? bbox;
  final Color minorColor;
  final Color majorColor;
  final double baseWorldStep;

  GridPainter({
    required this.transform,
    this.bbox,
    this.minorColor = const Color(0xFF1E293B),
    this.majorColor = const Color(0xFF334155),
    this.baseWorldStep = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.getMaxScaleOnAxis();
    final dx = transform.entry(0, 3);
    final dy = transform.entry(1, 3);

    final gridPaint = Paint()
      ..color = minorColor
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = majorColor
      ..strokeWidth = 0.5;

    // Dynamic grid step based on scale to maintain consistent density
    double worldStep = baseWorldStep;
    if (scale < 0.2) {
      worldStep = baseWorldStep * 5;
    } else if (scale < 0.5) {
      worldStep = baseWorldStep * 2.5;
    } else if (scale > 3.0) {
      worldStep = baseWorldStep / 4;
    } else if (scale > 8.0) {
      worldStep = baseWorldStep / 20;
    }

    final double step = worldStep * scale;

    final double bboxX = bbox?.x ?? 0.0;
    final double bboxY = bbox?.y ?? 0.0;

    final double offsetX = dx - scale * bboxX;
    final double offsetY = dy - scale * bboxY;

    // Minor grid lines
    double startX = offsetX % step;
    if (startX < 0) startX += step;
    for (double x = startX; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    double startY = offsetY % step;
    if (startY < 0) startY += step;
    for (double y = startY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Major grid lines (5x)
    final double majorStep = step * 5;
    double startMajorX = offsetX % majorStep;
    if (startMajorX < 0) startMajorX += majorStep;
    for (double x = startMajorX; x < size.width; x += majorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }

    double startMajorY = offsetY % majorStep;
    if (startMajorY < 0) startMajorY += majorStep;
    for (double y = startMajorY; y < size.height; y += majorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter old) =>
      old.transform != transform ||
      old.bbox != bbox ||
      old.minorColor != minorColor ||
      old.majorColor != majorColor ||
      old.baseWorldStep != baseWorldStep;
}
