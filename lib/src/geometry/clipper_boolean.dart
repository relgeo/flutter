import 'dart:math' as math;
import 'package:clipper2/clipper2.dart';
import 'types.dart';
import 'utils.dart';
import 'transforms.dart';

/// Pustaka Boolean dan Clipper2 Integration untuk RelGeo.
///
/// Modul ini menyediakan normalisasi objek tertutup (Rect, Circle, Path, Polygon, dll.)
/// menjadi list kontur serta melakukan operasi boolean 2D (Union, Subtract, Intersect, Xor)
/// secara deterministik dan presisi tinggi menggunakan Clipper2.

class ClosedShapeInput {
  final List<Point2D> outer;
  final List<List<Point2D>>? holes;

  ClosedShapeInput({required this.outer, this.holes});

  @override
  String toString() =>
      'ClosedShapeInput(outer: ${outer.length} pts, holes: ${holes?.length ?? 0})';
}

/// Fungsi utilitas untuk membersihkan titik-titik redundan atau duplikat berurutan.
List<Point2D> cleanPoints(List<Point2D> points) {
  final List<Point2D> result = [];
  for (final p in points) {
    if (result.isEmpty) {
      result.add(p);
      continue;
    }
    final last = result.last;
    final dx = p.x - last.x;
    final dy = p.y - last.y;
    if (math.sqrt(dx * dx + dy * dy) > 1e-7) {
      result.add(p);
    }
  }
  if (result.length > 1) {
    final first = result.first;
    final last = result.last;
    final dx = first.x - last.x;
    final dy = first.y - last.y;
    if (math.sqrt(dx * dx + dy * dy) < 1e-7) {
      result.removeLast();
    }
  }
  return result;
}

/// Mengubah list dari Point2D (RelGeo) ke PathD (Clipper2).
PathD toClipperPath(List<Point2D> path) {
  return path.map((p) => PointD(p.x, p.y)).toList();
}

/// Mengubah PathD (Clipper2) ke List dari Point2D (RelGeo).
List<Point2D> fromClipperPath(PathD path) {
  return path.map((p) => (x: p.x, y: p.y)).toList();
}

/// Mengubah satu ClosedShapeInput ke PathsD (Clipper2).
PathsD toClipperGeom(ClosedShapeInput shape) {
  final PathsD geom = [];
  geom.add(toClipperPath(shape.outer));
  if (shape.holes != null) {
    for (final hole in shape.holes!) {
      geom.add(toClipperPath(hole));
    }
  }
  return geom;
}

/// Helper untuk melakukan sampling segmen-segmen lubang (holes).
List<Point2D> sampleSegments(List<PathResolvedSegment> segments) {
  if (segments.isEmpty) return [];
  final List<Point2D> points = [];
  for (int i = 0; i < segments.length; i++) {
    final sampled = sampleSegmentLikePoints(segments[i]);
    if (i == 0) {
      points.addAll(sampled);
    } else {
      points.addAll(sampled.sublist(1));
    }
  }
  return points;
}

/// Melakukan normalisasi dari objek geometri RelGeo terdaftar ke ClosedShapeInput.
ClosedShapeInput normalizeClosedShape(
  ResolvedObject obj, [
  Map<String, ResolvedObject>? allObjects,
]) {
  ClosedShapeInput baseShape;

  if (obj is ResolvedRect) {
    final outer = cleanPoints([
      (x: obj.x, y: obj.y),
      (x: obj.x + obj.width, y: obj.y),
      (x: obj.x + obj.width, y: obj.y + obj.height),
      (x: obj.x, y: obj.y + obj.height),
    ]);
    final holes = obj.holes
        .map((h) => cleanPoints(sampleSegments(h.segments)))
        .where((h) => h.length >= 3)
        .toList();
    baseShape = ClosedShapeInput(
      outer: outer,
      holes: holes.isNotEmpty ? holes : null,
    );
  } else if (obj is ResolvedCircle) {
    final List<Point2D> outer = [];
    const segments = 64;
    for (int i = 0; i < segments; i++) {
      final angle = (i * 2 * math.pi) / segments;
      outer.add((
        x: obj.cx + obj.radius * math.cos(angle),
        y: obj.cy + obj.radius * math.sin(angle),
      ));
    }
    final holes = obj.holes
        .map((h) => cleanPoints(sampleSegments(h.segments)))
        .where((h) => h.length >= 3)
        .toList();
    baseShape = ClosedShapeInput(
      outer: cleanPoints(outer),
      holes: holes.isNotEmpty ? holes : null,
    );
  } else if (obj is ResolvedEllipse) {
    final List<Point2D> outer = [];
    const segments = 64;
    final cosR = math.cos(obj.rotation);
    final sinR = math.sin(obj.rotation);
    for (int i = 0; i < segments; i++) {
      final angle = (i * 2 * math.pi) / segments;
      final localX = obj.rx * math.cos(angle);
      final localY = obj.ry * math.sin(angle);
      outer.add((
        x: obj.cx + (localX * cosR - localY * sinR),
        y: obj.cy + (localX * sinR + localY * cosR),
      ));
    }
    final holes = obj.holes
        .map((h) => cleanPoints(sampleSegments(h.segments)))
        .where((h) => h.length >= 3)
        .toList();
    baseShape = ClosedShapeInput(
      outer: cleanPoints(outer),
      holes: holes.isNotEmpty ? holes : null,
    );
  } else if (obj is ResolvedPolygon) {
    final outer = cleanPoints(samplePathLikeObject(obj));
    final holes = obj.holes
        .map((h) => cleanPoints(sampleSegments(h.segments)))
        .where((h) => h.length >= 3)
        .toList();
    baseShape = ClosedShapeInput(
      outer: outer,
      holes: holes.isNotEmpty ? holes : null,
    );
  } else if (obj is ResolvedPath) {
    final outer = cleanPoints(samplePathLikeObject(obj));
    final holes = obj.holes
        .map((h) => cleanPoints(sampleSegments(h.segments)))
        .where((h) => h.length >= 3)
        .toList();
    baseShape = ClosedShapeInput(
      outer: outer,
      holes: holes.isNotEmpty ? holes : null,
    );
  } else if (obj is ResolvedBoolean) {
    final outer = cleanPoints(samplePathLikeObject(obj));
    final holes = obj.holes
        .map((h) => cleanPoints(sampleSegments(h.segments)))
        .where((h) => h.length >= 3)
        .toList();
    baseShape = ClosedShapeInput(
      outer: outer,
      holes: holes.isNotEmpty ? holes : null,
    );
  } else if (obj is ResolvedClone) {
    final target = allObjects?[obj.of];
    if (target == null) {
      throw Exception(
        'Cannot normalize clone without its target resolved object: ${obj.of}',
      );
    }
    final targetNormalized = normalizeClosedShape(target, allObjects);
    if (obj.transforms.isNotEmpty) {
      final outer = targetNormalized.outer
          .map((p) => applyTransformPipeline(p, obj.transforms))
          .toList();
      final holes = targetNormalized.holes
          ?.map(
            (h) => h
                .map((p) => applyTransformPipeline(p, obj.transforms))
                .toList(),
          )
          .toList();
      return ClosedShapeInput(outer: outer, holes: holes);
    }
    return targetNormalized;
  } else {
    throw Exception('Unsupported closed shape type: ${obj.runtimeType}');
  }

  // Apply transforms to base shapes if any are defined on the object
  if (obj.transforms.isNotEmpty) {
    final outer = baseShape.outer
        .map((p) => applyTransformPipeline(p, obj.transforms))
        .toList();
    final holes = baseShape.holes
        ?.map(
          (h) =>
              h.map((p) => applyTransformPipeline(p, obj.transforms)).toList(),
        )
        .toList();
    return ClosedShapeInput(outer: outer, holes: holes);
  }
  return baseShape;
}

