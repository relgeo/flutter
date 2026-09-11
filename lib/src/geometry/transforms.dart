/// Implementasi sistem transformasi 2D untuk RelGeo (Translate, Rotate, Scale, Mirror).

import 'dart:math' as math;
import 'types.dart';

Point2D applyTransformPipeline(
  Point2D point,
  List<ResolvedTransformOp> transform,
) {
  double px = point.x;
  double py = point.y;

  // Transformasi SVG diaplikasikan dari belakang ke depan (right-to-left)
  for (int i = transform.length - 1; i >= 0; i--) {
    final op = transform[i];
    switch (op) {
      case TranslateOp(:final x, :final y):
        px += x;
        py += y;
      case RotateOp(:final angle, :final origin):
        final rad = (angle * math.pi) / 180.0;
        final cos = math.cos(rad);
        final sin = math.sin(rad);
        final dx = px - origin.x;
        final dy = py - origin.y;
        px = origin.x + dx * cos - dy * sin;
        py = origin.y + dx * sin + dy * cos;
      case ScaleOp(:final sx, :final sy, :final origin):
        px = origin.x + (px - origin.x) * sx;
        py = origin.y + (py - origin.y) * sy;
      case MirrorOp(:final axis, :final origin):
        if (axis == "x" || axis == "both") {
          px = origin.x - (px - origin.x);
        }
        if (axis == "y" || axis == "both") {
          py = origin.y - (py - origin.y);
        }
    }
  }

  return (x: px, y: py);
}

/// Mengkonversi koordinat dunia ke koordinat lokal dengan membalik pipeline transform.
/// Ini adalah inverse dari [applyTransformPipeline] — dipakai untuk implementasi toLocal().
Point2D applyInverseTransformPipeline(
  Point2D point,
  List<ResolvedTransformOp> transform,
) {
  double px = point.x;
  double py = point.y;

  // Inverse: aplikasikan dari depan ke belakang, dengan setiap operasi dibalik
  for (int i = 0; i < transform.length; i++) {
    final op = transform[i];
    switch (op) {
      case TranslateOp(:final x, :final y):
        // Inverse translate: kurangi
        px -= x;
        py -= y;
      case RotateOp(:final angle, :final origin):
        // Inverse rotate: sudut negatif
        final rad = -(angle * math.pi) / 180.0;
        final cos = math.cos(rad);
        final sin = math.sin(rad);
        final dx = px - origin.x;
        final dy = py - origin.y;
        px = origin.x + dx * cos - dy * sin;
        py = origin.y + dx * sin + dy * cos;
      case ScaleOp(:final sx, :final sy, :final origin):
        // Inverse scale: bagi (guard division by zero)
        if (sx != 0) px = origin.x + (px - origin.x) / sx;
        if (sy != 0) py = origin.y + (py - origin.y) / sy;
      case MirrorOp(:final axis, :final origin):
        // Mirror adalah self-inverse
        if (axis == "x" || axis == "both") {
          px = origin.x - (px - origin.x);
        }
        if (axis == "y" || axis == "both") {
          py = origin.y - (py - origin.y);
        }
    }
  }

  return (x: px, y: py);
}
