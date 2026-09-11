/// Engine Perpotongan Geometri Terpadu (Generalized Intersection Engine) RelGeo.
///
/// Modul ini menghitung seluruh titik perpotongan (intersections) analitis dan
/// numerik antara berbagai jenis objek geometri secara deterministik.
/// Hasil diurutkan berdasarkan koordinat X menaik (atau Y sebagai tiebreaker)
/// untuk menjaga stabilitas seleksi indeks koleksi.

import 'dart:math' as math;
import 'types.dart';
import 'utils.dart' as geom;

const double tolerance = 1e-9;

bool eq(double a, double b) {
  return (a - b).abs() < tolerance;
}

List<Point2D> sortPoints(List<Point2D> pts) {
  final sorted = List<Point2D>.from(pts);
  sorted.sort((a, b) {
    if (eq(a.x, b.x)) {
      return a.y.compareTo(b.y);
    }
    return a.x.compareTo(b.x);
  });
  return sorted;
}

List<Point2D> dedupePoints(List<Point2D> pts) {
  final sorted = sortPoints(pts);
  final List<Point2D> result = [];
  for (final pt in sorted) {
    if (result.isEmpty) {
      result.add(pt);
    } else {
      final prev = result.last;
      if (!eq(prev.x, pt.x) || !eq(prev.y, pt.y)) {
        result.add(pt);
      }
    }
  }
  return result;
}

// ─────────────────────────────────────────────
// Line-Line
// ─────────────────────────────────────────────

Point2D? intersectLines(
  double x1, double y1, double x2, double y2,
  double x3, double y3, double x4, double y4,
) {
  final denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1);
  if (eq(denom, 0)) return null;

  final ua = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / denom;
  return (x: x1 + ua * (x2 - x1), y: y1 + ua * (y2 - y1));
}

bool pointOnSegment(Point2D p, Point2D a, Point2D b) {
  final cross = (p.y - a.y) * (b.x - a.x) - (p.x - a.x) * (b.y - a.y);
  if (cross.abs() > tolerance) return false;
  final dot = (p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y);
  if (dot < -tolerance) return false;
  final lenSq = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y);
  return dot <= lenSq + tolerance;
}

List<Point2D> intersectLineWithBoundedLine(
  double x1, double y1, double x2, double y2,
  double x3, double y3, double x4, double y4,
) {
  final point = intersectLines(x1, y1, x2, y2, x3, y3, x4, y4);
  if (point == null) return [];
  return pointOnSegment(point, (x: x3, y: y3), (x: x4, y: y4)) ? [point] : [];
}

List<Point2D> intersectBoundedLines(
  double x1, double y1, double x2, double y2,
  double x3, double y3, double x4, double y4,
) {
  final point = intersectLines(x1, y1, x2, y2, x3, y3, x4, y4);
  if (point == null) return [];
  final onL1 = pointOnSegment(point, (x: x1, y: y1), (x: x2, y: y2));
  final onL2 = pointOnSegment(point, (x: x3, y: y3), (x: x4, y: y4));
  return (onL1 && onL2) ? [point] : [];
}

// ─────────────────────────────────────────────
// Line-Circle
// ─────────────────────────────────────────────

List<Point2D> intersectLineCircle(
  double x1, double y1, double x2, double y2,
  double cx, double cy, double r,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final fx = x1 - cx;
  final fy = y1 - cy;

  final a = dx * dx + dy * dy;
  final b = 2 * (fx * dx + fy * dy);
  final c = fx * fx + fy * fy - r * r;

  final discriminant = b * b - 4 * a * c;

  if (discriminant < -tolerance) return [];
  if (eq(discriminant, 0)) {
    final t = -b / (2 * a);
    return sortPoints([(x: x1 + t * dx, y: y1 + t * dy)]);
  }

  final sqrtD = math.sqrt(math.max(0.0, discriminant));
  final t1 = (-b - sqrtD) / (2 * a);
  final t2 = (-b + sqrtD) / (2 * a);
  return sortPoints([
    (x: x1 + t1 * dx, y: y1 + t1 * dy),
    (x: x1 + t2 * dx, y: y1 + t2 * dy),
  ]);
}

