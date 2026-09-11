/// Utilitas matematika analitis, sampling kurva Bezier, kalkulasi jarak,
/// pencarian titik terdekat (closestPoint), luas, dan panjang geometri RelGeo.

import 'dart:math' as math;
import 'types.dart';
import 'transforms.dart';

double hypot(double x, double y) => math.sqrt(x * x + y * y);

double normalizeAngle(double angle) {
  const fullTurn = math.pi * 2;
  double value = angle % fullTurn;
  if (value < 0) value += fullTurn;
  return value;
}

bool isAngleOnSweep(double start, double end, double target, [int sweep = 1]) {
  final s = normalizeAngle(start);
  final e = normalizeAngle(end);
  final t = normalizeAngle(target);

  if (sweep == 1) {
    if (s <= e) return t >= s && t <= e;
    return t >= s || t <= e;
  }

  if (e <= s) return t <= s && t >= e;
  return t <= s || t >= e;
}

Point2D lerpPoint(Point2D a, Point2D b, double t) {
  return (x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t);
}

double distanceSquared(Point2D a, Point2D b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return dx * dx + dy * dy;
}

double polylineLength(List<Point2D> points, [bool closed = false]) {
  double total = 0.0;
  for (int i = 1; i < points.length; i++) {
    total += hypot(
      points[i].x - points[i - 1].x,
      points[i].y - points[i - 1].y,
    );
  }
  if (closed && points.length > 1) {
    total += hypot(
      points[0].x - points[points.length - 1].x,
      points[0].y - points[points.length - 1].y,
    );
  }
  return total;
}

double polygonArea(List<Point2D> points) {
  if (points.length < 3) return 0.0;
  double area = 0.0;
  for (int i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area.abs() / 2.0;
}

Point2D closestPointOnSegment(Point2D p, Point2D a, Point2D b) {
  final abx = b.x - a.x;
  final aby = b.y - a.y;
  final ab2 = abx * abx + aby * aby;
  if (ab2 == 0) return a;
  final apx = p.x - a.x;
  final apy = p.y - a.y;
  final t = math.min(1.0, math.max(0.0, (apx * abx + apy * aby) / ab2));
  return lerpPoint(a, b, t);
}

Point2D pickNearestPoint(Point2D ref, List<Point2D> points) {
  if (points.isEmpty) return (x: 0.0, y: 0.0);
  Point2D best = points[0];
  double bestDist = distanceSquared(ref, best);
  for (int i = 1; i < points.length; i++) {
    final dist = distanceSquared(ref, points[i]);
    if (dist < bestDist) {
      bestDist = dist;
      best = points[i];
    }
  }
  return best;
}

double clampAngleToArc(double angle, double start, double end) {
  double normalize(double val) {
    const fullTurn = math.pi * 2;
    double current = val % fullTurn;
    if (current < 0) current += fullTurn;
    return current;
  }

  final a = normalize(angle);
  final s = normalize(start);
  double e = normalize(end);
  if (e < s) e += math.pi * 2;

  final candidates = [a, a + math.pi * 2, a - math.pi * 2];
  for (final candidate in candidates) {
    if (candidate >= s && candidate <= e) return candidate;
  }
  return (candidates[0] - s).abs() < (candidates[0] - e).abs() ? s : e;
}

List<Point2D> sampleQuadraticPoints({
  required double x1,
  required double y1,
  required double cpx,
  required double cpy,
  required double x2,
  required double y2,
  int steps = 48,
}) {
  final List<Point2D> points = [];
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final mt = 1 - t;
    points.add((
      x: mt * mt * x1 + 2 * mt * t * cpx + t * t * x2,
      y: mt * mt * y1 + 2 * mt * t * cpy + t * t * y2,
    ));
  }
  return points;
}