/// Mengubah kontur poligon datar menjadi list LineSegment untuk AST.
List<PathResolvedSegment> polyToSegments(List<Point2D> poly) {
  final List<PathResolvedSegment> segments = [];
  for (int i = 0; i < poly.length; i++) {
    final p1 = poly[i];
    final p2 = poly[(i + 1) % poly.length];
    segments.add(LineSegment(p1.x, p1.y, p2.x, p2.y));
  }
  return segments;
}

/// Rekursi traversal untuk mengurai PolyTreeD menjadi ClosedShapeInput.
List<ClosedShapeInput> extractClosedShapes(PolyPathD node) {
  final double divisor = node.scale * node.scale;

  List<Point2D> fromClipperPathLocal(PathD path) {
    return path.map((p) => (x: p.x / divisor, y: p.y / divisor)).toList();
  }

  final List<ClosedShapeInput> results = [];
  for (final child in node.children) {
    if (child.polygon != null && child.polygon!.isNotEmpty) {
      final List<List<Point2D>> holesList = [];
      for (final holeNode in child.children) {
        if (holeNode.polygon != null && holeNode.polygon!.isNotEmpty) {
          holesList.add(fromClipperPathLocal(holeNode.polygon!));
        }
        results.addAll(extractClosedShapes(holeNode));
      }
      results.add(
        ClosedShapeInput(
          outer: fromClipperPathLocal(child.polygon!),
          holes: holesList.isNotEmpty ? holesList : null,
        ),
      );
    }
  }
  return results;
}

/// Engine untuk eksekusi operasi Boolean 2D menggunakan Clipper2.
class ClipperBooleanEngine {
  final int precision;

  ClipperBooleanEngine({this.precision = 4});

  List<ClosedShapeInput> _executeOp(
    ClipType clipType,
    List<ClosedShapeInput> subjects,
    List<ClosedShapeInput> clips,
  ) {
    if (subjects.isEmpty) return [];

    final c = ClipperD(roundingDecimalPrecision: precision);
    for (final s in subjects) {
      c.addPaths(toClipperGeom(s), PathType.subject);
    }
    for (final cl in clips) {
      c.addPaths(toClipperGeom(cl), PathType.clip);
    }

    final solution = c.executeTree(clipType, FillRule.nonZero);
    if (solution == null) return [];

    return extractClosedShapes(solution.tree);
  }

  List<ClosedShapeInput> union(List<ClosedShapeInput> shapes) {
    if (shapes.isEmpty) return [];
    if (shapes.length == 1) return [shapes[0]];
    return _executeOp(ClipType.union, [shapes[0]], shapes.sublist(1));
  }

  List<ClosedShapeInput> subtract(
    ClosedShapeInput base,
    List<ClosedShapeInput> tools,
  ) {
    if (tools.isEmpty) return [base];
    return _executeOp(ClipType.difference, [base], tools);
  }

  List<ClosedShapeInput> intersect(List<ClosedShapeInput> shapes) {
    if (shapes.isEmpty) return [];
    if (shapes.length == 1) return [shapes[0]];
    return _executeOp(ClipType.intersection, [shapes[0]], shapes.sublist(1));
  }

  List<ClosedShapeInput> xor(List<ClosedShapeInput> shapes) {
    if (shapes.isEmpty) return [];
    if (shapes.length == 1) return [shapes[0]];
    return _executeOp(ClipType.xor, [shapes[0]], shapes.sublist(1));
  }
}