// ─────────────────────────────────────────────
// Circle-Circle
// ─────────────────────────────────────────────

List<Point2D> intersectCircles(
  double cx1, double cy1, double r1,
  double cx2, double cy2, double r2,
) {
  final dx = cx2 - cx1;
  final dy = cy2 - cy1;
  final d = math.sqrt(dx * dx + dy * dy);

  if (d < tolerance) return []; // concentric
  if (d > r1 + r2 + tolerance) return []; // too far apart
  if (d < (r1 - r2).abs() - tolerance) return []; // one inside other

  final a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
  final h2 = r1 * r1 - a * a;
  if (h2 < 0) return [];
  final h = math.sqrt(math.max(0.0, h2));

  final mx = cx1 + (a * dx) / d;
  final my = cy1 + (a * dy) / d;

  if (eq(h, 0)) {
    return sortPoints([(x: mx, y: my)]);
  }

  return sortPoints([
    (x: mx + (h * dy) / d, y: my - (h * dx) / d),
    (x: mx - (h * dy) / d, y: my + (h * dx) / d),
  ]);
}

// ─────────────────────────────────────────────
// Arc Helpers
// ─────────────────────────────────────────────

bool angleInArc(double angle, double startAngle, double endAngle) {
  const tau = math.pi * 2;
  final norm = ((angle % tau) + tau) % tau;
  final s = ((startAngle % tau) + tau) % tau;
  var e = ((endAngle % tau) + tau) % tau;

  if (s <= e) {
    return norm >= s - tolerance && norm <= e + tolerance;
  } else {
    return norm >= s - tolerance || norm <= e + tolerance;
  }
}

List<Point2D> filterByArc(List<Point2D> points, double cx, double cy, double startAngle, double endAngle) {
  return points.where((p) {
    final angle = math.atan2(p.y - cy, p.x - cx);
    return angleInArc(angle, startAngle, endAngle);
  }).toList();
}

// ─────────────────────────────────────────────
// Line-Arc
// ─────────────────────────────────────────────

List<Point2D> intersectLineArc(
  double x1, double y1, double x2, double y2,
  double cx, double cy, double r, double startAngle, double endAngle,
) {
  final all = intersectLineCircle(x1, y1, x2, y2, cx, cy, r);
  return sortPoints(filterByArc(all, cx, cy, startAngle, endAngle));
}

// ─────────────────────────────────────────────
// Circle-Arc
// ─────────────────────────────────────────────

List<Point2D> intersectCircleArc(
  double cx1, double cy1, double r1,
  double cx2, double cy2, double r2, double startAngle, double endAngle,
) {
  final all = intersectCircles(cx1, cy1, r1, cx2, cy2, r2);
  return sortPoints(filterByArc(all, cx2, cy2, startAngle, endAngle));
}

// ─────────────────────────────────────────────
// Arc-Arc
// ─────────────────────────────────────────────

List<Point2D> intersectArcs(
  double cx1, double cy1, double r1, double start1, double end1,
  double cx2, double cy2, double r2, double start2, double end2,
) {
  final all = intersectCircles(cx1, cy1, r1, cx2, cy2, r2);
  final inA1 = filterByArc(all, cx1, cy1, start1, end1);
  final inA2 = filterByArc(inA1, cx2, cy2, start2, end2);
  return sortPoints(inA2);
}

// ─────────────────────────────────────────────
// Path & Approximation Helpers
// ─────────────────────────────────────────────

List<Point2D> sampleArc(
  double cx, double cy, double radius, double startAngle, double endAngle,
  [int steps = 48]
) {
  final List<Point2D> points = [];
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final angle = startAngle + (endAngle - startAngle) * t;
    points.add((
      x: cx + radius * math.cos(angle),
      y: cy + radius * math.sin(angle),
    ));
  }
  return points;
}