List<Point2D> sampleCubicPoints({
  required double x1,
  required double y1,
  required double cp1x,
  required double cp1y,
  required double cp2x,
  required double cp2y,
  required double x2,
  required double y2,
  int steps = 64,
}) {
  final List<Point2D> points = [];
  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final mt = 1 - t;
    points.add((
      x:
          mt * mt * mt * x1 +
          3 * mt * mt * t * cp1x +
          3 * mt * t * t * cp2x +
          t * t * t * x2,
      y:
          mt * mt * mt * y1 +
          3 * mt * mt * t * cp1y +
          3 * mt * t * t * cp2y +
          t * t * t * y2,
    ));
  }
  return points;
}

Point2D pointOnQuadratic(Point2D p0, Point2D cp, Point2D p1, double t) {
  final mt = 1.0 - t;
  return (
    x: mt * mt * p0.x + 2 * mt * t * cp.x + t * t * p1.x,
    y: mt * mt * p0.y + 2 * mt * t * cp.y + t * t * p1.y,
  );
}

Point2D pointOnCubic(
  Point2D p0,
  Point2D cp1,
  Point2D cp2,
  Point2D p1,
  double t,
) {
  final mt = 1.0 - t;
  return (
    x:
        mt * mt * mt * p0.x +
        3 * mt * mt * t * cp1.x +
        3 * mt * t * t * cp2.x +
        t * t * t * p1.x,
    y:
        mt * mt * mt * p0.y +
        3 * mt * mt * t * cp1.y +
        3 * mt * t * t * cp2.y +
        t * t * t * p1.y,
  );
}

double approximateQuadraticLength(
  Point2D p0,
  Point2D cp,
  Point2D p1, [
  int steps = 24,
]) {
  double total = 0.0;
  Point2D prev = p0;
  for (int i = 1; i <= steps; i++) {
    final t = i / steps;
    final next = pointOnQuadratic(p0, cp, p1, t);
    total += hypot(next.x - prev.x, next.y - prev.y);
    prev = next;
  }
  return total;
}

double approximateCubicLength(
  Point2D p0,
  Point2D cp1,
  Point2D cp2,
  Point2D p1, [
  int steps = 32,
]) {
  double total = 0.0;
  Point2D prev = p0;
  for (int i = 1; i <= steps; i++) {
    final t = i / steps;
    final next = pointOnCubic(p0, cp1, cp2, p1, t);
    total += hypot(next.x - prev.x, next.y - prev.y);
    prev = next;
  }
  return total;
}

double approximateSubQuadraticLength(
  Point2D p0,
  Point2D cp,
  Point2D p1,
  double t, [
  int steps = 24,
]) {
  double total = 0.0;
  Point2D prev = p0;
  for (int i = 1; i <= steps; i++) {
    final currT = (i / steps) * t;
    final next = pointOnQuadratic(p0, cp, p1, currT);
    total += hypot(next.x - prev.x, next.y - prev.y);
    prev = next;
  }
  return total;
}

double approximateSubCubicLength(
  Point2D p0,
  Point2D cp1,
  Point2D cp2,
  Point2D p1,
  double t, [
  int steps = 32,
]) {
  double total = 0.0;
  Point2D prev = p0;
  for (int i = 1; i <= steps; i++) {
    final currT = (i / steps) * t;
    final next = pointOnCubic(p0, cp1, cp2, p1, currT);
    total += hypot(next.x - prev.x, next.y - prev.y);
    prev = next;
  }
  return total;
}

Point2D closestPointOnQuadratic(
  Point2D ref,
  Point2D p0,
  Point2D cp,
  Point2D p1, [
  int steps = 48,
]) {
  final List<Point2D> samples = [];
  for (int i = 0; i <= steps; i++) {
    samples.add(pointOnQuadratic(p0, cp, p1, i / steps));
  }
  return pickNearestPoint(ref, samples);
}