List<LineSegment> polylineToSegments(List<Point2D> points) {
  final List<LineSegment> segments = [];
  for (int i = 1; i < points.length; i++) {
    segments.add(LineSegment(
      points[i - 1].x, points[i - 1].y,
      points[i].x, points[i].y,
    ));
  }
  return segments;
}

List<LineSegment> approximateSegment(PathResolvedSegment segment) {
  switch (segment) {
    case LineSegment(:final x1, :final y1, :final x2, :final y2):
      return [LineSegment(x1, y1, x2, y2)];
    case ArcSegment(:final cx, :final cy, :final radius, :final x1, :final y1, :final x2, :final y2, :final sweep):
      final startAngle = math.atan2(y1 - cy, x1 - cx);
      double endAngle = math.atan2(y2 - cy, x2 - cx);
      if (sweep == 1 && endAngle < startAngle) endAngle += math.pi * 2;
      if (sweep == 0 && endAngle > startAngle) endAngle -= math.pi * 2;
      return polylineToSegments(sampleArc(cx, cy, radius, startAngle, endAngle));
    case QuadraticSegment(:final x1, :final y1, :final cpx, :final cpy, :final x2, :final y2):
      return polylineToSegments(geom.sampleQuadraticPoints(x1: x1, y1: y1, cpx: cpx, cpy: cpy, x2: x2, y2: y2));
    case CubicSegment(:final x1, :final y1, :final cp1x, :final cp1y, :final cp2x, :final cp2y, :final x2, :final y2):
      return polylineToSegments(geom.sampleCubicPoints(x1: x1, y1: y1, cp1x: cp1x, cp1y: cp1y, cp2x: cp2x, cp2y: cp2y, x2: x2, y2: y2));
  }
}

List<PathResolvedSegment>? objectToPathSegments(ResolvedObject obj) {
  if (obj is ResolvedRect) {
    return [
      LineSegment(obj.x, obj.y, obj.x + obj.width, obj.y),
      LineSegment(obj.x + obj.width, obj.y, obj.x + obj.width, obj.y + obj.height),
      LineSegment(obj.x + obj.width, obj.y + obj.height, obj.x, obj.y + obj.height),
      LineSegment(obj.x, obj.y + obj.height, obj.x, obj.y),
    ];
  }
  if (obj is ResolvedPath) {
    final List<PathResolvedSegment> allSegments = [];
    if (obj.segments.isNotEmpty) {
      allSegments.addAll(obj.segments);
    } else if (obj.points.length > 1) {
      allSegments.addAll(polylineToSegments(obj.points));
    }
    for (final hole in obj.holes) {
      allSegments.addAll(hole.segments);
    }
    return allSegments.isNotEmpty ? allSegments : null;
  }
  if (obj is ResolvedPolygon) {
    if (obj.segments.isNotEmpty) {
      return obj.segments;
    }
    if (obj.points.length > 1) {
      final List<PathResolvedSegment> segments = [];
      for (int i = 0; i < obj.points.length; i++) {
        final a = obj.points[i];
        final b = obj.points[(i + 1) % obj.points.length];
        segments.add(LineSegment(a.x, a.y, b.x, b.y));
      }
      return segments;
    }
  }
  return null;
}

List<Point2D> intersectCircleWithSegmentLike(ResolvedCircle circle, PathResolvedSegment segment) {
  if (segment is LineSegment) {
    return intersectLineCircle(segment.x1, segment.y1, segment.x2, segment.y2, circle.cx, circle.cy, circle.radius);
  }
  if (segment is ArcSegment) {
    final start = math.atan2(segment.y1 - segment.cy, segment.x1 - segment.cx);
    double end = math.atan2(segment.y2 - segment.cy, segment.x2 - segment.cx);
    if (segment.sweep == 1 && end < start) end += math.pi * 2;
    if (segment.sweep == 0 && end > start) end -= math.pi * 2;
    return intersectCircleArc(circle.cx, circle.cy, circle.radius, segment.cx, segment.cy, segment.radius, start, end);
  }
  final approx = approximateSegment(segment);
  return dedupePoints(approx.expand((sample) => intersectLineCircle(sample.x1, sample.y1, sample.x2, sample.y2, circle.cx, circle.cy, circle.radius)).toList());
}

List<Point2D> intersectArcWithSegmentLike(ResolvedArc arc, PathResolvedSegment segment) {
  if (segment is LineSegment) {
    return intersectLineArc(segment.x1, segment.y1, segment.x2, segment.y2, arc.cx, arc.cy, arc.radius, arc.startAngle, arc.endAngle);
  }
  if (segment is ArcSegment) {
    final start = math.atan2(segment.y1 - segment.cy, segment.x1 - segment.cx);
    double end = math.atan2(segment.y2 - segment.cy, segment.x2 - segment.cx);
    if (segment.sweep == 1 && end < start) end += math.pi * 2;
    if (segment.sweep == 0 && end > start) end -= math.pi * 2;
    return intersectArcs(arc.cx, arc.cy, arc.radius, arc.startAngle, arc.endAngle, segment.cx, segment.cy, segment.radius, start, end);
  }
  final approx = approximateSegment(segment);
  return dedupePoints(approx.expand((sample) => intersectLineArc(sample.x1, sample.y1, sample.x2, sample.y2, arc.cx, arc.cy, arc.radius, arc.startAngle, arc.endAngle)).toList());
}

List<Point2D> intersectLineWithSegmentLike(
  double x1, double y1, double x2, double y2,
  PathResolvedSegment segment,
) {
  if (segment is LineSegment) {
    return intersectLineWithBoundedLine(x1, y1, x2, y2, segment.x1, segment.y1, segment.x2, segment.y2);
  }
  if (segment is ArcSegment) {
    final start = math.atan2(segment.y1 - segment.cy, segment.x1 - segment.cx);
    double end = math.atan2(segment.y2 - segment.cy, segment.x2 - segment.cx);
    if (segment.sweep == 1 && end < start) end += math.pi * 2;
    if (segment.sweep == 0 && end > start) end -= math.pi * 2;
    return intersectLineArc(x1, y1, x2, y2, segment.cx, segment.cy, segment.radius, start, end);
  }
  final approx = approximateSegment(segment);
  return dedupePoints(approx.expand((sample) => intersectLineWithBoundedLine(x1, y1, x2, y2, sample.x1, sample.y1, sample.x2, sample.y2)).toList());
}

List<Point2D> intersectSegmentLikes(PathResolvedSegment a, PathResolvedSegment b) {
  if (a is LineSegment && b is LineSegment) {
    return intersectBoundedLines(a.x1, a.y1, a.x2, a.y2, b.x1, b.y1, b.x2, b.y2);
  }
  if (a is LineSegment) {
    return intersectLineWithSegmentLike(a.x1, a.y1, a.x2, a.y2, b).where((p) => pointOnSegment(p, (x: a.x1, y: a.y1), (x: a.x2, y: a.y2))).toList();
  }
  if (b is LineSegment) {
    return intersectLineWithSegmentLike(b.x1, b.y1, b.x2, b.y2, a).where((p) => pointOnSegment(p, (x: b.x1, y: b.y1), (x: b.x2, y: b.y2))).toList();
  }
  if (a is ArcSegment && b is ArcSegment) {
    final startA = math.atan2(a.y1 - a.cy, a.x1 - a.cx);
    double endA = math.atan2(a.y2 - a.cy, a.x2 - a.cx);
    if (a.sweep == 1 && endA < startA) endA += math.pi * 2;
    if (a.sweep == 0 && endA > startA) endA -= math.pi * 2;

    final startB = math.atan2(b.y1 - b.cy, b.x1 - b.cx);
    double endB = math.atan2(b.y2 - b.cy, b.x2 - b.cx);
    if (b.sweep == 1 && endB < startB) endB += math.pi * 2;
    if (b.sweep == 0 && endB > startB) endB -= math.pi * 2;

    return intersectArcs(a.cx, a.cy, a.radius, startA, endA, b.cx, b.cy, b.radius, startB, endB);
  }

  final approxA = approximateSegment(a);
  final approxB = approximateSegment(b);
  final List<Point2D> result = [];
  for (final segA in approxA) {
    for (final segB in approxB) {
      result.addAll(intersectBoundedLines(segA.x1, segA.y1, segA.x2, segA.y2, segB.x1, segB.y1, segB.x2, segB.y2));
    }
  }
  return dedupePoints(result);
}