Point2D closestPointOnCubic(
  Point2D ref,
  Point2D p0,
  Point2D cp1,
  Point2D cp2,
  Point2D p1, [
  int steps = 64,
]) {
  final List<Point2D> samples = [];
  for (int i = 0; i <= steps; i++) {
    samples.add(pointOnCubic(p0, cp1, cp2, p1, i / steps));
  }
  return pickNearestPoint(ref, samples);
}

Point2D closestPointOnPointPath(
  Point2D ref,
  List<Point2D> points,
  bool closed,
) {
  final List<Point2D> candidates = [];
  final segmentCount = closed ? points.length : points.length - 1;
  for (int i = 0; i < segmentCount; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    candidates.add(closestPointOnSegment(ref, a, b));
  }
  return pickNearestPoint(ref, candidates);
}

Point2D closestPointOnEllipse(
  Point2D ref, {
  required double cx,
  required double cy,
  required double rx,
  required double ry,
  double rotation = 0.0,
  int steps = 128,
}) {
  final List<Point2D> samples = [];
  final cosR = math.cos(rotation);
  final sinR = math.sin(rotation);
  for (int i = 0; i <= steps; i++) {
    final theta = (i / steps) * 2 * math.pi;
    final localX = rx * math.cos(theta);
    final localY = ry * math.sin(theta);
    samples.add((
      x: cx + (localX * cosR - localY * sinR),
      y: cy + (localX * sinR + localY * cosR),
    ));
  }
  return pickNearestPoint(ref, samples);
}

List<Point2D> sampleSegmentLikePoints(
  PathResolvedSegment segment, [
  int steps = 32,
]) {
  switch (segment) {
    case LineSegment(:final x1, :final y1, :final x2, :final y2):
      return [(x: x1, y: y1), (x: x2, y: y2)];
    case ArcSegment(
      :final x1,
      :final y1,
      :final x2,
      :final y2,
      :final cx,
      :final cy,
      :final radius,
      :final sweep,
      :final largeArc,
    ):
      final startAngle = math.atan2(y1 - cy, x1 - cx);
      double endAngle = math.atan2(y2 - cy, x2 - cx);
      if (sweep == 1 && endAngle < startAngle) endAngle += math.pi * 2;
      if (sweep == 0 && endAngle > startAngle) endAngle -= math.pi * 2;
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
    case QuadraticSegment(
      :final x1,
      :final y1,
      :final cpx,
      :final cpy,
      :final x2,
      :final y2,
    ):
      return sampleQuadraticPoints(
        x1: x1,
        y1: y1,
        cpx: cpx,
        cpy: cpy,
        x2: x2,
        y2: y2,
        steps: math.max(steps, 48),
      );
    case CubicSegment(
      :final x1,
      :final y1,
      :final cp1x,
      :final cp1y,
      :final cp2x,
      :final cp2y,
      :final x2,
      :final y2,
    ):
      return sampleCubicPoints(
        x1: x1,
        y1: y1,
        cp1x: cp1x,
        cp1y: cp1y,
        cp2x: cp2x,
        cp2y: cp2y,
        x2: x2,
        y2: y2,
        steps: math.max(steps, 64),
      );
  }
}

List<Point2D> samplePathLikeObject(ResolvedObject obj) {
  List<PathResolvedSegment> segments = [];
  List<Point2D> points = [];

  if (obj is ResolvedPath) {
    segments = obj.segments;
    points = obj.points;
  } else if (obj is ResolvedPolygon) {
    segments = obj.segments;
    points = obj.points;
  } else if (obj is ResolvedBoolean) {
    segments = obj.segments;
    points = obj.points;
  }

  if (segments.isNotEmpty) {
    final List<Point2D> sampledPoints = [];
    for (int i = 0; i < segments.length; i++) {
      final sampled = sampleSegmentLikePoints(segments[i]);
      if (i == 0) {
        sampledPoints.addAll(sampled);
      } else {
        sampledPoints.addAll(sampled.sublist(1));
      }
    }
    return sampledPoints;
  }
  return points;
}

List<Point2D> getPointsForObject(ResolvedObject obj) {
  switch (obj) {
    case ResolvedPoint(:final x, :final y):
      return [(x: x, y: y)];
    case ResolvedLine(:final x1, :final y1, :final x2, :final y2):
      return [(x: x1, y: y1), (x: x2, y: y2)];
    case ResolvedRect(:final x, :final y, :final width, :final height):
      return [
        (x: x, y: y),
        (x: x + width, y: y),
        (x: x, y: y + height),
        (x: x + width, y: y + height),
      ];
    case ResolvedCircle(:final cx, :final cy, :final radius):
      return [
        (x: cx - radius, y: cy),
        (x: cx + radius, y: cy),
        (x: cx, y: cy - radius),
        (x: cx, y: cy + radius),
      ];
    case ResolvedEllipse(
      :final cx,
      :final cy,
      :final rx,
      :final ry,
      :final rotation,
    ):
      final cosR = math.cos(rotation);
      final sinR = math.sin(rotation);
      final halfWidth = math.sqrt(
        (rx * cosR) * (rx * cosR) + (ry * sinR) * (ry * sinR),
      );
      final halfHeight = math.sqrt(
        (rx * sinR) * (rx * sinR) + (ry * cosR) * (ry * cosR),
      );
      return [
        (x: cx - halfWidth, y: cy),
        (x: cx + halfWidth, y: cy),
        (x: cx, y: cy - halfHeight),
        (x: cx, y: cy + halfHeight),
      ];
    case ResolvedArc(
      :final x1,
      :final y1,
      :final x2,
      :final y2,
      :final cx,
      :final cy,
      :final radius,
      :final startAngle,
      :final endAngle,
      :final sweep,
    ):
      final points = [(x: x1, y: y1), (x: x2, y: y2)];
      final candidateAngles = [0.0, math.pi / 2, math.pi, (3 * math.pi) / 2];
      for (final angle in candidateAngles) {
        if (isAngleOnSweep(startAngle, endAngle, angle, sweep)) {
          points.add((
            x: cx + radius * math.cos(angle),
            y: cy + radius * math.sin(angle),
          ));
        }
      }
      return points;
    case ResolvedQuadratic(
      :final x1,
      :final y1,
      :final cpx,
      :final cpy,
      :final x2,
      :final y2,
    ):
      return sampleQuadraticPoints(
        x1: x1,
        y1: y1,
        cpx: cpx,
        cpy: cpy,
        x2: x2,
        y2: y2,
      );
    case ResolvedCubic(
      :final x1,
      :final y1,
      :final cp1x,
      :final cp1y,
      :final cp2x,
      :final cp2y,
      :final x2,
      :final y2,
    ):
      return sampleCubicPoints(
        x1: x1,
        y1: y1,
        cp1x: cp1x,
        cp1y: cp1y,
        cp2x: cp2x,
        cp2y: cp2y,
        x2: x2,
        y2: y2,
      );
    case ResolvedPath():
      return samplePathLikeObject(obj);
    case ResolvedPolygon():
      return samplePathLikeObject(obj);
    case ResolvedBoolean():
      return samplePathLikeObject(obj);
    case ResolvedText(:final x, :final y, :final width, :final height):
      return [(x: x, y: y), (x: x + width, y: y + height)];
    default:
      return [];
  }
}