List<Point2D> intersectLineWithPathLike(ResolvedLine line, ResolvedObject obj) {
  final segments = objectToPathSegments(obj) ?? [];
  return dedupePoints(segments.expand((s) => intersectLineWithSegmentLike(line.x1, line.y1, line.x2, line.y2, s)).toList());
}

List<Point2D> intersectCircleWithPathLike(ResolvedCircle circle, ResolvedObject obj) {
  final segments = objectToPathSegments(obj) ?? [];
  return dedupePoints(segments.expand((s) => intersectCircleWithSegmentLike(circle, s)).toList());
}

List<Point2D> intersectArcWithPathLike(ResolvedArc arc, ResolvedObject obj) {
  final segments = objectToPathSegments(obj) ?? [];
  return dedupePoints(segments.expand((s) => intersectArcWithSegmentLike(arc, s)).toList());
}

List<Point2D> intersectPathLikes(ResolvedObject obj1, ResolvedObject obj2) {
  final segments1 = objectToPathSegments(obj1) ?? [];
  final segments2 = objectToPathSegments(obj2) ?? [];
  final List<Point2D> result = [];
  for (final seg1 in segments1) {
    for (final seg2 in segments2) {
      result.addAll(intersectSegmentLikes(seg1, seg2));
    }
  }
  return dedupePoints(result);
}

// ─────────────────────────────────────────────
// Selector Application
// ─────────────────────────────────────────────

sealed class IntersectionSelector {}

class FirstSelector extends IntersectionSelector {}

class LastSelector extends IntersectionSelector {}

class IndexSelector extends IntersectionSelector {
  final int index;
  IndexSelector(this.index);
}

class NearestSelector extends IntersectionSelector {
  final Point2D ref;
  NearestSelector(this.ref);
}

class FarthestSelector extends IntersectionSelector {
  final Point2D ref;
  FarthestSelector(this.ref);
}

Point2D applySelector(List<Point2D> points, IntersectionSelector? selector, String label) {
  if (points.isEmpty) {
    throw Exception('NO_INTERSECTION: $label');
  }

  if (selector == null) {
    if (points.length > 1) {
      throw Exception('MULTIPLE_INTERSECTIONS: $label yields ${points.length} results. Use a selector.');
    }
    return points[0];
  }

  switch (selector) {
    case FirstSelector():
      return points.first;
    case LastSelector():
      return points.last;
    case IndexSelector(:final index):
      if (index < 0 || index >= points.length) {
        throw Exception('Intersection index $index out of range (${points.length} results): $label');
      }
      return points[index];
    case NearestSelector(:final ref):
      return points.reduce((best, p) => geom.distanceSquared(p, ref) < geom.distanceSquared(best, ref) ? p : best);
    case FarthestSelector(:final ref):
      return points.reduce((best, p) => geom.distanceSquared(p, ref) > geom.distanceSquared(best, ref) ? p : best);
  }
}

// ─────────────────────────────────────────────
// Generic dispatch
// ─────────────────────────────────────────────