BoundingBox calculateBoundingBox(
  Map<String, ResolvedObject> objects, {
  Map<String, String>? parentMap,
  List<String>? ignoreRoles,
  List<ResolvedTransformOp> defaultInitialTransform = const [],
  List<String>? targetIds,
}) {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = -double.infinity;
  double maxY = -double.infinity;

  void addPoints(List<Point2D> pts) {
    for (final p in pts) {
      if (p.x.isFinite && p.y.isFinite) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
    }
  }

  void recurse(
    String objId,
    List<ResolvedTransformOp> currentTransform,
    Meta parentMeta,
    bool isCloneDescendant,
  ) {
    final obj = objects[objId];
    if (obj == null) return;

    // Gabungkan meta
    final meta = isCloneDescendant
        ? Meta(
            visible: obj.meta.visible && parentMeta.visible,
            stroke: obj.meta.stroke ?? parentMeta.stroke,
            fill: obj.meta.fill ?? parentMeta.fill,
            strokeWidth: obj.meta.strokeWidth ?? parentMeta.strokeWidth,
            opacity: obj.meta.opacity ?? parentMeta.opacity,
            role: obj.meta.role,
          )
        : Meta(
            visible: parentMeta.visible && obj.meta.visible,
            stroke: parentMeta.stroke ?? obj.meta.stroke,
            fill: parentMeta.fill ?? obj.meta.fill,
            strokeWidth: parentMeta.strokeWidth ?? obj.meta.strokeWidth,
            opacity: parentMeta.opacity ?? obj.meta.opacity,
            role: obj.meta.role,
          );

    if (!meta.visible) return;
    if (ignoreRoles != null && ignoreRoles.contains(meta.role)) return;

    final combinedTransform = [...obj.transforms, ...currentTransform];

    // Bbox untuk objek lokal
    final localPts = getPointsForObject(obj);
    if (localPts.isNotEmpty) {
      final worldPts = localPts
          .map((pt) => applyTransformPipeline(pt, combinedTransform))
          .toList();
      addPoints(worldPts);
    }

    // Jika objek bertipe group/clone/component, telusuri anak-anaknya
    List<String> children = [];
    bool isClone = false;
    if (obj is BaseResolvedGroup) {
      children = obj.children;
      if (obj is ResolvedClone) {
        isClone = true;
      }
    }

    for (final childId in children) {
      recurse(childId, combinedTransform, meta, isCloneDescendant || isClone);
    }
  }

  final roots =
      targetIds ??
      () {
        // Cari elemen root (tidak dideklarasikan di dalam children elemen manapun)
        final childIds = <String>{};
        for (final obj in objects.values) {
          List<String> children = [];
          if (obj is BaseResolvedGroup) {
            children = obj.children;
          }
          childIds.addAll(children);
        }
        return objects.keys.where((id) => !childIds.contains(id)).toList();
      }();

  for (final id in roots) {
    final baseTransform = [...defaultInitialTransform];
    Meta baseMeta = Meta(visible: true);
    if (parentMap != null) {
      String? curr = parentMap[id];
      while (curr != null) {
        final parentObj = objects[curr];
        if (parentObj != null) {
          if (parentObj.transforms.isNotEmpty) {
            baseTransform.addAll(parentObj.transforms);
          }
          baseMeta = Meta(
            visible: baseMeta.visible && parentObj.meta.visible,
            stroke: parentObj.meta.stroke ?? baseMeta.stroke,
            fill: parentObj.meta.fill ?? baseMeta.fill,
            strokeWidth: parentObj.meta.strokeWidth ?? baseMeta.strokeWidth,
            opacity:
                (parentObj.meta.opacity != null && baseMeta.opacity != null)
                ? parentObj.meta.opacity! * baseMeta.opacity!
                : (parentObj.meta.opacity ?? baseMeta.opacity),
            role: parentObj.meta.role != 'final'
                ? parentObj.meta.role
                : baseMeta.role,
            dash: parentObj.meta.dash ?? baseMeta.dash,
          );
        }
        curr = parentMap[curr];
      }
    }
    recurse(id, baseTransform, baseMeta, false);
  }

  if (minX == double.infinity) {
    return const BoundingBox(x: 0, y: 0, width: 800, height: 600);
  }

  return BoundingBox(x: minX, y: minY, width: maxX - minX, height: maxY - minY);
}