List<Point2D> computeIntersections(ResolvedObject obj1, ResolvedObject obj2, String label) {
  final t1 = obj1 is ResolvedPoint ? 'point'
      : obj1 is ResolvedLine ? 'line'
      : obj1 is ResolvedCircle ? 'circle'
      : obj1 is ResolvedArc ? 'arc'
      : obj1 is ResolvedPath ? 'path'
      : obj1 is ResolvedPolygon ? 'polygon'
      : obj1 is ResolvedRect ? 'rect'
      : '';

  final t2 = obj2 is ResolvedPoint ? 'point'
      : obj2 is ResolvedLine ? 'line'
      : obj2 is ResolvedCircle ? 'circle'
      : obj2 is ResolvedArc ? 'arc'
      : obj2 is ResolvedPath ? 'path'
      : obj2 is ResolvedPolygon ? 'polygon'
      : obj2 is ResolvedRect ? 'rect'
      : '';

  final pair = [t1, t2]..sort();
  final pairKey = pair.join('-');

  switch (pairKey) {
    case 'line-line':
      final l1 = obj1 as ResolvedLine;
      final l2 = obj2 as ResolvedLine;
      final result = intersectLines(l1.x1, l1.y1, l1.x2, l1.y2, l2.x1, l2.y1, l2.x2, l2.y2);
      return result != null ? [result] : [];

    case 'circle-line':
      final line = obj1 is ResolvedLine ? obj1 : obj2 as ResolvedLine;
      final circle = obj1 is ResolvedCircle ? obj1 : obj2 as ResolvedCircle;
      return intersectLineCircle(line.x1, line.y1, line.x2, line.y2, circle.cx, circle.cy, circle.radius);

    case 'arc-line':
      final line = obj1 is ResolvedLine ? obj1 : obj2 as ResolvedLine;
      final arc = obj1 is ResolvedArc ? obj1 : obj2 as ResolvedArc;
      return intersectLineArc(line.x1, line.y1, line.x2, line.y2, arc.cx, arc.cy, arc.radius, arc.startAngle, arc.endAngle);

    case 'circle-circle':
      final c1 = obj1 as ResolvedCircle;
      final c2 = obj2 as ResolvedCircle;
      return intersectCircles(c1.cx, c1.cy, c1.radius, c2.cx, c2.cy, c2.radius);

    case 'arc-circle':
      final circle = obj1 is ResolvedCircle ? obj1 : obj2 as ResolvedCircle;
      final arc = obj1 is ResolvedArc ? obj1 : obj2 as ResolvedArc;
      return intersectCircleArc(circle.cx, circle.cy, circle.radius, arc.cx, arc.cy, arc.radius, arc.startAngle, arc.endAngle);

    case 'arc-arc':
      final a1 = obj1 as ResolvedArc;
      final a2 = obj2 as ResolvedArc;
      return intersectArcs(a1.cx, a1.cy, a1.radius, a1.startAngle, a1.endAngle, a2.cx, a2.cy, a2.radius, a2.startAngle, a2.endAngle);

    case 'line-path':
    case 'line-polygon':
    case 'line-rect':
      final line = obj1 is ResolvedLine ? obj1 : obj2 as ResolvedLine;
      final pathLike = obj1 is ResolvedLine ? obj2 : obj1;
      return intersectLineWithPathLike(line, pathLike);

    case 'circle-path':
    case 'circle-polygon':
    case 'circle-rect':
      final circle = obj1 is ResolvedCircle ? obj1 : obj2 as ResolvedCircle;
      final pathLike = obj1 is ResolvedCircle ? obj2 : obj1;
      return intersectCircleWithPathLike(circle, pathLike);

    case 'arc-path':
    case 'arc-polygon':
    case 'arc-rect':
      final arc = obj1 is ResolvedArc ? obj1 : obj2 as ResolvedArc;
      final pathLike = obj1 is ResolvedArc ? obj2 : obj1;
      return intersectArcWithPathLike(arc, pathLike);

    case 'path-path':
    case 'path-polygon':
    case 'path-rect':
    case 'polygon-polygon':
    case 'polygon-rect':
    case 'rect-rect':
      return intersectPathLikes(obj1, obj2);

    default:
      throw Exception('UNSUPPORTED_FEATURE: intersection between "$t1" and "$t2" is not supported');
  }
}
